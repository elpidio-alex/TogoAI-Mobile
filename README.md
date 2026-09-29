<!--
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Documentation générale du projet TogoAI Mobile (présentation, stack technique, structure, instructions d'installation et de lancement).
-->

# 🇹🇬 TogoAI Mobile

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend%20%26%20Auth-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%202.x-black)](https://riverpod.dev)
[![GoRouter](https://img.shields.io/badge/Router-GoRouter-blue)](https://pub.dev/packages/go_router)
[![EasyLocalization](https://img.shields.io/badge/i18n-FR%20%7C%20EN%20%7C%20EWE-orange)](https://pub.dev/packages/easy_localization)
[![License](https://img.shields.io/badge/License-Proprietary-red)](#)

> **L'assistant conversationnel intelligent dédié à l'actualité, aux démarches administratives et à la culture du Togo.**  
> Parité fonctionnelle complète avec la plateforme web [togoai.site](https://togoai.site).

---

## 📖 Sommaire

- [Aperçu du Projet](#-aperçu-du-projet)
- [Fonctionnalités Principales](#-fonctionnalités-principales)
- [Architecture & Technologies](#-architecture--technologies)
- [Organisation du Code](#-organisation-du-code)
- [Prérequis](#-prérequis)
- [Configuration des Environnements](#-configuration-des-environnements)
- [Démarrage Rapide](#-démarrage-rapide)
- [Architecture des Flux & Streaming SSE](#-architecture-des-flux--streaming-sse)
- [Tests & Qualité](#-tests--qualité)
- [Génération des Livrables (Build)](#-génération-des-livrables-build)
- [Auteurs](#-auteurs)

---

## 🌟 Aperçu du Projet

**TogoAI Mobile** est une application mobile multiplateforme (Android, iOS, Web) développée avec **Flutter**. Elle offre aux citoyens togolais, à la diaspora et aux voyageurs un accès instantané et contextualisé aux informations vitales du Togo grâce à deux modes d'interrogation propulsés par l'intelligence artificielle :
1. **Mode Base de connaissances (RAG)** : Recherche augmentée par extraction documentaire (procédures administratives, lois, institutions, histoire, culture).
2. **Mode Actu Directe (Temps réel)** : Restitution en direct des dernières dépêches et actualités nationales vérifiées, avec citation systématique des sources journalistiques.

---

## ✨ Fonctionnalités Principales

- 💬 **Messagerie IA en Streaming SSE** : Rendu incrémental fluide des réponses en Server-Sent Events avec gestion des pauses/reprises et réessai.
- 📚 **Transparence Documentaire** : Attribution systématique des sources avec puces interactives ouvrant les articles originaux dans le navigateur natif.
- 🔐 **Authentification Robuste & OAuth** : Connexion par e-mail/mot de passe et Google Sign-In avec gestion des deep links (`io.togoai.app://login-callback/`).
- 🚀 **Tunnel d'Onboarding Intelligent** : Collecte guidée de l'identité légale (Nom/Prénom obligatoires), du nom d'appel familier et de la date de naissance.
- 🗂️ **Gestion Intégrale des Conversations** : Historique synchronisé sur Supabase, recherche instantanée en temps réel, renommage et suppression.
- 🎨 **Design System Togo Épuré** : Palette chromatique inspirée du drapeau togolais (`#0C3C24`, `#1B7A4B`, `#E8B923`, `#D9381E`), mode sombre natif et typographie soignée.
- 🌍 **Support Multilingue Intégral** : Prise en charge native du Français (🇫🇷), de l'Anglais (🇬🇧) et de l'Éwé (🇹🇬), synchronisée avec le profil distant.
- 🛡️ **Sécurité & Soft-Delete RGPD** : Processus de suppression de compte à deux facteurs (mot de passe / ré-authentification OAuth + mot-clé `SUPPRIMER`).

---

## 🛠 Architecture & Technologies

| Domaine | Technologie | Justification Technique |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.x (Dart 3) | Performance 60/120 fps, binaire natif AOT et compilation multi-cibles. |
| **Gestion d'État** | Riverpod 2.x | Programmation réactive, gestion paresseuse des flux SSE et injection sans contexte. |
| **Routage** | GoRouter 14.x | Routage déclaratif, gestion des deep links OAuth et gardes d'authentification. |
| **Backend & BD** | Supabase (PostgreSQL + RLS) | Authentification JWT sécurisée, base PostgREST et politiques d'accès row-level. |
| **Moteur IA** | FastAPI (Python) | Microservice dédié au streaming SSE (`/chat/stream`), RAG et agents IA. |
| **Internationalisation** | EasyLocalization | Gestion fluide des locales et chargement asynchrone des assets JSON. |
| **Thématisation** | Vanilla ThemeExtensions | Design tokens TogoColors immuables avec support clair/sombre dynamique. |

---

## 📁 Organisation du Code

L'architecture du projet respecte les principes de la **Clean Architecture** organisée par fonctionnalités (**Feature-First**) :

```
TogoAI-Mobile/
├── assets/
│   ├── images/                # Logos officiels, icônes et wordmarks
│   └── translations/          # Dictionnaires i18n (fr.json, en.json, ewe.json)
├── docs/
│   └── ARCHITECTURE.md        # Spécifications détaillées de l'architecture logicielle
├── lib/
│   ├── main.dart              # Point d'entrée de l'application et initialisation
│   ├── core/                  # Socle technique transverse
│   │   ├── config/            # AppConfig (--dart-define, URLs, résolutions loopback)
│   │   ├── router/            # Configuration GoRouter et gardes d'accès
│   │   └── theme/             # Tokens TogoColors et ThemeData (clair / sombre)
│   ├── features/              # Modules métiers indépendants
│   │   ├── auth/              # Connexion, inscription, onboarding, flux OAuth
│   │   ├── chat/              # Client SSE streaming, contrôleur réactif, écran de discussion
│   │   ├── conversations/     # Dépôt CRUD Supabase et tiroir latéral
│   │   └── settings/          # Feuille modale des préférences et suppression de compte
│   └── shared/                # Éléments partagés inter-features
│       ├── providers/         # Fournisseurs Riverpod (auth, thème, locale)
│       └── widgets/           # Composants visuels génériques et branding
├── scripts/
│   └── run.ps1                # Script PowerShell d'exécution assistée avec .env
├── test/                      # Tests unitaires et tests de widgets
├── .env.example               # Gabarit des variables d'environnement
├── analysis_options.yaml      # Règles de linter et d'analyse statique Dart
└── pubspec.yaml               # Dépendances et métadonnées du projet
```

---

## 📋 Prérequis

Avant de configurer le projet, assurez-vous d'avoir installé :
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.19.0 ou supérieure)
- [Dart SDK](https://dart.dev/get-dart) (inclus dans Flutter)
- [Android Studio](https://developer.android.com/studio) (avec Android SDK & émulateur configuré)
- [VS Code](https://code.visualstudio.com/) (avec extensions Flutter & Dart)
- Un compte [Supabase](https://supabase.com) avec le schéma de tables déployé

---

## ⚙️ Configuration des Environnements

1. Dupliquez le fichier de configuration modèle :
   ```bash
   cp .env.example .env
   ```
   *(ou sous PowerShell Windows : `Copy-Item .env.example .env`)*

2. Éditez le fichier `.env` avec vos paramètres :
   ```env
   # Supabase
   SUPABASE_URL=https://votre-projet.supabase.co
   SUPABASE_ANON_KEY=votre_cle_anonyme_publique

   # Backend FastAPI
   BACKEND_URL=http://localhost:8000

   # Redirection OAuth
   OAUTH_REDIRECT_URL=io.togoai.app://login-callback/
   ```

> [!NOTE]  
> Sur l'émulateur officiel Android, `localhost` ou `127.0.0.1` pointe vers l'émulateur lui-même. L'application **réécrit automatiquement** cette adresse vers `10.0.2.2:8000` via [AppConfig.resolvedBackendUrl](file:///c:/Users/amous/Desktop/Projets/TogoAI-Mobile/lib/core/config/app_config.dart#L51).

---

## 🚀 Démarrage Rapide

### 1. Installation des dépendances
```bash
flutter pub get
```

### 2. Exécution avec le script automatisé (Recommandé)
Le script PowerShell `scripts/run.ps1` lit automatiquement les variables de votre fichier `.env` et les injecte via `--dart-define` :

- **Sur navigateur Chrome (Web) :**
  ```powershell
  .\scripts\run.ps1
  ```
- **Sur émulateur ou appareil Android :**
  ```powershell
  .\scripts\run.ps1 -device android
  ```
- **Sur application bureau Windows :**
  ```powershell
  .\scripts\run.ps1 -device windows
  ```

### 3. Exécution manuelle via CLI Flutter
```bash
flutter run --dart-define-from-file=.env
```

---

## 🔄 Architecture des Flux & Streaming SSE

Le chat interactif repose sur une communication unidirectionnelle persistante en **Server-Sent Events (SSE)** :

```
[Utilisateur]  ─────────── Saisie de la question ───────────► [ChatController]
                                                                     │
  ┌──────────────────────────────────────────────────────────────────┴───────────────────────────────────┐
  │                                                                                                      │
  ▼ (1. Insertion Optimiste)                                                                             ▼ (2. Persistance locale)
[ChatViewState] ◄─── Affiche bulle utilisateur + placeholder assistant                             [Supabase PostgREST]
                                                                                                         │
  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────┘
  ▼ (3. Requête HTTP POST /chat/stream)
[FastAPI Backend] ─────────► Traitement RAG / Realtime & Inférence LLM
        │
        ├── event: sources ──► Métadonnées documentaires (titre, lien, source)
        ├── event: chunk   ──► Fragment de texte généré par l'IA (concaténation fluide)
        ├── event: done    ──► Fin du flux de streaming
        │
        ▼
[ChatController] ──────────► (4. Persistance finale du message complet et des sources) ──────────► [Supabase]
```

---

## 🧪 Tests & Qualité

Le projet intègre une suite de tests automatisés validant la logique métier et les composants visuels.

Exécuter la suite de tests :
```bash
flutter test
```

Vérifier la conformité du code et du typage statique :
```bash
flutter analyze
```

---

## 📦 Génération des Livrables (Build)

### Android
- **Fichier APK universel (Release) :**
  ```bash
  flutter build apk --release --dart-define-from-file=.env
  ```
- **Android App Bundle (Google Play Store) :**
  ```bash
  flutter build appbundle --release --dart-define-from-file=.env
  ```

### Web
- **Production Bundle (HTML/JS/CanvasKit) :**
  ```bash
  flutter build web --release --dart-define-from-file=.env
  ```

### iOS
- **Archive IPA (App Store / TestFlight) :**
  ```bash
  flutter build ipa --release --dart-define-from-file=.env
  ```

---

## 👥 Auteurs

Projet conçu et développé par :

- **Elpidio Alexis AMOUSSOU**  
  📧 [amoussouelpidioalexis@gmail.com](mailto:amoussouelpidioalexis@gmail.com)
- **Eli Yannick HOVI**  
  📧 [yannickeli2007@gmail.com](mailto:yannickeli2007@gmail.com)

---

*© 2026 TogoAI Mobile. Tous droits réservés.*
