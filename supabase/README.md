# SUPER - Docs Supabase backend

Configured project: `ffwwirwgambgmqdqbbhi`, `https://ffwwirwgambgmqdqbbhi.supabase.co`.
The app uses the public settings in `lib/supabase_config.dart` by default, so normal IDE launches support login. `config/supabase.json` can also supply build overrides.
This file contains a publishable key, never a service-role key.

## What runs where

| Service | Location |
| --- | --- |
| Google login, session refresh, user identity | Supabase Auth |
| Private completed file bytes | Supabase Storage, private `documents` bucket |
| File names, favorites, created dates, owners | Supabase Postgres with RLS |
| Mobile AI photo enhancement | Bundled ESRGAN/TensorFlow Lite model on the device; no server |
| Merge, split, extract, organize, rotate, numbering, simple text watermark | Edge Function with pdf-lib |
| Office-to-PDF, searchable OCR, standard PDF-to-Office, encryption/decryption, rendered images, markup, compression, repair | Existing Docker/Python processing worker over HTTPS |
| Local image resize/compression/conversion and PDF creation | Flutter device |

Supabase Edge Functions cannot run LibreOffice or Tesseract. A reachable worker remains necessary for those operations. The cloud gateway authenticates the caller and calls that worker using a private shared secret, never the user's access token. Mobile image enhancement is offline. The optional PC Upscayl worker requires a Vulkan-compatible GPU; see `backend/UPSCAYL.md`.

## 1. Deploy database and function

From `C:\ALI - Docs` in PowerShell:

```powershell
npx supabase login
npx supabase link --project-ref ffwwirwgambgmqdqbbhi
npx supabase db push --dry-run
npx supabase db push
npx supabase functions deploy docs-process --project-ref ffwwirwgambgmqdqbbhi
```

Keep your login token and database password private; enter them in your terminal if prompted. These commands create the metadata table, private bucket, owner-only access policies, and an atomic 100-request daily budget per user. If a table named `documents` already exists, review the schema first; this migration intentionally does not overwrite an unrelated existing table.

Alternative for the database: paste `migrations/202610080001_documents.sql` into the project's **SQL Editor** and run it. Deploy the function with the CLI afterwards. The publishable key cannot apply migrations or deploy functions.

For AI, copy `supabase/.env.example` to `supabase/.env` and fill in the values privately. Set function secrets:

```powershell
npx supabase secrets set --env-file supabase/.env --project-ref ffwwirwgambgmqdqbbhi
```

No Gemini API key is required. Set `ALLOWED_ORIGINS` to your exact hosted web origin(s), comma separated. Mobile requests do not require a browser Origin header. Do not put AI keys or worker secrets in Flutter build configuration.

## 2. Enable Google login

1. Open [Google Cloud OAuth clients](https://console.cloud.google.com/auth/clients). Select or create your Google Cloud project and configure its OAuth consent screen with the SUPER - Docs app name and your support email. While the app is in testing, add your Google account as a test user.
2. Create an OAuth client of type **Web application**. This app uses browser OAuth with a mobile deep-link callback, so this client works for Flutter mobile and web.
3. Add web development origins `http://localhost:8080` and `http://127.0.0.1:8080`, plus your eventual hosted web origin.
4. Add this **Authorized redirect URI** exactly:

```text
https://ffwwirwgambgmqdqbbhi.supabase.co/auth/v1/callback
```

5. In [your project's Google provider settings](https://supabase.com/dashboard/project/ffwwirwgambgmqdqbbhi/auth/providers), enable Google. Paste the Google client ID and client secret there and save. Keep the client secret in Supabase, not in chat or Flutter.
6. In [Supabase URL Configuration](https://supabase.com/dashboard/project/ffwwirwgambgmqdqbbhi/auth/url-configuration), set your production Site URL when available and add these redirect URLs:

```text
com.superdocs.app://login-callback/
http://localhost:8080
http://127.0.0.1:8080
```

Add your hosted web origin too. The Supabase callback above goes in **Google Cloud**; the app callback goes in **Supabase's redirect allowlist**. Flutter already includes the Android intent filter, iOS URL scheme, PKCE login, persisted session recovery, and sign-out.

The project now reports Google as enabled. Its authorization endpoint redirects to accounts.google.com with the configured Supabase callback URL. A completed account login is still needed to verify the return to the app.

## 3. Build and run the configured app

```powershell
flutter run --dart-define-from-file=config/supabase.json
flutter run -d chrome --web-port 8080 --dart-define-from-file=config/supabase.json
flutter build apk --release --dart-define-from-file=config/supabase.json
flutter build web --release --dart-define-from-file=config/supabase.json
```

Sign in from **Profile** or **My files** using **Continue with Google**. Cloud processing requires a signed-in session; local tools still work as a guest. Guest files stay in the guest workspace. Each signed-in user's device cache and cloud files are separated; signing out returns to the guest files without deleting any account's files. Signed-in completions save locally first and upload in the background. Use **Sync files** to retry offline uploads or deletions. Documents are private and accessed with the owner's session, not public URLs.

Cloud processing accepts at most 12 MB total and 5 files per task; Upscayl photo enhancement accepts one file per task. Private Storage supports completed files up to 50 MB. Oversized or failed cloud saves keep device copies. PDF tasks have a 500-page cap; AI documents have a 100-page cap. Advanced worker tasks remain bounded by the hosted Edge Function timeout; split large inputs when necessary.

## 4. Host the native processing worker

Build the existing `backend/Dockerfile` on a container host. Set a strong `PROCESSOR_SHARED_SECRET` there and the same value in Supabase function secrets. Set the worker's HTTPS base URL as `PROCESSOR_URL` in Supabase secrets. When the worker secret is configured, direct unauthenticated processing requests receive 401. The worker does not need a Gemini key for standard conversions; Upscayl executes on the GPU worker. Worker health still reports Office and OCR engine availability.

This repo supplies the worker image and Supabase integration. It does not provision a container host, Supabase account, Google Cloud account, or OAuth consent verification.

## Verification

```powershell
flutter analyze
flutter test --no-pub
.tools/node_modules/.bin/deno.cmd check --config supabase/functions/docs-process/deno.json supabase/functions/docs-process/index.ts
.tools/node_modules/.bin/deno.cmd test --allow-env --allow-read --config supabase/functions/docs-process/deno.json supabase/functions/docs-process/handler_test.ts
npx supabase test db
```

Database policy tests require a running local Supabase/Docker instance or a disposable test project with the migration applied. Deno tests mock Google/Auth HTTP calls, verify session rejection, quotas, private secret routing, and parse real generated files. Flutter tests cover account isolation, offline sync retry, and account switching during uploads. Live Google sign-in requires the provider setup above; live cloud storage also requires the deployed migration.

References: [Google Auth setup](https://supabase.com/docs/guides/auth/social-login/auth-google), [Flutter OAuth](https://supabase.com/docs/reference/dart/auth-signinwithoauth), [Storage access policies](https://supabase.com/docs/guides/storage/security/access-control), [Edge Function runtime limits](https://supabase.com/docs/guides/functions/limits).


## Deployment status

The database migration `202610080001_documents.sql`, private `documents` bucket and `docs-process` Edge Function have been deployed to `ffwwirwgambgmqdqbbhi`. The app mobile callback and development web origins are configured. Live read-only checks confirmed the bucket is private, both tables have RLS, all owner policies are present, and anonymous processing returns 401.

Google's provider is enabled and its OAuth redirect has been verified. Complete Google sign-in on the device to validate session creation and cloud syncing. Live authenticated smoke tests requiring temporary administrative users were not run; automated approval review rejected those service-role operations. No temporary users were created.


## Device login check

The default IDE launch now initializes the supplied Supabase project, and the updated Android app reaches Google's OAuth page. The Google Web OAuth callback has been corrected to `https://ffwwirwgambgmqdqbbhi.supabase.co/auth/v1/callback`. A fresh sign-in from the installed app now reaches Google's account chooser without a redirect error. Android's `com.superdocs.app://login-callback/` routing is already verified.

The Profile page is available from the top-right avatar and the signed-in account panel. Edited display names are stored separately from Google-provided names so subsequent Google logins preserve the app profile name. OAuth callback failures now appear directly in the app.
