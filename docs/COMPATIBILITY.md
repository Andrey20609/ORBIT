# ORBIT — compatibility and data policy

## Engine compatibility matrix

| Target | Flutter renderer | Rive | Filament | Status |
|---|---|---|---|---|
| Android ARM64, API 24+ | Impeller | Native, subject to capability check | Experimental native PBR | Static build verification only until physical-device test |
| Android x86_64 debug | Skia fallback for the known emulator driver | Native allowed for tests | Native allowed for tests | Integration tested on Android 15 emulator |
| Android x86_64 release | Skia fallback | Disabled fail-closed; Static | Available when native stats prove rendering | Safe launch required; not a general guarantee for every GPU |
| Other platforms | Platform default | Platform default when available | Unsupported notice + Static | No native Filament claim |

Pinned verification toolchain: Flutter 3.47.9, Dart 3.13.7, Java 17, Android SDK 37, Filament 1.79.0, Rive Flutter 0.14.11 / rive_native 0.1.11.

The x86_64 release opt-out addresses a reproduced Impeller/Rive GL driver crash. Flutter logs `Impeller opt-out deprecated`; therefore this is a compatibility fallback, not a permanent policy. Re-test every Flutter/Rive upgrade and remove the override only after a real release smoke test proves the affected driver safe. Unknown or malformed capability responses always select Static and never permit native Rive initialization.

## Package and signing policy

- The stable application ID remains `app.orbit.orbit_visual_lab` for ORBIT 0.5.x so upgrades do not wipe user data.
- The current Android Debug signature is for test APKs only and is not accepted for store publication.
- Do not change application ID or signing key without an explicit migration plan. A different ID installs a separate application; a different key blocks a normal upgrade.
- Before distribution, approve a production identity/signing policy and verify an upgrade path from test installations without deleting preferences.

## Local data security boundary

- ORBIT 0.5.x contains explicitly marked demonstration data only. Tasks, events, read flags and draft text are JSON in ordinary `SharedPreferences` for local persistence tests.
- Plain preferences are not approved for real mail, credentials, tokens, passwords, personal production documents or other sensitive payloads.
- `FlutterOrbitSecretStore` is the only adapter intended for future secrets. It uses platform secure storage; no secrets are written in this version.
- Real mail and production user content must use an approved encrypted storage design before enabling those features. Do not silently migrate real messages into the demo JSON repository.
- QA exports remain local and must exclude credentials and real personal content. Root and sandbox bypasses are not used for evidence collection.
