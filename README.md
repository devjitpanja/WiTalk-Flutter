/Users/dev/Documents/App Development/React Native/WiTalk/frotnend



# WiTalk — Flutter

## Run the App

All commands are run from the project root via `make`.

### Typical Dev Workflow

```bash
make android16    # boot Android 16 emulator
# wait for emulator to fully load, then:
make dev          # run app with hot reload
```

### Run Targets

| Command | What it does |
|---|---|
| `make dev` | Run on any available device (prompts if multiple) |
| `make android16` | Launch Android 16 emulator |
| `make android15` | Launch Android 15 emulator |
| `make phone` | Run on physical wireless Android |
| `make web` | Run in Chrome browser |
| `make mac` | Run as macOS desktop app |

### Hot Reload (while `make dev` is running)

| Key | Action |
|---|---|
| `r` | Hot Reload — injects changes, **keeps app state** |
| `R` | Hot Restart — full restart, resets state |
| `q` | Quit |

> VS Code Flutter extension hot reloads automatically on every file save.

---

## Build

| Command | What it does |
|---|---|
| `make build-apk` | Build release APK |
| `make build-aab` | Build release App Bundle (Play Store) |

### Safe Release Build Flow

```bash
make clean        # clear all build caches
make build-apk    # or make build-aab
```

---

## Utilities

| Command | What it does |
|---|---|
| `make clean` | `flutter clean` + `flutter pub get` — clears all build caches |
| `make codegen` | Regenerate Riverpod/Drift generated files |
| `make codegen-watch` | Auto-regenerate on file save |

### When to run `make clean`

- Build errors that make no sense
- Changed `AndroidManifest.xml` or `build.gradle`
- Added/updated a native plugin
- Before any release build
- Switching between debug and release

---

## Adding Packages

```bash
flutter pub add package_name     # add a dependency
flutter pub get                  # install after editing pubspec.yaml manually
```

---

## Project Structure

```
lib/               # all Dart/Flutter source code
assets/            # images, icons, lottie animations, audio, fonts
android/           # native Android config
ios/               # native iOS config
pubspec.yaml       # dependencies (equivalent to package.json)
Makefile           # shortcut commands (equivalent to package.json scripts)
```
