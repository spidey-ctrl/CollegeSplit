# CollegeSplit

A mobile app for logging personal expenses by voice and splitting their cost with other people, **without requiring those people to have accounts**.

The app is an Android-first Flutter client backed by a NestJS API, a Postgres database (Neon), and Firebase Auth with Google Sign-In.

## How it works

- You sign in with Google (via Firebase Auth).
- You record an expense **by voice** (or type it manually), and choose how to split it: **Equal**, **Ratio**, or **Adhoc**.
- People you split with are tracked as **Participants**; people you split with more than once accumulate as **Contacts**; you can group Contacts into **Groups**.
- Everything lives in your own private **Ledger**, which computes the net **Balance** you owe / are owed with each person.
- You **Settle** a whole balance (paid outside the app) when it's done.
- Sharing sends a **read-only** view of an expense or a balance via in-app share or the native share sheet — it never grants edit access or merges ledgers.

See [`CONTEXT.md`](./CONTEXT.md) for the canonical domain vocabulary.

## Repository layout

```
.
├── app/      Flutter mobile client (Android)
├── server/   NestJS API + Prisma + Postgres, voice pipeline (Sarvam + Gemini)
├── docs/     ADRs and agent docs
├── clean-db.sh   Drop/recreate the database from all migrations (destructive)
├── .env.example  Copy to server/.env and fill in real values
└── CONTEXT.md    Domain glossary
```

---


## Prerequisites

| Tool   | Version / notes                                                            |
| ------ | -------------------------------------------------------------------------- |
| Flutter| 3.x stable (this repo is on 3.47+). `flutter doctor` should pass for Android.|
| Node   | 20+ (with `npm`)                                                           |
| Postgres| You can use a hosted Neon database (this repo's default) or any Postgres  |
| Firebase| A Firebase project (see below)                                             |
| Android | Android Studio + an Android emulator **or** a physical Android device      |

### Required secrets

Create `server/.env` by copying `.env.example`:

```bash
cp .env.example server/.env
```

Fill in:

| Variable          | What it's for                                                                 |
| ----------------- | ----------------------------------------------------------------------------- |
| `DATABASE_URL`    | Postgres connection string (e.g. your Neon database). Prisma uses it directly. |
| `SARVAM_API_KEY`  | Voice transcription (Sarvam). **Optional** — voice capture is disabled without it. |
| `GEMINI_API_KEY`  | Voice extraction (Gemini). **Optional** — voice capture is disabled without it. |

> `server/.env` is git-ignored. Never commit it.

Firebase/Google settings are already wired into the repo:
- `app/android/app/google-services.json` — Android Firebase config.
- `app/lib/firebase_options.dart` — mirrors it for the Flutter runtime.
- `app/lib/services/auth_service.dart` — contains the Google Sign-In **web OAuth client id**.
- `server/src/auth/firebase-auth.guard.ts` — verifies the Firebase ID token the app sends.

If you change Firebase projects, update all three (the Android config, `firebase_options.dart`, and the `loginOAuthClientId` in `auth_service.dart`).

---


## 1. Set up the backend

```bash
cd server

# Install dependencies
npm install

# Apply all Prisma migrations to your database
npx prisma migrate deploy

# Start in watch mode (reloads on change)
npm run start:dev
```

The API listens on `http://localhost:3000` by default (all interfaces, so devices on your network can reach it).

If you copy a `server/.env` from a fresh checkout, **apply migrations before starting** (the DB starts empty):

```bash
cd server
npx prisma migrate deploy
```

### Reset / clean the database

From the repo root, this drops and recreates all tables and re-applies every migration:

```bash
./clean-db.sh
```

> **Destructive — all data is lost.** This is only for development/preview databases. `prisma migrate reset --force` will prompt for explicit confirmation when run by an agent.

### Backend tests

```bash
cd server
npm run test          # unit tests
npm run test:e2e      # e2e tests (needs a database)
```

---

## 2. Set up the Flutter app

```bash
cd app

# Fetch dependencies
flutter pub get

# Get connected devices
flutter devices
```

The app is Android-only and already includes `google-services.json` and the Firebase options. No extra Flutter setup is required beyond `flutter pub get`.

### How the app finds the server

The base URL is compile-time configurable via `--dart-define=API_BASE_URL`.

```dart
// app/lib/services/auth_service.dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',   // Android emulator -> host loopback
);
```

- **Default (`10.0.2.2:3000`)** works automatically for the Android **emulator**.
- For a **real device** you must pass a URL the phone can reach (see below).

> Android 9+ blocks **cleartext HTTP** by default. If you see a
> `CLEARTEXT communication ... not permitted` error, add
> `android:usesCleartextTraffic="true"` to the `<application>` element in
> `app/android/app/src/main/AndroidManifest.xml` (for local development only).

---

## 3. Run on an Android emulator

This is the zero-config path — the default base URL already points at your host.

1. Start an emulator (Android Studio, Device Manager → Launch, or `flutter emulators --launch <id>`).
2. Start the backend on port 3000 (see above).
3. Run the app:

```bash
cd app
flutter run
```

The app automatically talks to `http://10.0.2.2:3000`, which the emulator maps to `localhost:3000` on your machine. No `--dart-define` needed.

For a specific emulator:

```bash
cd app
flutter run -d <device_id>
```

### Emulator networking note

- `10.0.2.2` is the emulator's alias for the host's loopback (`127.0.0.1`).
- The API must be running **on the host machine**, not inside the emulator.
- If the backend is running in Docker or on a non-default port, pass `--dart-define=API_BASE_URL=http://10.0.2.2:<port>`.

---

## 4. Run on a real Android device

Your phone and your computer must be on the **same Wi-Fi network**. You need the computer's **LAN IP address** (not `127.0.0.1` or `10.0.2.2`).

### Find your computer's LAN IP

```bash
# macOS
ipconfig getifaddr en0        # Wi-Fi
# or
ifconfig | grep "inet "

# Linux
hostname -I
```

Example: `192.168.1.50`.

### Run the app pointed at that IP

```bash
cd app
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
```

The app now makes requests to `http://192.168.1.50:3000` over the LAN.

### Port-forwarding alternative (no LAN IP)

If `adb` (Android debug bridge) is available and the phone is connected over USB:

```bash
adb reverse tcp:3000 tcp:3000
cd app
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

`adb reverse` forwards the device's `127.0.0.1:3000` to your host's `3000`, so the phone reaches the backend without needing its LAN IP. (The host's `127.0.0.1` only works because of the reverse tunnel, not because it's the same `localhost`.)

### Enable phone-side developer settings

- Enable **Developer options** and **USB debugging** (Settings → About phone → tap Build number 7×, then Developer options → USB debugging).
- Plug in the phone, and on a fresh computer, accept the **"Allow USB debugging"** prompt on the device.
- Confirm it shows up with `flutter devices` / `adb devices`.

### Real-device checklist

- [ ] Phone and computer on the **same Wi-Fi network**.
- [ ] Backend running on your computer (`npm run start:dev`).
- [ ] Your computer's firewall allows inbound connections on port `3000`.
- [ ] Cleartext HTTP allowed on the phone (see the Android note above) if using `http://`.
- [ ] Passed `--dart-define=API_BASE_URL=http://<your-LAN-IP>:3000` to `flutter run`.

---

## 5. Build a release APK (optional)

```bash
cd app
flutter build apk --release
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk`

> Release builds use the `release` signing config (currently the debug key) and only include the `main` manifest permissions. If you run a release build against `http://`, keep the cleartext flag from the troubleshooting note.

---

## Voice capture (optional)

Voice capture requires the AI providers to be configured on the backend:

1. Add `SARVAM_API_KEY` and `GEMINI_API_KEY` to `server/.env`.
2. Restart the server.

When neither key is set, the API boots fine but `POST /voice/capture` returns
`Voice capture is not configured on the server`, and the app's voice flow shows
the error. Manual expense entry still works.

---

## Useful commands

| Where   | Command                                   | What it does                        |
| ------- | ----------------------------------------- | ----------------------------------- |
| `app/`  | `flutter run`                             | Run on the active device/emulator   |
| `app/`  | `flutter run -d <id>`                     | Run on a specific device            |
| `app/`  | `flutter devices`                         | List connected devices              |
| `app/`  | `flutter test`                            | Run Flutter tests                   |
| `app/`  | `flutter analyze`                         | Static analysis                     |
| `server/`| `npm run start:dev`                      | Dev server (watch mode) on :3000    |
| `server/`| `npm run build`                          | Build the NestJS app                |
| `server/`| `npm run test`                           | Backend unit tests                  |
| `server/`| `npm run lint`                           | Lint the backend                    |
| repo root| `./clean-db.sh`                          | Drop + recreate DB (destructive)    |

---

## Troubleshooting

**App can't reach the server / network errors**
- Confirm the backend is running on port 3000.
- For a device, confirm you passed the correct `API_BASE_URL` and are on the same network.
- Try `curl http://<your-LAN-IP>:3000` from the phone's browser.

**`cleartext HTTP traffic to ... not permitted`**
- Add `android:usesCleartextTraffic="true"` to the `<application>` tag in `app/android/app/src/main/AndroidManifest.xml` (dev only).

**`Voice capture is not configured on the server`**
- Add `SARVAM_API_KEY` and `GEMINI_API_KEY` to `server/.env` and restart.

**Database is empty / missing tables**
- Run `npx prisma migrate deploy` from `server/`, or reset with `./clean-db.sh`.

**Google Sign-In fails / no Google account returned**
- Ensure the Google account exists and the web OAuth client id in `app/lib/services/auth_service.dart` matches your Firebase project.
- On an emulator, add a Google account in Settings → Accounts.
