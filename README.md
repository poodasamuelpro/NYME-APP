# 🚀 NYME — Application de Livraison Rapide & Intelligente

> Stack : Flutter · Supabase · Mapbox/Google Maps/OSRM · Firebase FCM · CinetPay

---

## 📁 Structure du projet

```
nyme_app/
├── lib/
│   ├── main.dart                          # Point d'entrée
│   ├── app.dart                           # Configuration app, thème, router
│   ├── config/
│   │   ├── supabase_config.dart           # URLs et clés Supabase
│   │   ├── router.dart                    # Toutes les routes GoRouter
│   │   └── firebase_options.dart          # Config Firebase (auto-générée)
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart            # Palette de couleurs NYME
│   │   │   └── app_strings.dart           # Tous les textes en français
│   │   ├── theme/
│   │   │   └── app_theme.dart             # Thème Material 3
│   │   ├── utils/
│   │   │   ├── format_prix.dart           # Formater les prix en FCFA
│   │   │   └── helpers.dart               # Fonctions utilitaires
│   │   └── errors/
│   │       └── app_exception.dart         # Gestion centralisée des erreurs
│   ├── data/
│   │   ├── models/
│   │   │   └── models.dart                # Tous les modèles Dart
│   │   └── repositories/
│   │       ├── auth_repository.dart       # Auth Supabase complète
│   │       ├── livraison_repository.dart  # CRUD livraisons + propositions
│   │       └── chat_repository.dart       # Messagerie temps réel
│   ├── services/
│   │   ├── map_service.dart               # Rotation 3 APIs cartes
│   │   ├── location_service.dart          # GPS + tracking temps réel
│   │   ├── notification_service.dart      # Firebase FCM
│   │   └── call_service.dart              # Appels natifs + WhatsApp
│   └── presentation/
│       ├── screens/
│       │   ├── auth/                      # Connexion, inscription, OTP, vérif coursier
│       │   ├── client/                    # Accueil, TB, nouvelle livraison, suivi
│       │   ├── coursier/                  # Accueil, carte GPS, TB, gains, profil
│       │   ├── chat/                      # Liste conversations + chat temps réel
│       │   ├── admin/                     # Dashboard admin
│       │   └── shared/                    # Notifications, paramètres
│       └── widgets/
│           └── common/                    # NymeButton, NymeTextField, StatutBadge...
├── supabase/
│   ├── migrations/
│   │   ├── 001_schema_complet.sql         # Toutes les tables + fonctions SQL
│   │   └── 002_rls_policies.sql           # Sécurité Row Level Security
│   └── DOCUMENTATION_SUPABASE.md         # Guide configuration complet
├── assets/
│   ├── images/
│   └── icons/
└── pubspec.yaml                           # Dépendances Flutter
```

---

## ⚡ Fonctionnalités

### 👤 Client
- Inscription / Connexion (email + OTP SMS)
- Créer une livraison (pour soi ou pour quelqu'un)
- Photos du colis, instructions, destinataire complet
- **Négociation de prix** style InDrive
- Course immédiate, urgente ou programmée (jusqu'à 15j)
- Suivi GPS en temps réel sur carte
- Chat avec le coursier
- Appel téléphonique et WhatsApp
- Adresses favorites (10 max)
- Contacts favoris (destinataires fréquents)
- Coursiers favoris
- Notation et commentaires
- Signalement
- Notifications push

### 🏍️ Coursier
- Inscription avec vérification documents (CNI, permis, carte grise)
- Dashboard avec stats (courses, note, gains)
- Toggle disponible/hors ligne
- Voir livraisons disponibles à proximité
- Proposer un prix / accepter
- Carte GPS avec itinéraire temps réel
- Mise à jour des statuts (en route, récupéré, livré)
- Wallet + historique des gains
- Chat avec le client

### 🛡️ Admin
- Valider les dossiers de vérification des coursiers
- Gérer les utilisateurs
- Traiter les signalements / litiges
- Statistiques globales
- Configurer les tarifs

### 🗺️ Maps (Rotation automatique)
1. **Mapbox** (50k req/mois gratuit) — priorité
2. **Google Maps** (~200$/mois offerts) — secours
3. **OSRM/OpenStreetMap** (illimité gratuit) — fallback

---

## 🚀 Démarrage rapide

### 1. Cloner et installer
```bash
git clone https://github.com/votre-user/nyme_app
cd nyme_app
flutter pub get
```

### 2. Configurer Supabase
Voir `supabase/DOCUMENTATION_SUPABASE.md` pour le guide complet.

Remplir `lib/config/supabase_config.dart` :
```dart
static const String url = 'https://VOTRE_PROJECT_ID.supabase.co';
static const String anonKey = 'VOTRE_ANON_KEY';
```

### 3. Configurer Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 4. Configurer les APIs cartes
Dans `lib/services/map_service.dart` :
```dart
static const String _mapboxToken = 'VOTRE_TOKEN_MAPBOX';
static const String _googleKey = 'VOTRE_CLE_GOOGLE_MAPS';
```

### 5. Lancer
```bash
flutter run
```

---

## 🔧 Technologies utilisées

| Tech | Usage |
|------|-------|
| Flutter 3.x | App mobile iOS & Android |
| Supabase | Auth, BDD PostgreSQL, Realtime, Storage |
| Firebase FCM | Notifications push |
| Mapbox | Cartes et itinéraires (principal) |
| Google Maps | Cartes et itinéraires (secours) |
| OSRM | Itinéraires gratuits (fallback) |
| CinetPay | Paiement Mobile Money |
| Flutter Riverpod | State management |
| GoRouter | Navigation |
| flutter_map | Rendu carte OpenStreetMap |
| Geolocator | GPS temps réel |

---

## 📞 Contact

**NYME** — Livraison Rapide & Intelligente  
Développé pour l'Afrique de l'Ouest 🌍
