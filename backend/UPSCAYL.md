# Optional PC Upscayl worker

The Flutter mobile app now uses bundled offline ESRGAN/TensorFlow Lite inference. It does not require this worker. The instructions below apply only to the optional PC/server engine.

Gemini has been replaced by the official Upscayl NCNN engine. No Google API key or per-image provider charge is required. GPU hosting still has a cost.

## Development on this PC

The Windows engine and standard 4x model are installed under `backend/runtime/upscayl` (ignored by version control). A real 32x32 image successfully returned a 64x64 PNG on this PC.

To install again:

```powershell
backend/.venv/Scripts/python.exe backend/install_upscayl.py
backend/.venv/Scripts/python.exe -m uvicorn app:app --app-dir backend --host 127.0.0.1 --port 8000
```

For emulator development without cloud login, start the PC worker above and run:

```powershell
flutter run --dart-define=SUPABASE_URL= --dart-define=PROCESSOR_URL=http://10.0.2.2:8000
```

For a USB-connected Android phone, use `adb reverse tcp:8000 tcp:8000` and `PROCESSOR_URL=http://127.0.0.1:8000` with `SUPABASE_URL=`. These development builds use guest mode; the production Supabase configuration keeps Google login. The app's local enhancement option works without a server.

## Supabase deployment

Supabase Edge Functions forward enhancement to the existing worker; they cannot run the native GPU engine themselves. Host the worker on a machine with a Vulkan-compatible GPU and drivers, install the engine/models, and expose it through HTTPS. Set `PROCESSOR_SHARED_SECRET` privately on both the worker and Supabase, and set `PROCESSOR_URL` in Supabase to its HTTPS base URL. This repository does not provision a GPU host.

Worker settings:

- `UPSCAYL_BIN`: optional absolute path to the engine; runtime files are discovered automatically.
- `UPSCAYL_MODELS`: optional model directory containing `upscayl-standard-4x.bin` and `.param`.
- `PROCESSOR_SHARED_SECRET`: authenticates requests from Supabase.

The endpoint accepts one image, offers 2x or 4x output, caps output at 32 megapixels, isolates temporary files, runs one GPU job at a time, and kills jobs after 100 seconds. API health reports engine/model availability, not a live GPU test.

The Docker image includes Vulkan runtime dependencies; it does not bundle a GPU driver. Supply the host's GPU devices and appropriate drivers. Mount installed binaries/models or run the installer for the target platform.

## Upstream software

- Engine/source: https://github.com/upscayl/upscayl-ncnn (AGPL-3.0; its LICENSE is retained in the downloaded runtime).
- Standard model: https://github.com/upscayl/upscayl/tree/v2.15.0/resources/models
- App/source: https://github.com/upscayl/upscayl

Retain upstream notices and meet the applicable source-availability and model-license terms when distributing or hosting the engine.
