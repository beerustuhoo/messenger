# Firebase Auth setup (email verification that actually works)

Firebase handles registration, login, password reset, and **verification emails** — no SMTP needed on Render.

## 1. Create Firebase project (5 min)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. **Add project** → this repo uses `web-messenger-bbc0f` (config is in `mobile/lib/firebase_options.dart`)
3. **Authentication** → **Get started** → enable **Email/Password**

## 2. Register your apps

### Web (Render)

1. Project settings → **Add app** → **Web** (`</>`)
2. Copy the `firebaseConfig` values

### Android (optional, for APK)

1. Add app → **Android**
2. Package name: check `mobile/android/app/build.gradle` → `applicationId`
3. Download `google-services.json` → place in `mobile/android/app/`

## 3. Backend (Render)

1. Firebase Console → **Project settings** → **Service accounts**
2. **Generate new private key** → download JSON
3. On **Render** → Environment → add one variable:

```
FIREBASE_SERVICE_ACCOUNT_JSON = <paste entire JSON file as one line>
```

Tip: minify the JSON (remove newlines) or paste as-is if Render accepts multiline.

4. Redeploy. Check:

```
https://YOUR-APP.onrender.com/health/ready
```

Should show `"firebase": true`.

`JWT_SECRET` is optional when Firebase is enabled.

## 4. Flutter web build (Render)

Pass Firebase config as dart-define when building:

```powershell
cd mobile
flutter pub get
flutter build web `
  --dart-define=API_URL=AUTO `
  --dart-define=FIREBASE_API_KEY=AIza... `
  --dart-define=FIREBASE_APP_ID=1:123:web:abc `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=123456 `
  --dart-define=FIREBASE_PROJECT_ID=your-project-id `
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com `
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
```

Or use FlutterFire CLI (recommended):

```powershell
dart pub global activate flutterfire_cli
cd mobile
flutterfire configure
```

Then rebuild with `scripts/prepare-render-deploy.ps1` (update script to include defines if needed).

Copy build to `backend/public` and push to GitHub.

## 5. Authorized domains (important for web)

Firebase Console → **Authentication** → **Settings** → **Authorized domains**

Add:

- `localhost` (dev)
- `mobile-messenger-i7id.onrender.com` (your Render URL)

## 6. Test flow

1. Register in the app
2. Firebase sends verification email to **any** real address
3. User clicks link in email
4. In app, tap **I verified** on the banner
5. Done

## Local dev without Firebase

If Firebase env vars are **not** set, the app falls back to the original JWT + Mailhog flow (`.\start-backend.ps1`, inbox at http://localhost:8025).

## What changed in the codebase

| Layer | Change |
|-------|--------|
| Backend | `firebase-admin` verifies ID tokens; `POST /api/auth/sync` creates DB profile |
| Flutter | `firebase_auth` for register/login/verify/resend |
| Postgres | `users.firebase_uid` column links Firebase user to your chats |

Chats, messages, encryption, and sockets are unchanged — only auth moved to Firebase.
