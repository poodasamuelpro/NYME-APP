-- ═══════════════════════════════════════════════════════════════════
-- NYME - Migration 003 : Wallet avancé + Documents coursiers
-- À exécuter APRÈS 001_schema_complet.sql et 002_rls_policies.sql
--
-- CORRECTIONS APPLIQUÉES vs le code original :
-- • public.users → public.utilisateurs (nom réel de la table)
-- • public.profiles → public.utilisateurs
-- • wallet_transactions → transactions_wallet (nom réel dans 001)
-- • wallets : déjà créée dans 001, on la complète avec ALTER TABLE
-- • statut → colonne correcte (pas status)
-- • Suppression des RLS déjà présents dans 002
-- • Trigger update_updated_at renommé pour éviter conflit avec 001
-- • livraisons_partenaire.coursier_id → référence utilisateurs, pas auth.users
-- • admin policies référencent utilisateurs et non profiles
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. AJOUT DU RÔLE PARTENAIRE dans la table utilisateurs
-- ─────────────────────────────────────────────────────────────────

-- Supprimer l'ancienne contrainte CHECK sur role
ALTER TABLE public.utilisateurs
  DROP CONSTRAINT IF EXISTS utilisateurs_role_check;

-- Recréer avec les 4 rôles : client, coursier, admin, partenaire
ALTER TABLE public.utilisateurs
  ADD CONSTRAINT utilisateurs_role_check
  CHECK (role IN ('client', 'coursier', 'admin', 'partenaire'));

-- Mettre à jour la fonction mon_role() dans 002 pour inclure partenaire
-- (pas de modification SQL nécessaire, la fonction lit juste la colonne role)

-- ─────────────────────────────────────────────────────────────────
-- 2. COMPLÉTER LA TABLE WALLETS (déjà créée dans 001)
-- On ajoute les colonnes manquantes sans recréer la table
-- ─────────────────────────────────────────────────────────────────

-- Ajouter created_at si absent
ALTER TABLE public.wallets
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ─────────────────────────────────────────────────────────────────
-- 3. COMPLÉTER LA TABLE TRANSACTIONS_WALLET (déjà créée dans 001)
-- ─────────────────────────────────────────────────────────────────

-- Ajouter les colonnes avancées manquantes dans la table existante
ALTER TABLE public.transactions_wallet
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed'
    CHECK (status IN ('pending', 'completed', 'failed', 'cancelled', 'confirmed')),
  ADD COLUMN IF NOT EXISTS payment_method TEXT
    CHECK (payment_method IN ('cash', 'mobile_money', 'carte', 'wallet', 'virement_bancaire')),
  ADD COLUMN IF NOT EXISTS idempotency_key UUID UNIQUE DEFAULT uuid_generate_v4(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Élargir les types autorisés dans transactions_wallet (001 a : gain, retrait, commission, bonus, remboursement)
ALTER TABLE public.transactions_wallet
  DROP CONSTRAINT IF EXISTS transactions_wallet_type_check;

ALTER TABLE public.transactions_wallet
  ADD CONSTRAINT transactions_wallet_type_check
  CHECK (type IN ('gain', 'retrait', 'commission', 'bonus', 'remboursement', 'recharge', 'paiement_course'));

-- Index supplémentaires
CREATE INDEX IF NOT EXISTS idx_transactions_wallet_status
  ON public.transactions_wallet(status);

CREATE INDEX IF NOT EXISTS idx_transactions_wallet_livraison
  ON public.transactions_wallet(livraison_id);

-- Trigger updated_at pour transactions_wallet (nom distinct de 001)
CREATE OR REPLACE FUNCTION public.update_transactions_wallet_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_transactions_wallet_updated_at ON public.transactions_wallet;
CREATE TRIGGER trg_transactions_wallet_updated_at
  BEFORE UPDATE ON public.transactions_wallet
  FOR EACH ROW EXECUTE FUNCTION public.update_transactions_wallet_updated_at();

-- ─────────────────────────────────────────────────────────────────
-- 4. FONCTION ATOMIQUE POUR LES TRANSACTIONS WALLET
-- Remplace les appels directs INSERT/UPDATE avec vérification de solde
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.process_wallet_transaction(
  p_user_id        UUID,
  p_type           TEXT,
  p_montant        NUMERIC,
  p_reference      TEXT    DEFAULT NULL,
  p_note           TEXT    DEFAULT NULL,
  p_livraison_id   UUID    DEFAULT NULL,
  p_payment_method TEXT    DEFAULT NULL,
  p_idempotency_key UUID   DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_solde_avant  NUMERIC(12,2);
  v_solde_apres  NUMERIC(12,2);
  v_transaction_id UUID;
BEGIN
  -- Verrouiller le wallet pour éviter les race conditions
  SELECT solde INTO v_solde_avant
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  -- Créer le wallet si inexistant
  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, solde)
    VALUES (p_user_id, 0.00)
    RETURNING solde INTO v_solde_avant;
  END IF;

  v_solde_apres := v_solde_avant + p_montant;

  -- Vérifier le solde pour les débits
  IF p_montant < 0 AND v_solde_apres < 0 THEN
    RAISE EXCEPTION 'Solde insuffisant. Solde: %, Débit demandé: %',
      v_solde_avant, ABS(p_montant);
  END IF;

  -- Mettre à jour le solde
  UPDATE public.wallets
  SET solde = v_solde_apres, updated_at = NOW()
  WHERE user_id = p_user_id;

  -- Enregistrer la transaction
  INSERT INTO public.transactions_wallet (
    user_id, type, montant, solde_avant, solde_apres,
    reference, note, livraison_id, status, payment_method, idempotency_key
  ) VALUES (
    p_user_id, p_type, p_montant, v_solde_avant, v_solde_apres,
    p_reference, p_note, p_livraison_id,
    'completed', p_payment_method,
    COALESCE(p_idempotency_key, uuid_generate_v4())
  )
  RETURNING id INTO v_transaction_id;

  RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────
-- 5. COLONNE PAYMENT_API sur LIVRAISONS (colonnes supplémentaires)
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE public.livraisons
  ADD COLUMN IF NOT EXISTS payment_api_reference TEXT,
  ADD COLUMN IF NOT EXISTS payment_api_status TEXT
    CHECK (payment_api_status IN ('pending', 'success', 'failed')),
  ADD COLUMN IF NOT EXISTS is_paid_to_courier BOOLEAN NOT NULL DEFAULT FALSE;

-- ─────────────────────────────────────────────────────────────────
-- 6. TABLE COURIER_DOCUMENTS (validation documents coursiers)
-- Remplace les colonnes cni_recto_url etc. de la table coursiers
-- par une table dédiée plus flexible
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.courier_documents (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  coursier_id      UUID NOT NULL REFERENCES public.coursiers(id) ON DELETE CASCADE,
  document_type    TEXT NOT NULL
    CHECK (document_type IN ('cni_recto', 'cni_verso', 'permis', 'carte_grise')),
  file_url         TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT,
  uploaded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  validated_by     UUID REFERENCES public.utilisateurs(id) ON DELETE SET NULL,
  validated_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_courier_documents_coursier
  ON public.courier_documents(coursier_id);

CREATE INDEX IF NOT EXISTS idx_courier_documents_status
  ON public.courier_documents(status);

-- RLS courier_documents
ALTER TABLE public.courier_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Coursier gère ses documents" ON public.courier_documents;
CREATE POLICY "Coursier gère ses documents"
  ON public.courier_documents
  FOR ALL
  USING (auth.uid() = coursier_id)
  WITH CHECK (auth.uid() = coursier_id);

DROP POLICY IF EXISTS "Admin gère tous les documents" ON public.courier_documents;
CREATE POLICY "Admin gère tous les documents"
  ON public.courier_documents
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.utilisateurs
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ─────────────────────────────────────────────────────────────────
-- 7. COLONNE STATUS_VALIDATION_DOCUMENTS dans COURSIERS
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE public.coursiers
  ADD COLUMN IF NOT EXISTS status_validation_documents TEXT NOT NULL DEFAULT 'pending'
    CHECK (status_validation_documents IN ('pending', 'approved', 'rejected'));

ALTER TABLE public.coursiers
  ADD COLUMN IF NOT EXISTS commission_due NUMERIC(12,2) NOT NULL DEFAULT 0.00
    CHECK (commission_due >= 0);

-- Trigger pour mettre à jour le statut global de validation
CREATE OR REPLACE FUNCTION public.update_courier_validation_status()
RETURNS TRIGGER AS $$
DECLARE
  v_pending  INT;
  v_rejected INT;
BEGIN
  SELECT COUNT(*) INTO v_pending
  FROM public.courier_documents
  WHERE coursier_id = NEW.coursier_id AND status = 'pending';

  SELECT COUNT(*) INTO v_rejected
  FROM public.courier_documents
  WHERE coursier_id = NEW.coursier_id AND status = 'rejected';

  IF v_rejected > 0 THEN
    UPDATE public.coursiers
    SET status_validation_documents = 'rejected'
    WHERE id = NEW.coursier_id;
  ELSIF v_pending = 0 THEN
    UPDATE public.coursiers
    SET status_validation_documents = 'approved'
    WHERE id = NEW.coursier_id;
  ELSE
    UPDATE public.coursiers
    SET status_validation_documents = 'pending'
    WHERE id = NEW.coursier_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_courier_validation_status ON public.courier_documents;
CREATE TRIGGER trg_courier_validation_status
  AFTER INSERT OR UPDATE OR DELETE ON public.courier_documents
  FOR EACH ROW EXECUTE FUNCTION public.update_courier_validation_status();

-- ─────────────────────────────────────────────────────────────────
-- 8. CALCUL AUTOMATIQUE DE COMMISSION après livraison payée
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.calculate_and_add_commission()
RETURNS TRIGGER AS $$
DECLARE
  v_taux       NUMERIC(5,2) := 0.15;
  v_commission NUMERIC(12,2);
BEGIN
  -- Déclencher uniquement quand livraison livrée ET payée
  IF NEW.statut = 'livree'
     AND NEW.statut_paiement = 'paye'
     AND NEW.coursier_id IS NOT NULL
     AND (OLD.statut != 'livree' OR OLD.statut_paiement != 'paye')
  THEN
    v_commission := COALESCE(NEW.prix_final, NEW.prix_calcule) * v_taux;

    -- Mettre à jour commission_due du coursier
    UPDATE public.coursiers
    SET commission_due = commission_due + v_commission
    WHERE id = NEW.coursier_id;

    -- Créditer le gain net au coursier via la fonction atomique
    PERFORM public.process_wallet_transaction(
      NEW.coursier_id,
      'gain',
      COALESCE(NEW.prix_final, NEW.prix_calcule) - v_commission,
      'LIVRAISON_' || NEW.id::TEXT,
      'Gain livraison ' || NEW.id::TEXT,
      NEW.id,
      'wallet'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calculate_commission ON public.livraisons;
CREATE TRIGGER trg_calculate_commission
  AFTER UPDATE OF statut, statut_paiement ON public.livraisons
  FOR EACH ROW EXECUTE FUNCTION public.calculate_and_add_commission();

-- ─────────────────────────────────────────────────────────────────
-- 9. FONCTION RETRAIT COURSIER (tous les 2 jours)
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.request_courier_withdrawal(
  p_coursier_id     UUID,
  p_montant         NUMERIC,
  p_idempotency_key UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_last_withdrawal TIMESTAMPTZ;
  v_solde           NUMERIC(12,2);
  v_transaction_id  UUID;
BEGIN
  -- Vérifier le délai entre retraits (2 jours)
  SELECT MAX(created_at) INTO v_last_withdrawal
  FROM public.transactions_wallet
  WHERE user_id = p_coursier_id
    AND type = 'retrait'
    AND status = 'completed';

  IF v_last_withdrawal IS NOT NULL
     AND v_last_withdrawal > (NOW() - INTERVAL '2 days')
  THEN
    RAISE EXCEPTION 'Retrait impossible : un retrait a été effectué il y a moins de 2 jours.';
  END IF;

  -- Vérifier le solde
  SELECT solde INTO v_solde
  FROM public.wallets
  WHERE user_id = p_coursier_id;

  IF v_solde IS NULL OR v_solde < p_montant THEN
    RAISE EXCEPTION 'Solde insuffisant : disponible %, demandé %',
      COALESCE(v_solde, 0), p_montant;
  END IF;

  -- Débiter via la fonction atomique
  v_transaction_id := public.process_wallet_transaction(
    p_coursier_id,
    'retrait',
    -p_montant,
    'RETRAIT_' || p_coursier_id::TEXT || '_' || NOW()::DATE::TEXT,
    'Retrait de fonds',
    NULL,
    'virement_bancaire',
    p_idempotency_key
  );

  RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
