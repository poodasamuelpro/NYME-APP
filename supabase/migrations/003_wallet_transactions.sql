-- Table des portefeuilles (wallets)
-- Cette table stocke le solde actuel de chaque utilisateur.
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    solde NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (solde >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour améliorer les performances des requêtes sur user_id
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);

-- Fonction pour mettre à jour le champ updated_at automatiquement
CREATE OR REPLACE FUNCTION public.update_wallets_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour la mise à jour automatique de updated_at
CREATE TRIGGER update_wallets_updated_at_trigger
BEFORE UPDATE ON public.wallets
FOR EACH ROW EXECUTE FUNCTION public.update_wallets_updated_at();

-- Table des transactions de portefeuille (wallet_transactions)
-- Cette table enregistre toutes les opérations de crédit/débit sur les portefeuilles.
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL, -- 'recharge', 'retrait', 'gain_course', 'paiement_course', 'commission'
    montant NUMERIC(12, 2) NOT NULL,
    solde_avant NUMERIC(12, 2) NOT NULL,
    solde_apres NUMERIC(12, 2) NOT NULL,
    reference TEXT, -- Référence externe (ex: ID de transaction Mobile Money, Stripe)
    note TEXT, -- Description de la transaction
    livraison_id UUID REFERENCES public.livraisons(id) ON DELETE SET NULL, -- Lien vers une livraison si applicable
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'completed', 'failed', 'cancelled', 'confirmed'
    payment_method TEXT, -- 'cash', 'mobile_money', 'carte', 'wallet', 'virement_bancaire'
    idempotency_key UUID UNIQUE DEFAULT uuid_generate_v4(), -- Clé pour éviter les doubles paiements
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON public.wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_livraison_id ON public.wallet_transactions(livraison_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_status ON public.wallet_transactions(status);

-- Fonction pour mettre à jour le champ updated_at automatiquement
CREATE OR REPLACE FUNCTION public.update_wallet_transactions_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour la mise à jour automatique de updated_at
CREATE TRIGGER update_wallet_transactions_updated_at_trigger
BEFORE UPDATE ON public.wallet_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_wallet_transactions_updated_at();

-- Fonction pour gérer les transactions atomiques et la vérification du solde
CREATE OR REPLACE FUNCTION public.process_wallet_transaction(
    p_user_id UUID,
    p_type TEXT,
    p_montant NUMERIC,
    p_reference TEXT DEFAULT NULL,
    p_note TEXT DEFAULT NULL,
    p_livraison_id UUID DEFAULT NULL,
    p_payment_method TEXT DEFAULT NULL,
    p_idempotency_key UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_current_solde NUMERIC(12, 2);
    v_new_solde NUMERIC(12, 2);
    v_transaction_id UUID;
BEGIN
    -- Verrouiller la ligne du portefeuille pour éviter les conditions de concurrence
    SELECT solde INTO v_current_solde FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;

    IF NOT FOUND THEN
        -- Créer un portefeuille si l'utilisateur n'en a pas (solde initial 0)
        INSERT INTO public.wallets (user_id, solde) VALUES (p_user_id, 0.00) RETURNING solde INTO v_current_solde;
    END IF;

    -- Calculer le nouveau solde
    v_new_solde = v_current_solde + p_montant;

    -- Vérifier le solde pour les débits (montant négatif)
    IF p_montant < 0 AND v_new_solde < 0 THEN
        RAISE EXCEPTION 'Solde insuffisant pour la transaction. Solde actuel: %, Montant: %', v_current_solde, p_montant;
    END IF;

    -- Mettre à jour le solde du portefeuille
    UPDATE public.wallets
    SET solde = v_new_solde
    WHERE user_id = p_user_id;

    -- Enregistrer la transaction
    INSERT INTO public.wallet_transactions (
        user_id, type, montant, solde_avant, solde_apres, reference, note, livraison_id, status, payment_method, idempotency_key
    ) VALUES (
        p_user_id, p_type, p_montant, v_current_solde, v_new_solde, p_reference, p_note, p_livraison_id, 'completed', p_payment_method, COALESCE(p_idempotency_key, uuid_generate_v4())
    ) RETURNING id INTO v_transaction_id;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- RLS pour la table wallets
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own wallet." ON public.wallets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own wallet (via function)." ON public.wallets
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS pour la table wallet_transactions
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own wallet transactions." ON public.wallet_transactions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own wallet transactions (via function)." ON public.wallet_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS pour la table coursiers (ajustement pour le solde)
-- Assurez-vous que la table coursiers existe et a une colonne user_id ou id qui référence auth.users(id)
-- Si la table coursiers utilise 'id' comme FK vers auth.users, ajustez la politique en conséquence.
-- Supposons que 'id' dans 'coursiers' est la FK vers 'auth.users(id)'
ALTER TABLE public.coursiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Couriers can view their own balance and transactions." ON public.coursiers
  FOR SELECT USING (auth.uid() = id);

-- RLS pour la table livraisons (ajustement pour le statut de paiement)
ALTER TABLE public.livraisons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Clients can view their own delivery payment status." ON public.livraisons
  FOR SELECT USING (auth.uid() = client_id);

CREATE POLICY "Couriers can view payment status for their assigned deliveries." ON public.livraisons
  FOR SELECT USING (auth.uid() = coursier_id);

-- Admin RLS policies (à ajouter dans un fichier séparé si nécessaire, ou ici pour simplicité)
-- Exemple pour les admins: les admins peuvent tout voir et modifier
-- CREATE POLICY "Admins can view all wallets." ON public.wallets FOR SELECT USING (auth.role() = 'admin');
-- CREATE POLICY "Admins can manage all wallets." ON public.wallets FOR ALL USING (auth.role() = 'admin');

-- Ajout de la colonne 'wallet_id' à la table 'users' si elle n'existe pas déjà
-- Cela permettrait une liaison directe et rapide entre un utilisateur et son portefeuille.
-- ALTER TABLE public.users ADD COLUMN IF NOT EXISTS wallet_id UUID REFERENCES public.wallets(id) UNIQUE;
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_users_wallet_id ON public.users(wallet_id);

-- Pour l'intégration avec Google Auth, Supabase gère déjà l'authentification des utilisateurs.
-- Les tables 'users', 'wallets' et 'wallet_transactions' sont liées à 'auth.users.id'.
-- Aucune modification SQL directe n'est nécessaire pour Google Auth ici, car c'est géré au niveau de l'application et de Supabase Auth.

-- Pour la validation des dossiers des coursiers, nous allons ajouter une table pour les documents
CREATE TABLE IF NOT EXISTS public.courier_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coursier_id UUID REFERENCES public.coursiers(id) ON DELETE CASCADE NOT NULL,
    document_type TEXT NOT NULL, -- 'cni_recto', 'cni_verso', 'permis', 'carte_grise'
    file_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    rejection_reason TEXT, -- Raison du rejet si applicable
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    validated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Admin qui a validé
    validated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_courier_documents_coursier_id ON public.courier_documents(coursier_id);
CREATE INDEX IF NOT EXISTS idx_courier_documents_status ON public.courier_documents(status);

-- RLS pour courier_documents
ALTER TABLE public.courier_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Couriers can view and upload their own documents." ON public.courier_documents
  FOR ALL USING (auth.uid() = coursier_id) WITH CHECK (auth.uid() = coursier_id);

CREATE POLICY "Admins can view and update all courier documents." ON public.courier_documents
  FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

-- Ajout de la colonne 'status_validation_documents' à la table 'coursiers' pour un suivi global
ALTER TABLE public.coursiers ADD COLUMN IF NOT EXISTS status_validation_documents TEXT NOT NULL DEFAULT 'pending'; -- 'pending', 'approved', 'rejected'

-- Fonction pour mettre à jour le statut global de validation des documents du coursier
CREATE OR REPLACE FUNCTION public.update_courier_validation_status() RETURNS TRIGGER AS $$
DECLARE
    v_pending_docs INT;
    v_rejected_docs INT;
BEGIN
    SELECT COUNT(*) INTO v_pending_docs FROM public.courier_documents WHERE coursier_id = NEW.coursier_id AND status = 'pending';
    SELECT COUNT(*) INTO v_rejected_docs FROM public.courier_documents WHERE coursier_id = NEW.coursier_id AND status = 'rejected';

    IF v_rejected_docs > 0 THEN
        UPDATE public.coursiers SET status_validation_documents = 'rejected' WHERE id = NEW.coursier_id;
    ELSIF v_pending_docs = 0 THEN
        UPDATE public.coursiers SET status_validation_documents = 'approved' WHERE id = NEW.coursier_id;
    ELSE
        UPDATE public.coursiers SET status_validation_documents = 'pending' WHERE id = NEW.coursier_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour le statut de validation des documents du coursier après chaque modification de document
CREATE TRIGGER update_courier_validation_status_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.courier_documents
FOR EACH ROW EXECUTE FUNCTION public.update_courier_validation_status();

-- Ajout de la colonne 'commission_due' à la table 'coursiers' pour suivre la commission due à l'entreprise
ALTER TABLE public.coursiers ADD COLUMN IF NOT EXISTS commission_due NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (commission_due >= 0);

-- Fonction pour calculer et ajouter la commission due après chaque course payée par le client
CREATE OR REPLACE FUNCTION public.calculate_and_add_commission() RETURNS TRIGGER AS $$
DECLARE
    v_commission_rate NUMERIC(5, 2); -- Taux de commission (ex: 0.15 pour 15%)
    v_commission_amount NUMERIC(12, 2);
BEGIN
    -- Récupérer le taux de commission (peut venir d'une table de configuration ou être fixe)
    -- Pour l'exemple, utilisons un taux fixe de 15%
    v_commission_rate := 0.15;

    IF NEW.status = 'livree' AND NEW.statut_paiement = 'paye' AND NEW.coursier_id IS NOT NULL THEN
        v_commission_amount := NEW.prix_final * v_commission_rate;

        -- Mettre à jour la commission due du coursier
        UPDATE public.coursiers
        SET commission_due = commission_due + v_commission_amount
        WHERE id = NEW.coursier_id;

        -- Enregistrer la transaction de commission
        PERFORM public.process_wallet_transaction(
            NEW.coursier_id,
            'commission',
            -v_commission_amount, -- Montant négatif car c'est un débit pour le coursier
            'LIVRAISON_' || NEW.id,
            'Commission sur livraison ' || NEW.id,
            NEW.id,
            'wallet'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour calculer et ajouter la commission après chaque livraison payée
CREATE TRIGGER calculate_and_add_commission_trigger
AFTER UPDATE OF status, statut_paiement ON public.livraisons
FOR EACH ROW EXECUTE FUNCTION public.calculate_and_add_commission();

-- Fonction pour gérer le retrait des fonds par le coursier (tous les 2 jours)
CREATE OR REPLACE FUNCTION public.request_courier_withdrawal(
    p_coursier_id UUID,
    p_montant NUMERIC,
    p_idempotency_key UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_last_withdrawal_date TIMESTAMPTZ;
    v_transaction_id UUID;
    v_current_solde NUMERIC(12, 2);
BEGIN
    -- Vérifier la dernière date de retrait pour ce coursier
    SELECT MAX(created_at) INTO v_last_withdrawal_date
    FROM public.wallet_transactions
    WHERE user_id = p_coursier_id AND type = 'retrait' AND status = 'completed';

    -- Si un retrait a déjà eu lieu, vérifier la période de 2 jours
    IF v_last_withdrawal_date IS NOT NULL AND v_last_withdrawal_date > (NOW() - INTERVAL '2 days') THEN
        RAISE EXCEPTION 'Un retrait a déjà été effectué il y a moins de 2 jours. Veuillez attendre.';
    END IF;

    -- Vérifier le solde avant de procéder au retrait
    SELECT solde INTO v_current_solde FROM public.wallets WHERE user_id = p_coursier_id;

    IF v_current_solde < p_montant THEN
        RAISE EXCEPTION 'Solde insuffisant pour le retrait. Solde actuel: %, Montant demandé: %', v_current_solde, p_montant;
    END IF;

    -- Débiter le portefeuille et enregistrer la transaction
    v_transaction_id := public.process_wallet_transaction(
        p_coursier_id,
        'retrait',
        -p_montant, -- Montant négatif pour un débit
        'RETRAIT_' || p_coursier_id || '_' || NOW()::DATE,
        'Retrait de fonds',
        NULL,
        'virement_bancaire', -- Ou autre méthode de retrait
        p_idempotency_key
    );

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- Ajout de la colonne 'google_id' à la table 'users' pour l'intégration Google Auth
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;

-- RLS pour la table users (ajustement pour google_id)
CREATE POLICY "Users can update their own google_id." ON public.users
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Mise à jour de la table 'livraisons' pour inclure le mode de paiement 'wallet'
-- La colonne 'mode_paiement' existe déjà, il faut s'assurer que 'wallet' est une valeur acceptée.
-- Si la colonne est de type ENUM, il faudrait ALTER TYPE pour ajouter 'wallet'.
-- Si c'est TEXT, il suffit de l'utiliser.

-- Ajout de la colonne 'payment_api_reference' à la table 'livraisons' pour stocker la référence de transaction externe
ALTER TABLE public.livraisons ADD COLUMN IF NOT EXISTS payment_api_reference TEXT;

-- Ajout de la colonne 'payment_api_status' à la table 'livraisons' pour le statut de la transaction externe
ALTER TABLE public.livraisons ADD COLUMN IF NOT EXISTS payment_api_status TEXT; -- 'pending', 'success', 'failed'

-- Ajout de la colonne 'is_paid_to_courier' à la table 'livraisons' pour suivre si le coursier a été payé (pour les paiements client via wallet/carte)
ALTER TABLE public.livraisons ADD COLUMN IF NOT EXISTS is_paid_to_courier BOOLEAN NOT NULL DEFAULT FALSE;

-- Fonction pour gérer le paiement du coursier après une livraison réussie et payée par le client (hors cash)
CREATE OR REPLACE FUNCTION public.pay_courier_for_delivery(
    p_livraison_id UUID,
    p_idempotency_key UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_livraison_data public.livraisons;
    v_transaction_id UUID;
    v_courier_id UUID;
    v_montant_gain NUMERIC(12, 2);
BEGIN
    SELECT * INTO v_livraison_data FROM public.livraisons WHERE id = p_livraison_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Livraison non trouvée.';
    END IF;

    IF v_livraison_data.status != 'livree' THEN
        RAISE EXCEPTION 'La livraison n''est pas encore livrée.';
    END IF;

    IF v_livraison_data.statut_paiement != 'paye' THEN
        RAISE EXCEPTION 'Le client n''a pas encore payé cette livraison.';
    END IF;

    IF v_livraison_data.is_paid_to_courier THEN
  
(Content truncated due to size limit. Use line ranges to read remaining content)