# Setup — Xpense Tracker

The app runs **fully offline** out of the box. The only setup below is for the *optional* Google Drive backup feature. Skip it if you don't need backups.

## 1. Get the project running

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # only if drift schema changes
flutter run                                                # plug in an Android device
```

Requires the Flutter SDK with Dart `^3.11.5`. Android is the only maintained
platform — the other platform folders are stock `flutter create` scaffolding.

Sanity checks before you commit:

```bash
flutter analyze
flutter test
```

## 2. (Optional) Enable Google Drive backup

Backups land in a **hidden app-data folder** on the signed-in user's Drive — invisible in their Drive UI, scoped to this app only. To make sign-in work on your device, you need an OAuth 2.0 client ID in Google Cloud Console.

### a) Get your debug SHA-1

```bash
cd android
./gradlew signingReport
```

Look for the block under `Variant: debug`. Copy the **SHA-1** line.

(For release builds later, generate a release keystore and grab its SHA-1 the same way.)

### b) Create a Google Cloud project

1. <https://console.cloud.google.com> → top bar → **New project** (or reuse one).
2. **APIs & Services** → **Library** → search **Google Drive API** → **Enable**.
3. **APIs & Services** → **OAuth consent screen**:
   - User type: **External**
   - App name: `Xpense Tracker` (or your own)
   - Support email: yours
   - Scopes: add `.../auth/userinfo.email` and `.../auth/drive.appdata`
   - Test users: add your own Google account
4. **APIs & Services** → **Credentials** → **Create credentials** → **OAuth client ID**:
   - Type: **Android**
   - Package name: the `applicationId` from `android/app/build.gradle.kts` (default: `com.example.xpense_traker`)
   - SHA-1: paste from step (a)

No `google-services.json` is needed — that's for Firebase. `google_sign_in` 6.x matches via package name + SHA-1 at runtime.

### c) Try it out

1. `flutter run` → Settings → **Backup** → **Connect Google**
2. Sign in with the test-user account you added in step (b).
3. Tap **Back up now** → "Backup uploaded ✓".
4. To see your backup file metadata, visit <https://myaccount.google.com/permissions> — this app should appear with "View and manage its own configuration data in your Google Drive". (You won't see the file in the normal Drive UI; that's by design.)

### Troubleshooting

- **"Sign-in not configured (error 10)"** — `DEVELOPER_ERROR`. Google matches the app by
  `(package name + SHA-1 of the signing key)` and found no OAuth client for that pair. Either the
  fingerprint was never registered, or **the signing key changed** — a new machine has a new debug
  keystore, and a regenerated release keystore has a new fingerprint too. Fix it in the Console, not
  in the code: see [§ 4](#4-changing-machines-or-rotating-the-signing-key).
- **There is no client ID in this codebase, and that's correct.** `GoogleSignIn` is constructed with
  scopes only (`google_auth.dart`), there's no `google-services.json`, and Android OAuth clients are
  never referenced by ID at runtime. Pasting a client ID into the app fixes nothing.
- **"Sign in failed" / silent fail**: 90% of the time this is the SHA-1 mismatch. Re-run `./gradlew signingReport`, paste the *exact* SHA-1 (uppercase, with colons), wait a couple of minutes for Google to propagate.
- **"This app is blocked"**: your test account isn't in the consent-screen test-users list. Add it.
- **"403 storageQuotaExceeded"**: the user's Drive is full. We surface this in the Backup screen.
- **Nothing changed after editing an OAuth client** — propagation takes 5 minutes to a few hours
  (Google says so on the client page). Retrying immediately still returns error 10 and looks like
  the edit failed. Also confirm the edit actually *saved*: the toast reads **"OAuth client saved"**,
  which is not the same as **"Client ID copied to clipboard"**.

### "This app isn't verified" on the login screen

This is **not** about your APK signing or "unknown sources" — it's Google's **OAuth consent-screen warning**. It appears because the consent screen is in **Testing** mode (or unverified Production) *and* the app requests a **sensitive scope** (`drive.appdata`). Google requires a formal verification review before showing that consent to the public without a warning.

**To get past it (you / your test users):**
1. On the warning, tap **Advanced** (bottom-left).
2. Tap **"Go to Xpense Tracker (unsafe)"** → continue → grant access.

This works as long as the account is listed under **OAuth consent screen → Test users** (up to 100). For personal use or a handful of users, this is the normal, correct path — **no verification needed**.

**To remove the warning entirely (public release):** OAuth consent screen → **Publish app** (Production) → complete **verification** (privacy policy URL, app/domain ownership, scope justification). Can take days to weeks.

> ⚠️ **7-day token expiry in Testing mode.** While the consent screen is in *Testing*, Google expires refresh tokens after **7 days** for sensitive scopes. This means silent sign-in (used by auto-backup) stops working roughly weekly and the user must reconnect under Settings → Backup. For reliable long-term auto-backup, publish to **Production (verified)**.

---

## 3. Release builds

> **`flutter run` vs `flutter build apk`** — `flutter run [--release]` builds, installs, and *launches* the app on a connected device for testing; it does not give you a shareable `.apk`. To produce an installable APK file, use **`flutter build apk`** (see step **d** below). Outputs land in `build/app/outputs/flutter-apk/`.

Debug-signed APKs from `flutter run` are fine for development, but to publish or sideload to other devices you need a release keystore + a separate OAuth client.

### a) Generate a release keystore (one-time, NEVER lose this)

```bash
mkdir -p ~/keystores
keytool -genkeypair -v -keystore ~/keystores/xpense-release.jks \
  -keyalg RSA -keysize 4096 -validity 10950 -alias xpense
```

⚠ **Back up the `.jks` file and its passwords to a password manager + encrypted cloud storage —
somewhere that is not this laptop.** Losing it means every existing user must uninstall (destroying
their local database) before they can install your next version. That has already happened once to
this app; see [§ 4](#4-changing-machines-or-rotating-the-signing-key).

The keystore is **not** a build artifact. It, its passwords, and the fingerprints registered in
Google Cloud are the app's permanent identity — treat them like the domain name, not like
`build/`.

### b) Wire it into the build

Create `android/key.properties` (gitignored):

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=xpense
storeFile=/absolute/path/to/xpense-release.jks
```

The `android/app/build.gradle.kts` in this repo already loads `key.properties` if present, enables R8 + resource shrinking, and signs the `release` build type with it. If the file is missing, it falls back to debug signing so CI / fresh clones still build.

### c) Register the release SHA-1 with Google Cloud

```bash
cd android && ./gradlew signingReport   # copy the "Variant: release" SHA-1
```

In Google Cloud Console → **APIs & Services → Credentials** → **+ Create credentials → OAuth client ID**:
- Type: **Android**
- Name: `Xpense Tracker Android (release)`
- Package name: `com.example.xpense_traker`
- SHA-1: the release fingerprint you just copied

You'll end up with **two** OAuth clients (debug + release) sharing the same package name. That's correct — Google Sign-In matches by `(package + SHA-1)` at runtime and routes each build to the right client.

Wait ~5 minutes after saving for propagation.

### d) Build

```bash
flutter clean && flutter pub get
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols/1.0.3   # match pubspec `version:`
```

Outputs three APKs in `build/app/outputs/flutter-apk/`. Ship `app-arm64-v8a-release.apk` to ~95 % of users.

For Play Store, use `flutter build appbundle --release ...` instead. Play re-signs the bundle with its own "App Signing" key — you'll need to register **that** SHA-1 (visible in Play Console → App integrity, after the first upload) as a **third** OAuth client.

### e) Always archive

Each release: keep the matching `build/symbols/<version>` folder, the APK files, and a note of the git commit hash. Without the symbols, obfuscated crash reports from that build can never be decoded.

---

## 4. Changing machines, or rotating the signing key

Both signing keys live outside the repo, so a fresh laptop has **neither**. Sign-in then fails with
error 10 on every build until the new fingerprints are registered. This section is the recovery
playbook — it has already been needed once.

### a) Work out which key signs the build you're testing

| Build | Signed with | Fingerprint from |
| --- | --- | --- |
| `flutter run` / `flutter build apk --debug` | `~/.android/debug.keystore` (auto-created per machine) | `Variant: debug` |
| `flutter build apk --release` with `android/key.properties` present | your release keystore | `Variant: release` |
| `flutter build apk --release` **without** `key.properties` | falls back to the *debug* key — see `build.gradle.kts` | `Variant: debug` |

That last row is the quiet one: a "release" APK can be debug-signed, and then only the debug
fingerprint will let it sign in.

```bash
cd android && ./gradlew signingReport      # both variants, SHA-1 and SHA-256
```

To check what actually signed an APK you already built or downloaded:

```bash
$ANDROID_HOME/build-tools/<ver>/apksigner verify --print-certs app-arm64-v8a-release.apk
```

### b) If you still have the release keystore

Copy the `.jks` across, recreate `android/key.properties` pointing at it (see § 3b), and register
the **new machine's debug** SHA-1. The release fingerprint is unchanged, so existing installs keep
updating normally. Nothing else to do.

### c) If the release keystore is gone

It cannot be recovered or recreated — the fingerprint is derived from a private key that no longer
exists. Generate a new one (§ 3a) and accept the consequences:

- **Every existing install must be uninstalled** before the new build will install. Android refuses
  an APK whose certificate differs from the installed one, and there is no override.
- **Uninstalling wipes the local database.** Tell users to back up to Drive *first*, in the old
  version, while its sign-in still works — which means fixing the OAuth fingerprint before you ship,
  not after.
- Bump `version:` in `pubspec.yaml` as usual; the version code is unrelated to signing.

### d) Update the OAuth clients

Google Cloud Console → **APIs & Services → Credentials**. There is one Android client per
`(package name, SHA-1)` pair, and the fingerprint field is editable.

**Edit the existing clients rather than creating new ones.** When a key is gone for good there is
nothing to preserve, and replacing keeps the list at two working clients instead of four with two
dead ones. Creating a second client is only right when both keys are still in use.

| Client | Set its SHA-1 to |
| --- | --- |
| `Xpense Tracker Android (release)` | `Variant: release` fingerprint of your release keystore |
| `Xpense Tracker Android (debug)` | `Variant: debug` fingerprint from *this* machine |

Package name stays `com.example.xpense_traker` on both. Save — confirm the toast says **"OAuth
client saved"** — then wait 5+ minutes for propagation before retrying on the device.

### e) Checklist

```text
[ ] release keystore restored or regenerated, and backed up OFF this machine
[ ] android/key.properties recreated (gitignored — never commit it)
[ ] ./gradlew signingReport run; both SHA-1s copied
[ ] release OAuth client SHA-1 updated + saved
[ ] debug OAuth client SHA-1 updated + saved
[ ] your account still listed under OAuth consent screen → Test users
[ ] waited for propagation, then Connect Google succeeds on a real build
[ ] if the release key changed: release notes warn users to back up before uninstalling
```
