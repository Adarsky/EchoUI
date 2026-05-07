# Project Structure

This project is organized around the app layers a user or developer needs to understand first.

## App

- `FrontendAI/App/FrontendAIApp.swift`: SwiftUI app entry point.
- `FrontendAI/App/Info.plist`: app Info.plist used by the Xcode target.

## Core

- `FrontendAI/Core/Bots`: bot data types and model helpers.
- `FrontendAI/Core/Chat`: shared chat/message data types.
- `FrontendAI/Core/Environment`: SwiftUI environment keys.
- `FrontendAI/Core/Personas`: persona data types and manager.

## Features

- `FrontendAI/Features/API`: API configuration models, API services, OpenRouter helpers, and API management views.
- `FrontendAI/Features/Bots`: bot creation and editing views.
- `FrontendAI/Features/Chat`: chat screens, chat generation/history extensions, stream service, and chat UI components.
- `FrontendAI/Features/Export`: export screen.
- `FrontendAI/Features/Personas`: persona creation and editing views.
- `FrontendAI/Features/Settings`: main/settings screens and related settings views.
- `FrontendAI/Features/Usage`: cache, statistics, token usage, and data network views.

## Shared UI

- `FrontendAI/SharedUI/Components`: reusable standalone UI components.
- `FrontendAI/SharedUI/Sheets`: reusable sheet views.

## Resources

- `FrontendAI/Resources/Assets.xcassets`: app icons, accent color, and AI company image assets.
- `FrontendAI/PreviewContent/PreviewAssets.xcassets`: SwiftUI preview-only assets.
- `Documentation/Screenshots`: screenshots used by the README.
