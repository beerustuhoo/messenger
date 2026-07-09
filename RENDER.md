# Deploy to Render 🚀

Host **Web Messenger**, the **API**, and **Mobile Messenger** (via Server URL) on a single public URL — e.g. `https://mobile-messenger.onrender.com`.

| Client | How it connects |
|--------|-----------------|
| **Web** | Open the Render URL in any browser |
| **Mobile (APK)** | **Server settings** → `https://YOUR-SERVICE.onrender.com` → Test → Save |

Everything shares one Node.js service, one PostgreSQL database, and one Socket.IO endpoint.

---

## Architecture on Render

```
https://mobile-messenger.onrender.com
├── /                    → Flutter Web (static files in backend/public)
├── /api/*               → Express REST API
├── /socket.io/*         → WebSocket (real-time chat)
├── /uploads/*           → Media files
└── /health              → Health check
```

Mobile APK uses the **same base URL** (no `/api` suffix) in Server settings.

---

## Render free tier vs always online

| Plan | Behavior |
|------|----------|
| **Free** | Service **sleeps** after ~15 minutes with no traffic. First visit after sleep can take **30–60 seconds** (cold start). Fine for demos and review. |
| **Starter (paid)** | Service stays **always on** — best if you need instant access from any computer at any time. |

To avoid cold starts on free tier, use a free uptime monitor (e.g. [UptimeRobot](https://uptimerobot.com)) to ping `/health` every 5 minutes — acceptable for school projects; Render may still spin down occasionally.

Docs: [Render pricing](https://render.com/pricing) · [Render deploy guide](RENDER.md)

---

1. [Render](https://render.com) account (free tier works for review)
2. Git remote Render can access — **GitHub** or **GitLab** (recommended).  
   If your repo is only on Gitea, mirror it to GitHub or use [Manual Deploy](https://render.com/docs/deploy-a-commit).
3. [Flutter SDK](https://docs.flutter.dev/get-started/install) on your PC (to build the web bundle before deploy)
4. Firebase project for auth emails on Render (see [FIREBASE_SETUP.md](FIREBASE_SETUP.md)). SMTP is optional when Firebase is enabled.

---

## Step 1 — Push code to GitHub/GitLab

Ensure your repository contains:

- `render.yaml` (blueprint)
- `backend/` (API)
- `mobile/` (Flutter app)
- `scripts/prepare-render-deploy.ps1`

---

## Step 2 — Create services with Blueprint

1. Open [Render Dashboard](https://dashboard.render.com) → **New** → **Blueprint**
2. Connect your GitHub/GitLab repo
3. Render reads `render.yaml` and creates:
   - **PostgreSQL** database (`mobile-messenger-db`)
   - **Web service** (`mobile-messenger`, Node, `rootDir: backend`)

4. Click **Apply**. Wait for the first deploy (API only — web UI not bundled yet).

5. Copy your service URL, e.g. `https://mobile-messenger.onrender.com`

---

## Step 3 — Set environment variables

In Render → **mobile-messenger** → **Environment**:

| Variable | Value | Notes |
|----------|-------|-------|
| `DATABASE_URL` | *(auto from database)* | Linked by blueprint |
| `JWT_SECRET` | *(auto-generated)* | Or set your own |
| `ENCRYPTION_KEY` | **64 hex characters** | Run: `openssl rand -hex 32` |
| `APP_URL` | `https://mobile-messenger.onrender.com` | Your exact Render URL (HTTPS, no trailing slash) |
| `SMTP_HOST` | e.g. `smtp.resend.com` | Provider hostname |
| `SMTP_PORT` | `587` | Usually 587 with TLS |
| `SMTP_REQUIRE_TLS` | `true` | |
| `SMTP_USER` | e.g. `resend` | Provider username |
| `SMTP_PASS` | your API key | Provider password / API key |
| `SMTP_FROM` | verified sender | e.g. `onboarding@resend.dev` |
| `UPLOAD_DIR` | `./uploads` | Default is fine on free tier |

**Save** — Render redeploys automatically.

### Example: Resend SMTP

```
SMTP_HOST=smtp.resend.com
SMTP_PORT=587
SMTP_REQUIRE_TLS=true
SMTP_USER=resend
SMTP_PASS=re_xxxxxxxxxxxx
SMTP_FROM=onboarding@resend.dev
```

---

## Step 4 — Build and deploy the web UI

The Flutter web app is copied into `backend/public` and served by the same Node process.

**Windows (PowerShell):**

```powershell
.\scripts\prepare-render-deploy.ps1
```

Uses `API_URL=AUTO` so the web app talks to the same origin as the page (ideal for Render).

**macOS / Linux:**

```bash
chmod +x scripts/prepare-render-deploy.sh
./scripts/prepare-render-deploy.sh
```

Then commit and push:

```bash
git add backend/public
git commit -m "Add web build for Render"
git push
```

Render rebuilds and deploys. Open your URL — you should see the Web Messenger login screen.

### Re-deploy after UI changes

Run `prepare-render-deploy` again → commit `backend/public` → push.

---

## Step 5 — Configure Mobile Messenger (APK)

On a physical phone or emulator:

1. Install the APK (`releases/app-release.apk` or build locally)
2. On the **login screen**, tap **Server: http://…**
3. Enter: `https://mobile-messenger.onrender.com`  
   (your Render URL — **https**, no `/api`, no trailing slash)
4. Tap **Test connection** → should show healthy
5. Tap **Save**
6. Register / log in — same accounts as web

Both clients use the same database and sync in real time via Socket.IO.

---

## Step 6 — Verify deployment

| Check | URL / action |
|-------|----------------|
| Health | `https://YOUR-SERVICE.onrender.com/health` → `{"status":"ok"}` |
| Web app | `https://YOUR-SERVICE.onrender.com/` → login screen |
| Register + verify email | Real inbox (SMTP configured) |
| Web ↔ mobile sync | Send message on web → appears on phone |
| Logout selective | Log out web only → mobile stays logged in |

---

## Render free tier notes

| Topic | Behavior |
|-------|----------|
| **Cold starts** | Service sleeps after ~15 min idle; first request may take 30–60 s |
| **Media uploads** | Stored on ephemeral disk — files may be lost on redeploy. Fine for demos; use S3 or a Render Disk for production |
| **PostgreSQL** | Free DB expires after 90 days unless upgraded |
| **HTTPS** | Provided automatically by Render |
| **WebSockets** | Supported on web services (typing indicators, live messages) |

---

## Manual setup (without Blueprint)

If you prefer the dashboard instead of `render.yaml`:

### Database

1. **New** → **PostgreSQL** → name `mobile-messenger-db` → Create
2. Copy **Internal Database URL**

### Web service

1. **New** → **Web Service** → connect repo
2. **Root Directory:** `backend`
3. **Runtime:** Node
4. **Build Command:** `npm install`
5. **Start Command:** `npm start`
6. **Health Check Path:** `/health`
7. Add environment variables from the table above
8. Link `DATABASE_URL` to the PostgreSQL instance

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Web shows API JSON or 404 | Run `prepare-render-deploy`, commit `backend/public`, push |
| Mobile “Cannot reach server” | Use `https://` not `http://`; no trailing slash; wait for cold start |
| CORS / socket errors | Web should use `AUTO` API URL (same origin). Mobile uses base URL only |
| Emails not sent | Check SMTP vars; verify sender domain with provider |
| `ENCRYPTION_KEY` error on boot | Must be exactly 64 hex chars (`openssl rand -hex 32`) |
| Verification link wrong host | Set `APP_URL` to your public `https://…onrender.com` URL |

---

## Local vs Render

| | Local (Docker) | Render |
|--|--------------|--------|
| Web URL | http://localhost:8080 | https://YOUR-SERVICE.onrender.com |
| API URL | http://localhost:3000 | same as web URL |
| Email | Mailhog :8025 | Real SMTP |
| Mobile default | `http://10.0.2.2:3000` | Set in Server settings |

---

## Related docs

- [README.md](README.md) — Web Messenger overview, setup, and usage
- [README.md](README.md) — Mobile Messenger & local Docker setup
