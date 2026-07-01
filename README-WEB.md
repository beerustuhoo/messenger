# Web Messenger 🌐

A browser-based messenger built with **Flutter Web**, sharing the same codebase and PostgreSQL database as [Mobile Messenger](README.md). Real-time messaging uses Socket.IO; sensitive data is encrypted at rest with **AES-256-GCM**.

| Layer | Stack |
|-------|-------|
| Web client | Flutter 3.x (Chrome / Edge / Firefox), Provider |
| Mobile client | Same `mobile/` project (`kIsWeb` → `WebShell`) |
| Backend | Node.js, Express, Socket.IO, PostgreSQL |
| Deployment (local) | nginx via Docker (`http://localhost:8080`) |
| Deployment (public) | [Render](RENDER.md) — one HTTPS URL for web + API + mobile |
| Email (dev) | Mailhog → http://localhost:8025 |

**Local:** http://localhost:8080 (web) · http://localhost:3000 (API)  
**Render:** `https://YOUR-SERVICE.onrender.com` (web + API + mobile Server URL)

---

## Project overview

Web Messenger extends Mobile Messenger with a responsive web UI and web-only features:

- **Sidebar + dual chat panes** — open up to **2 chats** on one page
- **Group chats** — create groups, invite members, accept/decline invitations
- **Message search** — search text in direct and group chats; highlight matches; navigate with ↑/↓
- **Group polls** — public or anonymous; vote, change vote, retract vote
- **Error banner** — API/network failures show dismissible feedback; app keeps last stable UI state

All mobile features (registration, profiles, direct invites, media, receipts, typing indicators, encryption) work on web through the shared backend.

### Repository layout

```
mobile/                 Flutter app (mobile + web from one codebase)
  lib/
    main.dart             Platform entry — WebShell on web, HomeScreen on mobile
    screens/              UI (web_shell.dart, chat_screen.dart, auth_screen.dart, …)
    providers/            AppState, ThemeProvider
    models/               Data models
    services/             API, socket, storage, notifications
    widgets/              Reusable components (avatar, poll_card, error_banner)
    utils/                Platform helpers (voice_recorder, image_bytes)
backend/                Express API + Socket.IO + migrations
  docker-compose.yml    db, api, mailhog, web (nginx)
  src/crypto.js         AES-256-GCM encryption
build-web.ps1           Build Flutter web + start nginx container
README.md               Mobile Messenger documentation
README-WEB.md           This file — Web Messenger reviewer guide
```

---

## Complete setup instructions

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+ (for development builds only)
- A modern browser (Chrome recommended)

### 1. Start the backend

**Windows:**
```powershell
.\start-backend.ps1
```

**macOS / Linux:**
```bash
chmod +x start-backend.sh && ./start-backend.sh
```

Verify API: http://localhost:3000/health → `{"status":"ok"}`

### 2. Deploy Web Messenger (reviewers — no Flutter required)

```powershell
.\build-web.ps1
```

This runs `flutter build web` and starts nginx on **port 8080**.

Open: **http://localhost:8080**

Re-run `.\build-web.ps1` after pulling UI changes.

### 3. Deploy to Render (accessible from any computer)

See **[RENDER.md](RENDER.md)** for the full guide. Summary:

1. Push repo to GitHub/GitLab → Render **New Blueprint** (`render.yaml`)
2. Set `ENCRYPTION_KEY`, `APP_URL`, and SMTP variables in the Render dashboard
3. Run `.\scripts\prepare-render-deploy.ps1` → commit `backend/public` → push
4. Web: open `https://YOUR-SERVICE.onrender.com`
5. Mobile: **Server settings** → same URL → Test → Save

### 4. Development mode (hot reload)

```powershell
.\start-backend.ps1
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

### 5. Production build (custom API host)

```bash
cd mobile
flutter build web --dart-define=API_URL=https://your-api.example.com
```

Serve `mobile/build/web` with any static host, or use the included nginx service in `backend/docker-compose.yml`.

### Email in development

Outgoing mail is captured by **Mailhog** (not delivered to real inboxes).

1. Register in the web app
2. On the same PC, open http://localhost:8025
3. Open the verification or password-reset email
4. **Easiest:** after login, use **Verify now** on the home banner (mobile) or verify via token in Profile

### Stop services

```bash
docker compose -f backend/docker-compose.yml down
```

---

## Usage guide

### First-time setup

1. Open http://localhost:8080
2. **Register** — email, username, password (strength rules shown live)
3. **Verify email** — Mailhog token or **Verify now** (mobile banner; web: Profile shows status)
4. **Search users** (person icon) — find contacts by username or email
5. **Send direct invite** from search results

### Web layout

| Area | Action |
|------|--------|
| Left sidebar | Chat list (sorted by last activity); click to open |
| Main area | Up to **2 chat panes** side by side |
| Top bar | Invites, search users, create group, profile |
| Search bar | Search message text; use ↑/↓ to jump between matches |

### Direct chats

1. Accept a pending invite (mail badge icon)
2. Click the chat in the sidebar
3. Send text, images, or videos
4. Long-press (or right-click) your message → **Edit** / **Delete**

### Group chats

1. **Create group** (+ icon) — name + member user IDs (find IDs via Search)
2. **Invite more users** — person-add icon in group chat header
3. **Accept/decline** group invites in the Invitations screen
4. **Create poll** — poll icon in group chat input bar

### Profile

Open **Profile** (account icon):

- Edit **username** and **About Me**
- Upload **JPEG/PNG** avatar (≤ 5 MB)
- Change theme (light / dark / system)
- Configure server URL if API is not on `localhost:3000`
- **Log out** (only this browser session ends)

### Cross-platform testing

1. Log in as the same user on **web** and **mobile** (APK)
2. Send a message from web → appears instantly on mobile
3. Confirm ✓ (sent) → ✓✓ (delivered) → blue ✓✓ (read)
4. Log out on web only → mobile session stays active

---

## Requirements checklist

Use this section to verify mandatory and extra requirements during review.

### Repository & documentation

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Complete source code and configuration | ✅ | Repo contains `mobile/`, `backend/`, `docker-compose.yml`, `build-web.ps1` |
| README with required sections | ✅ | This file: overview, setup, usage; [README.md](README.md) for mobile |
| Application deployed on chosen platform | ✅ | [RENDER.md](RENDER.md) — Render Blueprint; public HTTPS URL |

### Authentication & account

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Register with email, username, password | ✅ | Register tab on login screen |
| Block duplicate email/username | ✅ | Register same email or username → inline error + API 409 |
| Visual feedback on registration errors | ✅ | Red field errors; password strength checklist |
| Email verified before full account use | ✅ | Verification email sent at signup; `emailVerified: false` until token confirmed; banner / Profile status |
| Login with email + password | ✅ | Login tab |
| Password reset | ✅ | “Forgot password?” on login → email token via Mailhog → new password |
| Data persists after restart | ✅ | Refresh browser or reopen app → session restored via secure storage + refresh token |

### Profile

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Profile page exists | ✅ | Account icon → Profile |
| Username, profile picture, About Me | ✅ | All three sections on Profile screen |
| Default profile picture on first login | ✅ | Letter avatar from username initial (`AvatarWidget`) |
| Upload JPEG and PNG avatars | ✅ | Tap avatar → pick image; rejects other formats |
| Edit any profile data | ✅ | Change username, about, avatar; Save |

### Contacts & invitations

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Search by username or email | ✅ | Person-search icon → Search screen |
| Send individual chat invitations | ✅ | Search → Send invite |
| Send group chat invitations | ✅ | Group chat header → person-add; or include members when creating group |
| Accept or decline invitations | ✅ | Mail badge → Invitations (direct + group tabs) |
| Pending invitation section | ✅ | Invitations screen with badge count on mail icon |

### Chats & messaging

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Chat list sorted by last message time | ✅ | Sidebar reorders after send/receive (`updated_at`) |
| Send text messages | ✅ | Type in input → Send |
| Send images | ✅ | Image icon → pick from gallery |
| Send videos | ✅ | Video icon → pick from gallery |
| Typing indicators (real time) | ✅ | Start typing → other client shows “typing…” |
| Sent indicator | ✅ | Single check on own messages |
| Delivered indicator | ✅ | Double check (typically &lt; 2 s on LAN) |
| Read indicator | ✅ | Blue double check when recipient views message |
| Failed delivery visual feedback | ✅ | Red border + “Not delivered” + Retry / Delete |
| Edit own messages | ✅ | Long-press → Edit (text only) |
| Delete own messages | ✅ | Long-press → Delete |
| Message search (direct + group) | ✅ | Top search bar → results strip |
| Search highlights matches | ✅ | Yellow highlight on matching text in chat |
| Navigate search results in chat | ✅ | ↑ / ↓ buttons + click result card; scrolls to message |
| Messages sync web ↔ mobile | ✅ | Same DB + Socket.IO; test with two clients |
| Instant cross-platform delivery | ✅ | `message:new` socket event |
| Delivered status under 2 seconds | ✅ | On local Docker/LAN; watch ✓ → ✓✓ |

### Sessions

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Independent sessions per device | ✅ | Each login creates its own refresh token row |
| Same user on web + mobile simultaneously | ✅ | Log in on both; both stay connected |
| Selective logout | ✅ | Profile → Log out removes only current device token |
| Logout on one device does not affect others | ✅ | Log out web → mobile still receives messages |

### Security & encryption

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Sensitive data encrypted before DB | ✅ | `backend/src/crypto.js` — AES-256-GCM |
| Encrypted message content | ✅ | `messages.content_enc` |
| Encrypted profile email & about | ✅ | `email_enc`, `about_enc` |
| Encrypted poll text | ✅ | `question_enc`, `poll_options.text_enc` |
| Media files | ⚠️ | Stored on disk under `uploads/`; paths in DB (standard for this stack) |

### Error handling

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Recover to last stable state on errors | ✅ | Failed sends stay in list with retry; loads don’t wipe chat state |
| Visual error feedback | ✅ | `ErrorBanner` on web; SnackBars for actions; failed message styling |

### Extra — Web adaptation

| Requirement | Status | How to verify |
|-------------|--------|---------------|
| Mobile codebase adapted for web | ✅ | `WebShell`, responsive layout, platform guards (`kIsWeb`) |
| Organized `lib/` structure | ✅ | `screens/`, `providers/`, `services/`, `widgets/`, `utils/`, `models/` |
| Consistent theme & intuitive UI | ✅ | Shared `app_theme.dart`; Material 3; sidebar + panes pattern |
| Public or anonymous group polls | ✅ | Poll dialog → anonymous toggle |
| Change or retract votes | ✅ | Tap another option or “Retract vote” on `PollCard` |
| Open ≥ 2 chats on same page | ✅ | Open two chats from sidebar → split view |

---

## Suggested reviewer test flow

1. **Deploy:** `.\start-backend.ps1` then `.\build-web.ps1` → open http://localhost:8080
2. **Register** `alice@test.com` and `bob@test.com` — confirm duplicate errors work
3. **Verify** both accounts (Mailhog or resend from Profile)
4. **Search** bob from alice → send direct invite → bob accepts
5. **Chat** — text, image, video; confirm typing + receipts
6. **Create group** with bob → send group invite to a third user
7. **Search messages** — find text, use ↑/↓ navigation
8. **Create poll** — vote, change vote, retract; toggle anonymous
9. **Open 2 chats** side by side in web UI
10. **Mobile sync** — install APK, same backend, send web → mobile and mobile → web
11. **Logout web only** — confirm mobile session still works
12. **Offline test** — stop Docker, send message → failed UI → restart → Retry

---

## Architecture

```
Browser (Flutter Web)          Mobile (Flutter APK)
        │                              │
        └──────────┬───────────────────┘
                   │  REST + WebSocket
            Express API :3000
                   │
            PostgreSQL (encrypted fields)
                   │
            Mailhog :8025 (dev email)
```

### Encryption (`backend/src/crypto.js`)

| Field | Table | Encrypted |
|-------|-------|-----------|
| Email | `users.email_enc` | Yes |
| About Me | `users.about_enc` | Yes |
| Message text | `messages.content_enc` | Yes |
| Poll question/options | `polls`, `poll_options` | Yes |
| Username | `users.username` | No (searchable identifier) |
| Avatar file | disk `uploads/` | File bytes not encrypted |

### Real-time events

| Event | Purpose |
|-------|---------|
| `message:new` | New message |
| `message:status` | Delivered / read |
| `typing:start` / `typing:stop` | Typing indicators |
| `invite:received` | Direct invite |
| `group-invite:received` | Group invite |
| `poll:updated` | Poll vote changes |

### Web-specific code

| File | Role |
|------|------|
| `lib/screens/web_shell.dart` | Sidebar, dual panes, search, group create |
| `lib/main.dart` | `kIsWeb ? WebShell : HomeScreen` |
| `lib/utils/voice_recorder_*.dart` | Audio recording mobile-only |
| `lib/widgets/poll_card.dart` | Poll UI with vote/retract |
| `lib/widgets/error_banner.dart` | Top error strip |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Web app blank / can’t connect | Confirm http://localhost:3000/health; check browser console CORS |
| 8080 not loading | Run `.\build-web.ps1`; ensure port 8080 is free |
| Verification email missing | Open http://localhost:8025 (Mailhog), not Gmail |
| Search returns nothing | Messages must be text type; query min length 2 |
| Group invite by ID | Use Search → note user UUID from API, or search by username |
| Flutter web build fails | `cd mobile && flutter pub get && flutter build web` |

---

## Related documentation

- [RENDER.md](RENDER.md) — Deploy to Render (web + API + mobile)
- [README.md](README.md) — Mobile Messenger, APK review, Docker backend details
- API health: http://localhost:3000/health
- Web app: http://localhost:8080
- Mailhog: http://localhost:8025
