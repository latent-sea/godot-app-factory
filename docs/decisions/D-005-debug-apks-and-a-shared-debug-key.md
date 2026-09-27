# D-005: Milestone 1 ships debug APKs signed by a shared debug key in the repo

**Problem.** An APK must be signed to install. A key made fresh on each
build would make each new APK refuse to install over the last without an
uninstall, which deletes the app's saved data.

**Decision.** `tooling/android/debug.keystore`, with Android's default debug
passwords, signs every debug APK, locally and in CI.

**Why.** A debug-signed APK can be sideloaded but Google Play refuses it, so
the key can publish nothing; committing it costs nothing and keeps installs
continuous.

**Reconsider at** milestone 2: release signing arrives, and release keys
never go in the repository.
