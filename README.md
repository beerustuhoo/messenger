# Mobile Messenger 📲

A full-stack Flutter messaging application with a Node.js backend, real-time chat, encrypted data storage, and reviewer-friendly setup.

## Two-part project (mobile + web)

This repo contains **one shared codebase** with two deliverables:

| Part | What reviewers use | Where it runs | Git remote |
|------|-------------------|---------------|------------|
| **1 — Mobile** | Android APK + local Docker | Emulator/phone → `http://10.0.2.2:3000` or your PC IP | **Gitea** (school submission) |
| **2 — Web** | Browser + cloud API | **Render** → `https://YOUR-SERVICE.onrender.com` | **Gitea** → [web-messenger](https://gitea.kood.tech/johansebastianrodriguez/web-messenger) |

**Will web changes break mobile?** No — not if you keep using the APK with **local Docker** (default). Web-only UI (`WebShell`, dual panes, polls button) is behind `kIsWeb`. On Android you still get `HomeScreen`, voice messages, and notifications. The shared backend gained group/search/poll APIs; mobile direct-chat flow is unchanged.

**Optional:** Point the APK at Render (**Server settings** → your `https://…onrender.com` URL) to use the same cloud database as web.

See **[RENDER.md](RENDER.md)** for always-online cloud deployment.

---

## Project overview

Mobile Messenger lets users register, verify email, manage profiles, search for contacts, send chat invitations, exchange text/image/video/audio messages, and see delivery/read receipts with typing indicators. Sensitive data (emails, profile text, message content) is encrypted at rest using **AES-256-GCM** before being stored in PostgreSQL.

| Layer | Stack |
|-------|-------|
| Mobile | Flutter 3.x, Provider, Socket.IO client |
| Backend | Node.js, Express, Socket.IO, PostgreSQL |
| Infra | Docker Compose (single command) |
| Email (dev) | Mailhog web UI on port 8025 |

---

## Reviewer quick start

**No Flutter required.** Install Docker, start the backend, install the APK.

```powershell
.\start-backend.ps1
```

1. Wait for `http://localhost:3000/health` → `{"status":"ok"}`
2. Install **`releases/app-release.apk`** on an Android emulator or device
3. **Emulator:** open app and register — default server `http://10.0.2.2:3000` works immediately
4. **Physical phone:** tap **Server: http://…** on the login screen → enter `http://YOUR_PC_IP:3000` (from `start-backend.ps1`) → **Test** → **Save**
5. Register two accounts → tap **Verify now** on the home banner (or use Mailhog on the PC)

Full details: [Reviewer Guide](#reviewer-guide) below.

---

## Quick start (developers)

### 1. Start the backend (one command)

**Windows (PowerShell):**
```powershell
.\start-backend.ps1
```

**macOS / Linux:**
```bash
chmod +x start-backend.sh && ./start-backend.sh
```

**Or manually:**
```bash
docker compose -f backend/docker-compose.yml up --build -d
```

Verify: http://localhost:3000/health  
View test emails: http://localhost:8025

`start-backend.ps1` / `.sh` also prints the **LAN URL for physical phones** and reminds you which URL emulators use by default.

### Email in development (Mailhog)

In local/dev mode the backend does **not** send mail to real inboxes (Gmail, Outlook, etc.). Docker includes **Mailhog**, a fake SMTP server that captures every outgoing email and shows it in a web UI.

| What you might expect | What actually happens |
|-----------------------|------------------------|
| Verification email in your Gmail inbox | Email appears only in Mailhog |
| Need a real email provider for testing | Any address works in the register form — delivery is always local |

**After registering or requesting a password reset:**

1. On the **same machine running Docker**, open http://localhost:8025
2. Open the message (subject: *Verify your Mobile Messenger account* or *Reset your password*)
3. **Easiest:** on the phone/emulator, tap **Verify now** on the home banner after login (no Mailhog needed on the device)
4. **Alternative:** copy the plain-text token from Mailhog into the app, or open the verify link in a desktop browser

If you registered with your real email and nothing showed up in Gmail, that is normal — check Mailhog instead.

**Production:** Configure a real SMTP provider in `backend/.env` (see `backend/.env.example`).

### 2. Run or build the Flutter app (Android)

```bash
cd mobile
flutter pub get
flutter run
```

On a connected device or emulator, `flutter run` targets Android by default in this project.

#### Server URL (no rebuild needed for reviewers)

The pre-built APK defaults to **`http://10.0.2.2:3000`** (Android emulator → host Docker). Change the server **in the app**:

| Where | How |
|-------|-----|
| Login screen | Tap the **Server: http://…** button under the logo (or the server icon in the app bar) |
| While logged in | **Profile → Server** |

Use **Test connection** then **Save**. The URL is stored on the device.

| Target | URL |
|--------|-----|
| Android emulator / Nox / BlueStacks | `http://10.0.2.2:3000` (default) |
| Physical phone on same Wi‑Fi | `http://YOUR_PC_IP:3000` (from `start-backend.ps1`) |

Example for `flutter run` on a physical Android device:
```bash
flutter run --dart-define=API_URL=http://YOUR_PC_IP:3000
```

Build release APK:
```bash
cd mobile
flutter build apk --release
```

Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`

---

## Reviewer Guide

Reviewers can test the app **without installing Flutter or Android Studio** using the pre-built APK and Docker backend.

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- An Android device, emulator, or browser-based emulator

### Pre-built APK

| File | Default server | Use for |
|------|----------------|---------|
| `releases/app-release.apk` | `http://10.0.2.2:3000` | **All reviewers** — emulators and phones (set `http://YOUR_PC_IP:3000` in app on physical device) |

**Download:** The APK is **not in Git** (host size limit). Get `app-release.apk` from the **Google Drive link in your submission**, or build locally:

```bash
cd mobile && flutter build apk --release
```

**Important:** The APK does **not** contain a personal/home IP. On a physical phone, set `http://YOUR_PC_IP:3000` once in **Server settings**.

### Step 1 — Start the backend

From the project root:

```powershell
.\start-backend.ps1
```

Wait until `http://localhost:3000/health` returns `{"status":"ok"}`.

The terminal prints:
- Emulator URL: `http://10.0.2.2:3000` (built into the APK)
- Physical phone URL: `http://YOUR_PC_IP:3000` (set once in the app; your IP is printed by `start-backend.ps1`)

**Email testing:** http://localhost:8025 (Mailhog)

### Step 2 — Install the app

Install **`releases/app-release.apk`**.

#### Option A: Android emulator (recommended — zero config)

1. Start the backend (Step 1).
2. Install `releases/app-release.apk` in Android Studio emulator, Nox, BlueStacks, or LDPlayer.
3. Open the app and register — no server setup needed.
4. Tap **Verify now** on the home banner, or verify via Mailhog on the PC.
5. Search users → send invite → chat on a second account/emulator.

#### Option B: Physical Android device

1. Start the backend (Step 1) and note the **Physical phone** URL from the terminal.
2. Copy `releases/app-release.apk` to the device (USB, cloud link, or GitHub Release).
3. Enable **Install unknown apps** for your file manager; install the APK.
4. Phone on the **same Wi‑Fi** as the PC running Docker (not guest Wi‑Fi).
5. Open app → tap **Server: http://…** on login → paste `http://YOUR_PC_IP:3000` → **Test connection** → **Save**.
6. Register and test. Use **Verify now** on the home banner for email verification.

**Troubleshooting:** In Chrome on the phone, open `http://YOUR_PC_IP:3000/health`. If that fails, fix Wi‑Fi/firewall before changing app settings.

#### Option C: Browser-based emulator (Appetize.io)

1. Upload `releases/app-release.apk` to [Appetize](https://appetize.io/).
2. Appetize runs in the cloud and **cannot reach `localhost` on your machine**. Use Option A or B for standard review, or expose the API with ngrok and set that URL in **Server settings**.

### Suggested test flow

1. **Register** two users with strong passwords (8+ chars, upper, lower, digit, special).
2. Try duplicate email/username — confirm error messages appear.
3. **Verify** via **Verify now** on the home banner (or Mailhog token on PC).
4. **Search** for the second user → **Send invite** → accept on the other account.
5. Send **text**, **image**, **video**, and **voice** messages; check sent/delivered/read ticks.
6. Stop Docker, send a message — confirm **Not delivered** with Retry/Delete; restart backend and **Retry**.
7. **Edit** and **delete** your own messages.
8. **Archive** a chat from the chat list.
9. Open **Profile** → edit username/about → upload JPEG/PNG avatar (≤5MB) → change **Theme** (light/dark/system).
10. **Mute** notifications on a chat (long-press chat in list); confirm notification when unmuted and app in background.
11. **Log out** and reopen — session should persist until logout.

### APK distribution

| Location | Notes |
|----------|-------|
| Google Drive (submission link) | Primary download for reviewers (~51 MB) |
| `releases/app-release.apk` | Local build output; gitignored (too large for Gitea) |
| `flutter build apk --release` | Reviewers can rebuild from source if needed |

---

## Features implemented

### Core requirements
- Registration (email, password, username) with duplicate detection
- Password strength validation with live feedback
- Login / persistent session (secure storage + refresh tokens)
- Email verification (Mailhog in dev; **Verify now** one-tap in app)
- Password reset via email
- User profile (avatar, username, about) — JPEG/PNG, 5MB limit
- User search by username or email
- Chat invitations (send, accept, decline, pending list)
- Chat list sorted by last activity, archive/unarchive
- Text, image, video, and audio messages (20MB after compression)
- Message status: sent → delivered → read (with failed delivery UI + retry)
- Edit/delete own messages
- Typing indicators (WebSocket)
- AES-256-GCM encryption for sensitive DB fields

### Extra requirements
- Reviewer-friendly Docker backend (`start-backend.ps1` / `.sh`)
- Reviewer Guide with emulator, physical device, and Appetize paths
- Release APK in `releases/` with in-app server configuration
- Instructions for Android, lightweight emulator, and browser-based emulator

### Bonus
- **Audio messages** — record with microphone, waveform-style player in chat
- **Local notifications** — new messages and invites (Android 13+ permission requested; works when app/socket connected)
- **Per-chat mute** for notifications
- **Light / dark / system theme** in Profile
- **Configurable server URL** — one APK for all reviewers without rebuilding

---

## Architecture

```
mobile/          Flutter client
backend/         Express API + Socket.IO
  src/
    crypto.js    AES-256-GCM encrypt/decrypt
    routes/      REST endpoints
    socket.js    Real-time events
releases/        Pre-built APK(s) for reviewers
```

### Encryption

Fields encrypted before insert: `email_enc`, `about_enc`, `messages.content_enc`. Media files are stored on disk; paths are stored in DB.

### Real-time events

| Event | Purpose |
|-------|---------|
| `message:new` | New message in chat |
| `message:status` | Delivered / read |
| `typing:start` / `typing:stop` | Typing indicators |
| `invite:received` | New invitation |
| `notification` | Local notification payload |

---

## Usage guide

1. **Register** on the Register tab; meet all password rules.
2. After login, tap **Verify now** on the home banner (or use Mailhog on the PC).
3. **Login** persists across app restarts.
4. **Search** (person icon) → invite users.
5. **Invites** (mail badge) → accept to create a chat.
6. Tap a chat → send text, media, or hold mic for voice.
7. Long-press your message → edit or delete.
8. **Profile** → avatar, about, theme, server URL, or log out.

---

## Challenges & solutions

| Challenge | Approach |
|-----------|----------|
| Emulator ↔ host networking | Default `10.0.2.2` in APK; no setup for reviewers |
| Different PC IP per reviewer | In-app **Server settings** — no Flutter rebuild |
| Email in dev without SMTP | Mailhog in docker-compose + **Verify now** in app |
| Encrypted search by email | SHA-256 hash column for exact email lookup |
| Large media | `flutter_image_compress` + 20MB server limit |
| Session persistence on Android | `flutter_secure_storage` with encrypted prefs + refresh tokens |
| Failed sends when offline | Optimistic UI, outbox, Retry/Delete |
| Android 13+ notifications | Runtime `POST_NOTIFICATIONS` permission |

---

## Web Messenger

Full Web Messenger documentation: **[README-WEB.md](README-WEB.md)** (setup, deployment, requirements checklist, reviewer test flow).

The same Flutter codebase runs as **Web Messenger** in the browser, sharing the backend and database with the mobile app.

### Run locally

```bash
.\start-backend.ps1
cd mobile
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

## Deployment (Render — public URL)

Deploy API + Web Messenger on one URL so **any computer** and the **mobile APK** can connect.

**Full guide:** [RENDER.md](RENDER.md)

Quick summary:

1. Connect repo to Render → **New Blueprint** (uses `render.yaml`)
2. Set `ENCRYPTION_KEY`, `APP_URL`, and SMTP env vars
3. Run `.\scripts\prepare-render-deploy.ps1` → commit `backend/public` → push
4. Open `https://YOUR-SERVICE.onrender.com` (web)
5. Mobile: **Server settings** → same URL

---

## Deployment (local Docker)

### Web-only features

| Feature | Description |
|---------|-------------|
| **Responsive UI** | Sidebar chat list + up to **2 chats** open side by side |
| **Group chats** | Create groups, invite members, accept/decline group invitations |
| **Message search** | Search text in chats; results highlighted and navigable |
| **Group polls** | Create polls (anonymous or public), vote, change/retract vote |
| **Error banner** | Network/API errors shown with dismiss; app keeps last stable state |

### Default API URL

- **Web:** `http://localhost:3000` (auto when no saved Server URL)
- **Android:** `http://10.0.2.2:3000` or configure in **Server settings**

---

## Stop services

```bash
docker compose -f backend/docker-compose.yml down
```

---


