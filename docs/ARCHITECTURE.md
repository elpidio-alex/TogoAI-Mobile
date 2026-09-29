# Architecture mobile TogoAI

## Choix Riverpod

- Auth + profil = `StreamProvider` / `FutureProvider` naturels
- SSE = `StateNotifier` + subscription annulable (stop)
- Moins de fichiers que Bloc pour 4 features
- Testable via `ProviderScope` overrides

## Flux chat

```
User tape → insert message user (Supabase)
         → POST /chat/stream { question, mode, historique }
         → events SSE → UI
         → insert message assistant + sources (Supabase)
         → update titre conversation
```

## Modes

| UI | API |
|----|-----|
| Base de connaissances | `mode: "rag"` |
| Actu en direct | `mode: "realtime"` |

## Thème / langue

Valeurs DB identiques au web : `systeme|clair|sombre`, `fr|en|ewe`.
