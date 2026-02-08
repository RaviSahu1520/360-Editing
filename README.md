# photo_editor_auto_improve

A new Flutter project.

## API Connection

This app reads backend URL from Flutter `--dart-define` values.

Supported keys:
- `PHOTO_EDITOR_API_URL`
- `API_BASE_URL`

Example using your provided API base URL:

```bash
flutter run --dart-define=API_BASE_URL=https://api.fitcheckaiapp.com
```

Notes:
- Only the backend URL is used directly by this Flutter app.
- Keep provider secrets (Supabase secret key, Pinecone key, Gemini/OpenAI keys) on backend only.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
