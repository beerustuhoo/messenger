# Mobile client (same codebase)

The Android app shares the backend and database with Web Messenger. Use it to test cross-platform sync.

## Quick test against Render

1. Install `releases/app-release.apk` (build with `flutter build apk --release` if needed).  
2. On the login screen, tap **Server** → enter `https://mobile-messenger-i7id.onrender.com` → **Test** → **Save**.  
3. Register or log in with the same account as on the web.

## Local backend

```powershell
.\start-backend.ps1
```

| Device | Server URL |
|--------|------------|
| Android emulator | `http://10.0.2.2:3000` (default) |
| Physical phone | `http://YOUR_PC_IP:3000` (printed by start script) |

Verification emails locally: http://localhost:8025

## Mobile-only features

Voice messages and push notifications work on Android only (`kIsWeb` guards in the code). Everything else (chat, invites, profile, receipts) matches the web client.
