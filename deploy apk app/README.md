# pbl6_app

Flutter application for monitoring and analyzing indoor air quality (IAQ). The app provides a clean dashboard, a real Firestore-backed monthly heatmap, and an AI-powered analysis that summarizes the current situation and suggests actionable improvements.

## Overview

This project is part of a PBL6 assignment. It focuses on: 
- Visualizing IAQ readings in a meaningful, responsive UI.
- Allowing users to switch the analysis window between 1 day / 1 week / 1 month.
- Integrating an OpenAI-compatible API (DeepSeek / HF router) to produce practical recommendations based on recent IAQ data.
- Moving test/control writes from Firestore to Firebase Realtime Database (via a minimal REST client).

## Features

- Dashboard
	- Recent sensor data and System Metrics arranged responsively.
	- “Connection” status displayed consistently.

- Report Heatmap
	- Uses real IAQ data from Firestore, grouped by day for the previous month.
	- Fills horizontal space and supports horizontal scrolling of the entire month at once.
	- Fixed Y-axis (day labels) similar to the dashboard chart.
	- EPA-style color scale with a small legend.

- AI Analysis
	- OpenAI-compatible client with configurable API key, base URL, and model.
	- In-app “AI Settings” dialog (stored with SharedPreferences) so dart-define is optional.
	- Mode selector: 1 Day / 1 Week / 1 Month. Switching modes automatically recomputes the IAQ average window and re-runs the analysis.
	- Enhanced prompt: ~120–200 word analysis + 5–8 prioritized, actionable recommendations.

- Firebase
	- Reads IAQ from Firestore for reporting.
	- Sends control/test payloads to Realtime Database using a small REST helper.

## Technology

- Flutter, Dart
- Firebase: Cloud Firestore (reads), Realtime Database (REST writes)
- HTTP client, SharedPreferences
- OpenAI-compatible Chat Completions (DeepSeek / HF router)

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## AI (DeepSeek) configuration

This app can call an OpenAI-compatible Chat Completions API for AI analysis. Configure it using Dart defines to avoid hardcoding secrets.

1) Local defines file (recommended for development)

Create `dart-defines.local.json` in the project root (already ignored by .gitignore) with:

{
	"DEEPSEEK_API_KEY": "hf_...",
	"DEEPSEEK_BASE_URL": "https://router.huggingface.co/v1",
	"DEEPSEEK_MODEL": "deepseek-ai/DeepSeek-V3.1:novita"
}

Run the app using the file:

flutter run --dart-define-from-file=dart-defines.local.json

2) Or pass defines inline:

flutter run `
	--dart-define=DEEPSEEK_API_KEY=hf_xxx `
	--dart-define=DEEPSEEK_BASE_URL=https://router.huggingface.co/v1 `
	--dart-define=DEEPSEEK_MODEL=deepseek-ai/DeepSeek-V3.1:novita

Notes:
- `DEEPSEEK_API_KEY` is required. The other two are optional (defaults point to the DeepSeek API and `deepseek-chat`).
- Never commit real API keys. The .gitignore already excludes `dart-defines.local.json`.


