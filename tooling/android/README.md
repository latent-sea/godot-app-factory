# Android

## Debug keystore

`debug.keystore` signs every app's **debug** APK, in CI and on your machine.
Its passwords are the Android defaults, stated here on purpose:

| | |
| --- | --- |
| alias | `androiddebugkey` |
| store and key password | `android` |

It is not a secret. A debug-signed APK can be installed by sideloading, but
Google Play refuses it, so this key cannot publish anything. It's committed so
that every build is signed by the same key. Each new APK then installs over
the previous one without an uninstall, which would otherwise wipe the app's
saved data.

Release keys never go in this repository.

## Exporting an app

`tooling/export_android.py <app>` writes `build/<app>-debug.apk`. It expects
Godot 4.6.2 with its Android export templates, a JDK 17+ and an Android SDK.
Where to find each one is in the script's own help (`--help`).
