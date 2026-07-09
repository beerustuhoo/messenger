# Web Messenger

Browser-based messenger built with **Flutter Web** and a shared **Node.js / PostgreSQL** backend. The same codebase also builds the Android app, so messages sync between web and mobile in real time.

**Live deployment:** https://mobile-messenger-i7id.onrender.com  
**Repository:** https://gitea.kood.tech/johansebastianrodriguez/web-messenger

| Layer | Technology |
|-------|------------|
| Web & mobile UI | Flutter 3.x, Provider |
| API & WebSocket | Node.js, Express, Socket.IO |
| Database | PostgreSQL |
| Hosting | [Render](RENDER.md) (web + API on one URL) |
| Auth (production) | Firebase Auth (email verification & password reset) |
| Auth (local dev) | JWT + [Mailhog](http://localhost:8025) |

---

## Project overview

Users register with email, username, and password, verify their email, then search for contacts and send chat invitations (direct or group). Chats support text, images, and video, with typing indicators and sent / delivered / read receipts. Group chats add polls (public or anonymous) and in-chat message search.

Sensitive fields (email, about text, message bodies, poll text) are encrypted with **AES-256-GCM** in `backend/src/crypto.js` before they are stored. Usernames stay plain text so search still works.

Web-specific UI lives in `mobile/lib/screens/web_shell.dart`: a sidebar chat list, up to two open chats side by side, group management, polls, and a top error banner when the API fails.

---

## Setup

### Option A — Review the deployed app (no install)

1. Open https://mobile-messenger-i7id.onrender.com  
2. Register with a real email address (Firebase sends the verification mail).  
3. Click the link in the email, then tap **I verified** in the app if the banner is still shown.

First load after idle can take ~30 seconds on Render’s free tier (cold start).

### Option B — Run locally

**You need:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) and, only if you want to rebuild the web UI, the [Flutter SDK](https://docs.flutter.dev/get-started/install).

**1. Start the backend**

```powershell
.\start-backend.ps1
```

Check http://localhost:3000/health → `{"status":"ok"}`.

**2. Open the web app**

```powershell
.\build-web.ps1
```

Then open http://localhost:8080.

For hot reload during development:

```powershell
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

**3. Email on localhost**

Outgoing mail is caught by Mailhog, not delivered to Gmail. After registering, open http://localhost:8025 on the same PC, or use **Verify now** in the app.

**4. Stop**

```bash
docker compose -f backend/docker-compose.yml down
```

### Option C — Deploy your own instance on Render

See **[RENDER.md](RENDER.md)** and **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** for environment variables, Firebase service account JSON, and rebuilding `backend/public`.

---

## Usage guide

### Account

1. **Register** — email, username, password. Password rules are shown while typing (8+ chars, upper, lower, digit, special). Duplicate email or username shows an inline error.  
2. **Verify email** — required before the account is treated as verified. On Render, Firebase sends the email. Locally, use Mailhog or **Verify now**.  
3. **Log in** with email and password.  
4. **Forgot password** — link on the login screen; follow the email reset flow.

### Contacts & invites

- **Search** (person icon) — by username (partial match) or email (exact).  
- **Direct invite** — from search results.  
- **Group invite** — when creating a group or from the group chat header.  
- **Pending invites** — mail icon; accept or decline direct and group invitations.

### Chats

- Sidebar lists chats sorted by latest activity.  
- Click a chat to open it; on web you can open **two chats** at once.  
- Send text, images (gallery), or videos.  
- Typing indicators appear while the other person types.  
- Own messages show ✓ sent, ✓✓ delivered, blue ✓✓ read.  
- Failed sends show a red state with **Retry** and **Delete**.  
- Long-press your message to **edit** or **delete** text.

### Message search (web)

Use the search field above the chat area. Matches are highlighted in yellow; **↑** / **↓** move between results.

### Group polls

In a group chat, use the poll icon. Choose public or anonymous, vote, change your vote, or retract it.

### Profile

Account icon → edit username, **About Me**, and profile picture (JPEG/PNG, max 5 MB). New users get a default letter avatar. **Log out** ends only the current browser session.

### Web + mobile together

Install the APK (see [README-MOBILE.md](README-MOBILE.md)), set **Server** to `https://mobile-messenger-i7id.onrender.com`, and log in with the same account. Messages should appear on both clients within about two seconds.

---

## Requirements reference

Short map from the project rubric to where things live in the app.

| Area | What to check |
|------|----------------|
| **Auth** | Register / login tabs; duplicate email/username errors; password checklist; verification banner; forgot password |
| **Profile** | Profile screen — username, avatar upload, About Me, default initial avatar |
| **Invites** | Search screen; Invitations screen with pending badge |
| **Messaging** | Chat input; image/video pickers; typing line; receipt icons; failed message retry |
| **Groups** | Create group (+); group invites; polls in group chats |
| **Search** | Web search bar; highlighted hits; prev/next navigation |
| **Sessions** | Log in on web and phone; log out on one — the other stays connected |
| **Encryption** | `backend/src/crypto.js`, encrypted columns in `backend/src/db.js` |
| **Errors** | Red `ErrorBanner` on web; snackbars on actions; failed messages stay in the list |
| **Web extras** | `web_shell.dart` — dual panes, responsive layout, shared `app_theme.dart` |

---

## Code layout

```
mobile/lib/
  main.dart           Web vs mobile entry (WebShell / HomeScreen)
  screens/            auth, web_shell, chat, profile, search, …
  providers/          AppState (shared state), ThemeProvider
  services/           API client, socket, storage, Firebase auth
  widgets/            avatar, poll_card, error_banner, …
  models/             User, Chat, Message, Poll, …
backend/src/
  routes/             REST endpoints
  socket.js           real-time events
  crypto.js           AES-256-GCM
  firebase.js         production auth
```

---

## Challenges & solutions

| Problem | What we did |
|---------|-------------|
| Emulator reaching Docker on the host | Default API URL `10.0.2.2` for Android; in-app server settings for real devices |
| Email verification without SMTP in the cloud | Firebase Auth on Render; Mailhog locally |
| Encrypted email but still searchable | SHA-256 hash column for exact email lookup |
| Web and mobile from one repo | `kIsWeb` guards; `WebShell` only on web |
| Failed sends on bad network | Optimistic UI, local outbox, retry/delete on the bubble |
| Stale web bundle after deploy | `prepare-render-deploy.ps1` copies build into `backend/public`; PWA cache disabled for web release builds |
| Group member pickers on web | `user_picker_dialog.dart` instead of raw UUID entry |

---

## Troubleshooting

| Issue | Try |
|-------|-----|
| Render site slow or blank | Wait for cold start; hard-refresh (`Ctrl+Shift+R`) |
| Registration error about Firebase | Add `mobile-messenger-i7id.onrender.com` under Firebase → Authentication → Authorized domains |
| Local web won’t connect | Confirm http://localhost:3000/health |
| No verification email locally | http://localhost:8025 (Mailhog) |
| Mobile can’t reach PC backend | Same Wi‑Fi; use LAN IP from `start-backend.ps1` in Server settings |

---

## More docs

- [README-MOBILE.md](README-MOBILE.md) — APK install and mobile testing  
- [RENDER.md](RENDER.md) — Render deployment  
- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) — Firebase Auth configuration
