-- ═══════════════════════════════════════════════════════════════════
-- NYME - Row Level Security (RLS) - Sécurité complète
-- Exécuter APRÈS le fichier 001_schema_complet.sql
-- ═══════════════════════════════════════════════════════════════════

-- Activer RLS sur toutes les tables
ALTER TABLE utilisateurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE coursiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicules ENABLE ROW LEVEL SECURITY;
ALTER TABLE adresses_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts_favoris ENABLE ROW LEVEL SECURITY;
ALTER TABLE coursiers_favoris ENABLE ROW LEVEL SECURITY;
ALTER TABLE livraisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE statuts_livraison ENABLE ROW LEVEL SECURITY;
ALTER TABLE propositions_prix ENABLE ROW LEVEL SECURITY;
ALTER TABLE localisation_coursier ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE paiements ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE signalements ENABLE ROW LEVEL SECURITY;
ALTER TABLE logs_appels ENABLE ROW LEVEL SECURITY;

-- Helper : récupérer le rôle de l'utilisateur courant
CREATE OR REPLACE FUNCTION mon_role()
RETURNS TEXT AS $$
  SELECT role FROM utilisateurs WHERE id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ═══════════════════════════════════════════════════════════════════
-- UTILISATEURS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Voir son propre profil" ON utilisateurs
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "Voir profil public des autres" ON utilisateurs
  FOR SELECT USING (est_actif = TRUE);

CREATE POLICY "Modifier son propre profil" ON utilisateurs
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "Admin peut tout voir" ON utilisateurs
  FOR ALL USING (mon_role() = 'admin');

-- ═══════════════════════════════════════════════════════════════════
-- COURSIERS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Coursier voit son profil" ON coursiers
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "Clients voient coursiers disponibles" ON coursiers
  FOR SELECT USING (statut = 'disponible' AND statut_verification = 'verifie');

CREATE POLICY "Coursier met à jour son statut" ON coursiers
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "Admin gère les coursiers" ON coursiers
  FOR ALL USING (mon_role() = 'admin');

-- ═══════════════════════════════════════════════════════════════════
-- VEHICULES
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Coursier gère son véhicule" ON vehicules
  FOR ALL USING (coursier_id = auth.uid());

CREATE POLICY "Admin voit tous les véhicules" ON vehicules
  FOR ALL USING (mon_role() = 'admin');

-- ═══════════════════════════════════════════════════════════════════
-- ADRESSES FAVORITES
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Gérer ses propres adresses" ON adresses_favorites
  FOR ALL USING (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════
-- CONTACTS FAVORIS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Gérer ses propres contacts" ON contacts_favoris
  FOR ALL USING (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════
-- COURSIERS FAVORIS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Gérer ses coursiers favoris" ON coursiers_favoris
  FOR ALL USING (client_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════
-- LIVRAISONS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Client voit ses livraisons" ON livraisons
  FOR SELECT USING (client_id = auth.uid());

CREATE POLICY "Coursier voit livraisons disponibles et ses courses" ON livraisons
  FOR SELECT USING (
    statut = 'en_attente'
    OR coursier_id = auth.uid()
  );

CREATE POLICY "Client crée une livraison" ON livraisons
  FOR INSERT WITH CHECK (client_id = auth.uid());

CREATE POLICY "Coursier accepte et met à jour une livraison" ON livraisons
  FOR UPDATE USING (
    coursier_id = auth.uid()
    OR (statut = 'en_attente' AND mon_role() = 'coursier')
  );

CREATE POLICY "Client annule sa livraison" ON livraisons
  FOR UPDATE USING (client_id = auth.uid() AND statut IN ('en_attente', 'acceptee'));

CREATE POLICY "Admin gère toutes les livraisons" ON livraisons
  FOR ALL USING (mon_role() = 'admin');

-- ═══════════════════════════════════════════════════════════════════
-- PROPOSITIONS DE PRIX
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Voir propositions de ses livraisons" ON propositions_prix
  FOR SELECT USING (
    auteur_id = auth.uid()
    OR EXISTS (SELECT 1 FROM livraisons WHERE id = livraison_id AND client_id = auth.uid())
  );

CREATE POLICY "Proposer un prix" ON propositions_prix
  FOR INSERT WITH CHECK (auteur_id = auth.uid());

CREATE POLICY "Accepter une proposition (client)" ON propositions_prix
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM livraisons WHERE id = livraison_id AND client_id = auth.uid())
  );

-- ═══════════════════════════════════════════════════════════════════
-- LOCALISATION COURSIER
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Coursier insère sa position" ON localisation_coursier
  FOR INSERT WITH CHECK (coursier_id = auth.uid());

CREATE POLICY "Voir position des coursiers en course" ON localisation_coursier
  FOR SELECT USING (
    coursier_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM livraisons
      WHERE coursier_id = localisation_coursier.coursier_id
        AND client_id = auth.uid()
        AND statut NOT IN ('livree', 'annulee')
    )
  );

-- ═══════════════════════════════════════════════════════════════════
-- MESSAGES
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Lire ses messages" ON messages
  FOR SELECT USING (
    expediteur_id = auth.uid() OR destinataire_id = auth.uid()
  );

CREATE POLICY "Envoyer un message" ON messages
  FOR INSERT WITH CHECK (expediteur_id = auth.uid());

CREATE POLICY "Marquer message comme lu" ON messages
  FOR UPDATE USING (destinataire_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════
-- WALLETS & TRANSACTIONS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Voir son wallet" ON wallets
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Voir ses transactions" ON transactions_wallet
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Admin gère les wallets" ON wallets
  FOR ALL USING (mon_role() = 'admin');

-- ═══════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Voir ses notifications" ON notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Marquer notif comme lue" ON notifications
  FOR UPDATE USING (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════
-- SIGNALEMENTS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Faire un signalement" ON signalements
  FOR INSERT WITH CHECK (signalant_id = auth.uid());

CREATE POLICY "Voir ses signalements" ON signalements
  FOR SELECT USING (signalant_id = auth.uid());

CREATE POLICY "Admin gère les signalements" ON signalements
  FOR ALL USING (mon_role() = 'admin');

-- ═══════════════════════════════════════════════════════════════════
-- LOGS APPELS
-- ═══════════════════════════════════════════════════════════════════
CREATE POLICY "Insérer log appel" ON logs_appels
  FOR INSERT WITH CHECK (appelant_id = auth.uid());

CREATE POLICY "Voir ses logs" ON logs_appels
  FOR SELECT USING (appelant_id = auth.uid() OR destinataire_id = auth.uid());

CREATE POLICY "Admin voit tous les logs" ON logs_appels
  FOR ALL USING (mon_role() = 'admin');
