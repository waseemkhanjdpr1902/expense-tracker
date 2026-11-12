# Expense Pocket Android test wrapper

This prototype packages the sibling `expense-pocket-web` files as local Android assets. It does not load the Vercel website and Android entries are separate from website browser data. Website changes require rebuilding the Android package.

Build with Android SDK 36, Java 17, and Gradle 8.11.1 or newer compatible with Android Gradle Plugin 8.10.1:

```sh
cd expense-pocket-android
gradle :app:assembleDebug
gradle :app:bundleRelease
```

Release builds are deliberately unsigned. A Play upload requires a privately held upload key and secure signing setup; never commit a keystore or passwords. No AdMob, billing, push notifications, or production signing is configured. Validate backup export/import, navigation, offline operation, device compatibility, Android policy and privacy disclosures before Play distribution.
