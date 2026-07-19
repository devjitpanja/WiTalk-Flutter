Check my existing React Native project at:

/Users/dev/Documents/App Development/React Native/WiTalk/frontend

I am migrating this project from React Native to Flutter.

Before creating or modifying any Flutter screens, thoroughly analyze the React Native project and replicate the design as accurately as possible.

Requirements
Copy the UI and UX exactly from the React Native project.
Match the color palette, theme, typography, font sizes, font weights, spacing, padding, margins, border radius, shadows, animations, and component styling.
Use the same icons and ensure their colors, sizes, and styling match the React Native version exactly.
Preserve the same navigation behavior, interactions, and user experience.
Maintain the same layout and responsiveness across different screen sizes.
Theme
First, identify how the React Native project manages its theme (colors, typography, dark/light mode, constants, etc.).
Create an equivalent Flutter theme (ThemeData, color constants, text styles, etc.).
Every screen and widget in the Flutter project must use this centralized theme. Avoid hardcoding colors, fonts, or text styles unless absolutely necessary.
Important

During previous migrations, I noticed several inconsistencies:

Icon colors were different.
Background colors didn't exactly match.
Some text styles, spacing, and component colors were inconsistent.
Certain UI elements looked slightly different from the original React Native app.

Please pay extra attention to these details and ensure the Flutter implementation is pixel-perfect. The goal is that users should not be able to tell whether the app was built in React Native or Flutter.

Migration Rules
Do not redesign or modernize the UI.
Do not change the user experience.
Replicate the existing implementation as faithfully as possible.
Reuse the same assets, icons, illustrations, fonts, and branding.
If any design detail is unclear, inspect the React Native implementation before making assumptions.

The objective is a 1:1 migration from React Native to Flutter with no visual or UX differences.

Functionality & API Migration

This is not just a UI migration. Every feature from the React Native app must work exactly the same in Flutter.

Migrate all business logic and functionality.
Copy all API integrations exactly, including endpoints, request methods, headers, authentication, and payloads.
Ensure API request and response handling behaves identically to the React Native implementation.
Migrate all POST, GET, PUT, PATCH, and DELETE requests correctly.
Preserve all validation, loading states, success states, error handling, retry logic, and edge cases.
Ensure authentication, token refresh, session management, local storage/secure storage, notifications, deep links, and navigation flows continue to work exactly as before.
Every button, form, modal, bottom sheet, search, filter, upload, download, pagination, and user interaction must be fully functional.
Do not leave placeholder implementations, mock data, or TODOs. Every screen should be production-ready and connected to the actual backend APIs.
Before marking a screen as complete, verify that every UI element, API call, state update, and user interaction works exactly like the React Native version.

The goal is a complete 1:1 migration—not only visually, but also functionally. The Flutter app should behave exactly like the React Native app, with no missing features, broken API calls, or differences in user experience.

Cross-Platform Compatibility (Android & iOS)

The existing React Native project was primarily developed for Android, so some implementations, packages, permissions, or native code may be Android-specific. During the migration, identify any Android-only code or features and implement the appropriate Flutter cross-platform solution so that the app works seamlessly on both Android and iOS.

Ensure that all platform-specific permissions, file handling, media picker, notifications, deep links, camera, location, storage, authentication, and any native integrations are fully compatible with both platforms. If a React Native implementation does not support iOS, implement the required iOS equivalent in Flutter while preserving the same functionality and user experience. The final Flutter application should be production-ready for both Android and iOS, with no platform-specific features missing or broken.