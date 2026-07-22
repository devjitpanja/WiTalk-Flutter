.PHONY: android16 android15 dev both web mac phone iphone clean build-apk build-aab build-ipa

# --- Launch Emulators (run one of these first, then run 'make dev') ---

android16:
	flutter emulators --launch Android16

android15:
	flutter emulators --launch Android15

# --- Run App ---

# Run on whatever device/emulator is available (prompts if multiple)
dev:
	flutter run

# Run on both emulators simultaneously
both:
	flutter run -d emulator-5554 & flutter run -d emulator-5556 & wait

# Run on physical wireless Android phone
phone:
	flutter run -d 22021211RI

# Run on physical iPhone (wired)
iphone:
	flutter run -d 00008120-000E54D23672201E

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

build-ipa:
	flutter build ipa

# --- Utilities ---

clean:
	flutter clean && flutter pub get

# Regenerate code (Riverpod, Drift, etc.)
codegen:
	dart run build_runner build --delete-conflicting-outputs

codegen-watch:
	dart run build_runner watch --delete-conflicting-outputs
