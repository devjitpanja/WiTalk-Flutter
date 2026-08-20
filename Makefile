.PHONY: android16 android15 dev both web mac phone iphone clean build-apk build-aab build-ipa sideload-ipa testios

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

# --- Build Android ---

# Signed release APK → build/app/outputs/flutter-apk/app-release.apk
apk:
	flutter build apk --release
	@echo "✅ APK ready at: build/app/outputs/flutter-apk/app-release.apk"

# Signed release AAB → build/app/outputs/bundle/release/app-release.aab
aab:
	flutter build appbundle --release
	@echo "✅ AAB ready at: build/app/outputs/bundle/release/app-release.aab"

# Build both APK and AAB
android: apk aab
	@echo "✅ Android builds complete"

# Split APKs per ABI (smaller downloads, good for direct distribution)
apk-split:
	flutter build apk --release --split-per-abi
	@echo "✅ Split APKs ready at: build/app/outputs/flutter-apk/"

# Legacy aliases
build-apk: apk
build-aab: aab

# Signed IPA for Sideloadly → build/ios/ipa/
testios:
	flutter build ipa --release --export-method development
	@echo "✅ IPA ready at: build/ios/ipa/"

build-ipa:
	flutter build ipa

# Builds an unsigned IPA ready for Sideloadly
sideload-ipa:
	flutter build ipa --release --no-codesign --no-tree-shake-icons
	rm -rf /tmp/WiTalkSideload
	mkdir -p /tmp/WiTalkSideload/Payload
	cp -r "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app" /tmp/WiTalkSideload/Payload/
	cd /tmp/WiTalkSideload && zip -r WiTalk.ipa Payload
	mkdir -p build/ios/ipa
	cp /tmp/WiTalkSideload/WiTalk.ipa build/ios/ipa/WiTalk-sideload.ipa
	rm -rf /tmp/WiTalkSideload
	@echo "✅ IPA ready at: build/ios/ipa/WiTalk-sideload.ipa"

# --- Utilities ---

clean:
	flutter clean && flutter pub get

# Regenerate code (Riverpod, Drift, etc.)
codegen:
	dart run build_runner build --delete-conflicting-outputs

codegen-watch:
	dart run build_runner watch --delete-conflicting-outputs
