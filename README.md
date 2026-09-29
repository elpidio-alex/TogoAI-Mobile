# TogoAI Mobile (Flutter)

Assistant conversationnel IA pour l'actualité et les infos pratiques du Togo.
Parité fonctionnelle avec [togoai.vercel.app](https://togoai.vercel.app),
même backend FastAPI + Supabase.

## Stack

| Couche | Choix |
|--------|--------|
| Framework | Flutter 3.x |
| État | **Riverpod** — streams SSE, auth, listes async ; moins de boilerplate que Bloc pour ce périmètre |
| Navigation | go_router |
| Auth | supabase_flutter (email + Google OAuth) |
| i18n | easy_localization (FR / EN / Éwé) — JSON portés depuis le web |
| Chat | SSE natif `POST {BACKEND_URL}/chat/stream` |

## Démarrage

1. Installer Flutter stable et ajouter au `PATH`.
2. Copier `.env.example` vers `.env`.
3. Lancer :

```bash
flutter pub get
```

**Chrome / Windows** (backend `http://localhost:8000`) :

```powershell
.\scripts\run.ps1
```

**Émulateur Android** (Android Studio) : `localhost` ne pointe pas vers le PC.
L'app réécrit automatiquement vers `http://10.0.2.2:8000`. HTTP debug est autorisé.

```powershell
# 1. Démarrer un AVD dans Android Studio (Device Manager)
# 2. Backend FastAPI déjà sur :8000
.\scripts\run.ps1 -device android
```

Dans Android Studio (plugin Flutter) : Run → Edit Configurations → Additional
run args : `--dart-define-from-file=.env`. Sans ça, Supabase est vide et le
backend tombe sur Render.

**Téléphone physique** : mettre `BACKEND_URL=http://<IP-LAN-du-PC>:8000` dans
`.env` et faire écouter FastAPI sur `0.0.0.0:8000`.

4. Configurer le deep link OAuth `io.togoai.app://login-callback/` dans Supabase
   (Redirect URLs) et sur Android/iOS.

## Référence web (ne pas committer)

Le dossier `TogoAI/` (backend + frontend Next.js) est une **référence locale**
exclue via `.gitignore`. Lire ce code avant tout appel réseau ; ne jamais
inventer d'endpoint.

## Architecture chat (important)

Le web appelle `POST /api/chat` (Next.js BFF, cookies) qui proxy vers FastAPI
`POST /chat` puis simule le streaming côté navigateur.

L'app mobile :
1. Persiste conversations/messages via **Supabase client** (RLS).
2. Stream via FastAPI **`POST /chat/stream`** (événements `sources` / `chunk` /
   `done` / `error`).

### Écart backend à combler (rétrocompatible)

FastAPI n'accepte aujourd'hui que `X-Internal-API-Key` (secret serveur).
**Ne pas embarquer cette clé dans l'APK/IPA.**

Proposition rétrocompatible (à faire côté FastAPI, sans casser le web) :

- Accepter **soit** `X-Internal-API-Key` **soit** `Authorization: Bearer <JWT Supabase>`
  (vérification JWKS / secret Supabase).

Sans ce patch, le streaming mobile ne fonctionne en prod que si
`INTERNAL_API_KEY` est vide (dev) ou via un BFF dédié.

### Endpoints manquants pour le mobile

| Besoin | Statut |
|--------|--------|
| Auth email / Google | OK via Supabase SDK |
| CRUD conversations / messages | OK via tables Supabase **si RLS le permet** (le web utilise parfois service role pour delete cascade) |
| Chat streaming | `/chat/stream` existe — **auth mobile manquante** (JWT) |
| Suppression compte | Web : `POST /api/account/delete` (cookies + password). **Pas d'équivalent Bearer** — à porter (Edge Function ou route Next Bearer) |
| Génération titre Gemini | Web only dans `/api/chat` — mobile utilise un titre heuristique (comme fallback web) |

## Structure

```
lib/
  core/           config, theme, router
  features/
    auth/
    chat/         SSE client + écran
    conversations/
    settings/
  shared/         widgets, providers
assets/
  images/         logos
  translations/   fr.json, en.json, ewe.json
```

## Écrans

1. Login / Signup (header dégradé + formulaire)
2. Onboarding : nom-prénom → nom d'appel (skippable) → date de naissance (skippable)
3. Chat (empty state, modes `rag` / `realtime`, composer + SSE)
4. Drawer conversations
5. Paramètres (profil, thème, langue, logout, soft-delete compte)

## Soft-delete compte

Même logique métier que le web (confirmation `SUPPRIMER`, re-auth password ou Google < 5 min).
Le **ban admin** (service role) n'est pas fait côté mobile ; `deleted_at` suffit pour bloquer le login.
