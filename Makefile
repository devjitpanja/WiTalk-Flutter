.PHONY: android16 android15 dev web mac phone clean build-apk build-aab

# --- Launch Emulators (run one of these first, then run 'make dev') ---

android16:
	flutter emulators --launch Android16

android15:
	flutter emulators --launch Android15

# --- Run App ---

# Run on whatever device/emulator is available (prompts if multiple)
dev:
	flutter run

# Run on physical wireless Android phone
phone:
	flutter run -d 22021211RI

# Run on Chrome browser
web:
	flutter run -d chrome

# Run on macOS desktop
mac:
	flutter run -d macos

# --- Build ---

build-apk:
	flutter build apk

build-aab:
	flutter build appbundle

# --- Utilities ---

clean:
	flutter clean && flutter pub get

# Regenerate code (Riverpod, Drift, etc.)
codegen:
	dart run build_runner build --delete-conflicting-outputs

codegen-watch:
	dart run build_runner watch --delete-conflicting-outputs
