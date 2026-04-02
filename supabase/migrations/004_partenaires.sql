-- ═══════════════════════════════════════════════════════════════════
-- NYME - Migration 004 : Rôle Partenaire + Tables Partenaires
-- À exécuter APRÈS 003_wallet_avance.sql
--
-- CORRECTIONS vs code original :
-- • public.profiles → public.utilisateurs
-- • livraisons_partenaire.coursier_id → référence utilisateurs (pas auth.users)
-- • admin policy référence utilisateurs et non profiles
-- • Trigger update_updated_at renommé (évite conflit avec 001)
-- • Colonnes harmonisées avec la convention NYME (snake_case français)
-- • Ajout RLS admin cohérente avec mon_role() de 002
--
-- PÉRIMÈTRE : utilisé pour le site web et le dashboard partenaire
-- Ne touche PAS à la logique de livraison de l'app mobile
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. AJOUTER 'partenaire' aux rôles autorisés
-- (Si la migration 003 n'a pas été exécutée avant celle-ci)
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE public.utilisateurs
  DROP CONSTRAINT IF EXISTS utilisateurs_role_check;

ALTER TABLE public.utilisateurs
  ADD CONSTRAINT utilisateurs_role_check
  CHECK (role IN ('client', 'coursier', 'admin', 'partenaire'));

-- ─────────────────────────────────────────────────────────────────
-- 2. TABLE PARTENAIRES
-- Un partenaire = une entreprise qui utilise NYME via le site web
-- pour commander des livraisons en volume
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.partenaires (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  -- Lié à l'utilisateur NYME (rôle partenaire)
  user_id         UUID NOT NULL UNIQUE REFERENCES public.utilisateurs(id) ON DELETE CASCADE,
  -- Informations entreprise
  entreprise      TEXT NOT NULL,
  nom_contact     TEXT NOT NULL,
  telephone       TEXT,
  email_pro       TEXT,
  adresse         TEXT,
  -- Plan d'abonnement
  plan            TEXT NOT NULL DEFAULT 'starter'
    CHECK (plan IN ('starter', 'business', 'enterprise')),
  -- Statut du compte partenaire
  statut          TEXT NOT NULL DEFAULT 'en_attente'
    CHECK (statut IN ('actif', 'suspendu', 'en_attente', 'rejete')),
  -- Limites selon le plan
  livraisons_max  INTEGER NOT NULL DEFAULT 30,
  livraisons_mois INTEGER NOT NULL DEFAULT 0,
  -- Période d'abonnement
  date_debut      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  date_fin        TIMESTAMPTZ,
  -- Commission spécifique partenaire (peut différer du taux standard)
  taux_commission NUMERIC(5,2) NOT NULL DEFAULT 12.0
    CHECK (taux_commission >= 0 AND taux_commission <= 100),
  -- Timestamps
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_partenaires_user_id
  ON public.partenaires(user_id);

CREATE INDEX IF NOT EXISTS idx_partenaires_statut
  ON public.partenaires(statut);

-- Trigger updated_at (nom distinct)
CREATE OR REPLACE FUNCTION public.update_partenaires_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_partenaires_updated_at ON public.partenaires;
CREATE TRIGGER trg_partenaires_updated_at
  BEFORE UPDATE ON public.partenaires
  FOR EACH ROW EXECUTE FUNCTION public.update_partenaires_updated_at();

-- RLS partenaires
ALTER TABLE public.partenaires ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Partenaire voit son profil" ON public.partenaires;
CREATE POLICY "Partenaire voit son profil"
  ON public.partenaires FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Partenaire modifie son profil" ON public.partenaires;
CREATE POLICY "Partenaire modifie son profil"
  ON public.partenaires FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin gère tous les partenaires" ON public.partenaires;
CREATE POLICY "Admin gère tous les partenaires"
  ON public.partenaires FOR ALL
  -- Utilise mon_role() de 002 au lieu de public.profiles
  USING (mon_role() = 'admin');

-- ─────────────────────────────────────────────────────────────────
-- 3. TABLE LIVRAISONS_PARTENAIRE
-- Historique simplifié des livraisons commandées par les partenaires
-- via le site web / dashboard partenaire
-- N'est PAS la même que la table livraisons de l'app mobile
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.livraisons_partenaire (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partenaire_id    UUID NOT NULL REFERENCES public.partenaires(id) ON DELETE CASCADE,
  -- Adresses
  adresse_depart   TEXT NOT NULL,
  adresse_arrivee  TEXT NOT NULL,
  lat_depart       DOUBLE PRECISION,
  lng_depart       DOUBLE PRECISION,
  lat_arrivee      DOUBLE PRECISION,
  lng_arrivee      DOUBLE PRECISION,
  -- Destinataire
  destinataire_nom TEXT,
  destinataire_tel TEXT,
  instructions     TEXT,
  -- Statut
  statut           TEXT NOT NULL DEFAULT 'en_attente'
    CHECK (statut IN ('en_attente', 'en_cours', 'livre', 'annule')),
  -- Prix
  prix             NUMERIC(10,2),
  commission       NUMERIC(10,2),
  -- Coursier assigné — référence utilisateurs (pas auth.users directement)
  coursier_id      UUID REFERENCES public.utilisateurs(id) ON DELETE SET NULL,
  -- Lien optionnel vers la livraison réelle dans l'app mobile
  livraison_app_id UUID REFERENCES public.livraisons(id) ON DELETE SET NULL,
  -- Timestamps
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_livraisons_partenaire_partenaire
  ON public.livraisons_partenaire(partenaire_id);

CREATE INDEX IF NOT EXISTS idx_livraisons_partenaire_statut
  ON public.livraisons_partenaire(statut);

CREATE INDEX IF NOT EXISTS idx_livraisons_partenaire_coursier
  ON public.livraisons_partenaire(coursier_id);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION public.update_livraisons_partenaire_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_livraisons_partenaire_updated_at ON public.livraisons_partenaire;
CREATE TRIGGER trg_livraisons_partenaire_updated_at
  BEFORE UPDATE ON public.livraisons_partenaire
  FOR EACH ROW EXECUTE FUNCTION public.update_livraisons_partenaire_updated_at();

-- RLS livraisons_partenaire
ALTER TABLE public.livraisons_partenaire ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Partenaire voit ses livraisons" ON public.livraisons_partenaire;
CREATE POLICY "Partenaire voit ses livraisons"
  ON public.livraisons_partenaire FOR SELECT
  USING (
    partenaire_id IN (
      SELECT id FROM public.partenaires
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Partenaire crée ses livraisons" ON public.livraisons_partenaire;
CREATE POLICY "Partenaire crée ses livraisons"
  ON public.livraisons_partenaire FOR INSERT
  WITH CHECK (
    partenaire_id IN (
      SELECT id FROM public.partenaires
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admin gère toutes les livraisons partenaire" ON public.livraisons_partenaire;
CREATE POLICY "Admin gère toutes les livraisons partenaire"
  ON public.livraisons_partenaire FOR ALL
  USING (mon_role() = 'admin');

-- ─────────────────────────────────────────────────────────────────
-- 4. RÉINITIALISATION MENSUELLE DU COMPTEUR LIVRAISONS PARTENAIRE
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.reset_livraisons_mois_partenaires()
RETURNS VOID AS $$
BEGIN
  UPDATE public.partenaires
  SET livraisons_mois = 0, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────
-- 5. FONCTION : INCRÉMENTER LE COMPTEUR MENSUEL PARTENAIRE
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.incrementer_livraison_partenaire()
RETURNS TRIGGER AS $$
DECLARE
  v_partenaire public.partenaires%ROWTYPE;
BEGIN
  -- Récupérer le partenaire
  SELECT * INTO v_partenaire
  FROM public.partenaires
  WHERE id = NEW.partenaire_id
  FOR UPDATE;

  -- Vérifier la limite mensuelle
  IF v_partenaire.livraisons_mois >= v_partenaire.livraisons_max THEN
    RAISE EXCEPTION 'Limite mensuelle de livraisons atteinte (%). Contactez NYME pour upgrader.',
      v_partenaire.livraisons_max;
  END IF;

  -- Incrémenter le compteur
  UPDATE public.partenaires
  SET livraisons_mois = livraisons_mois + 1, updated_at = NOW()
  WHERE id = NEW.partenaire_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_incrementer_livraison_partenaire ON public.livraisons_partenaire;
CREATE TRIGGER trg_incrementer_livraison_partenaire
  BEFORE INSERT ON public.livraisons_partenaire
  FOR EACH ROW EXECUTE FUNCTION public.incrementer_livraison_partenaire();

-- ─────────────────────────────────────────────────────────────────
-- 6. AJOUT RLS PARTENAIRE SUR LIVRAISONS NYME
-- Un partenaire peut voir les livraisons liées à ses commandes
-- ─────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Partenaire voit livraisons liées" ON public.livraisons;
CREATE POLICY "Partenaire voit livraisons liées"
  ON public.livraisons FOR SELECT
  USING (
    id IN (
      SELECT livraison_app_id
      FROM public.livraisons_partenaire lp
      JOIN public.partenaires p ON p.id = lp.partenaire_id
      WHERE p.user_id = auth.uid()
        AND lp.livraison_app_id IS NOT NULL
    )
  );

-- ─────────────────────────────────────────────────────────────────
-- 7. VÉRIFICATION FINALE
-- ─────────────────────────────────────────────────────────────────

-- Vérifier que les tables existent
SELECT
  'partenaires'          AS table_name,
  COUNT(*)               AS nb_lignes
FROM public.partenaires
UNION ALL
SELECT
  'livraisons_partenaire',
  COUNT(*)
FROM public.livraisons_partenaire
UNION ALL
SELECT
  'utilisateurs (roles)',
  COUNT(DISTINCT role)
FROM public.utilisateurs;
