# Digidropp Todos (Flutter)

A small todo app for testing [Digidropp](https://digidropp.online) automatic builds of a Flutter app whose config
lives in a `.env` file that isn't committed.

- Android package: `online.digidropp.todo`
- Flutter version: pinned in `.fvmrc` (Digidropp builds use it)
- Reads `APP_TITLE`, `ENVIRONMENT`, `ACCENT_COLOR` and `API_URL` from `.env` (see `.env.example`). Tap the
  environment badge in the app to see which values the build used.

## Build it with Digidropp

1. Push this repo to GitHub.
2. In Digidropp, open **Automatic builds**, connect the repo and merge the pull request it opens.
3. On the repo's card, click **Add variables**, choose **Paste .env** and paste the contents of `.env.example`
   (change the values if you like). Save.
4. Push a commit. The build log shows `Created .env with 4 variables`, and the installed app shows your values.

Without step 3 the build fails, because `pubspec.yaml` lists `.env` as an asset. Digidropp shows that error with a
hint on the Automatic builds page.

## Run locally

```
cp .env.example .env
flutter run
```
