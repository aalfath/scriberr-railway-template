[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/scriberr?utm_medium=integration&utm_source=button&utm_campaign=scriberr)

# Deploy and Host Scriberr on Railway

Scriberr is an open-source, self-hosted audio transcription app. Upload or record audio (or paste a YouTube link) and it turns speech into text with word-level timestamps using WhisperX, runs on your own server with no cloud transcription service, and lets you add notes, summaries and chat about a transcript through an OpenAI-compatible or Ollama model you connect.

## About Hosting Scriberr

This template runs one Scriberr v1.2.0 service built from a public GitHub repo, with a Railway volume at `/app/data` for the SQLite database, uploads, transcripts and downloaded models. The image ships a CPU build of WhisperX, so the app is ready seconds after the first start instead of installing several GB of GPU packages on boot. An admin account is created on first boot from generated variables, so nobody can claim your instance through the sign-up screen. Transcription is CPU-heavy: the web app runs in 0.5 GB, but a transcription job needs about 1.5 to 2 GB of RAM, so give the service 2 GB (Hobby plan or higher) for real work.

## Common Use Cases

* Transcribe meetings, interviews, lectures and voice notes privately, with timestamps you can click to replay
* Build searchable notes and AI summaries of recordings with your own LLM key
* Feed transcription into automations (n8n and others) through Scriberr's REST API and API keys

## Dependencies for Scriberr Hosting

* One Railway service built from `aalfath/scriberr-railway-template` (Scriberr v1.2.0 plus WhisperX v3.7.4 on CPU)
* One Railway volume at `/app/data` (database, uploads, transcripts, model cache)

### Deployment Dependencies

* Scriberr: https://github.com/rishikanthc/Scriberr (release v1.2.0)
* Scriberr docs: https://scriberr.app/docs/
* WhisperX: https://github.com/m-bain/whisperX
* Template repo: https://github.com/aalfath/scriberr-railway-template

### Implementation Details

**After deploy:** open the service's public URL and sign in as `admin` with the password in the service's `ADMIN_PASSWORD` variable (Variables tab). Change it under Settings if you like. Upload an audio file and press Transcribe. A default profile, "CPU - Whisper small (Int8)", is already selected. The first job downloads the Whisper, alignment and voice-detection models (about 1.3 GB) into the volume, so it takes a minute longer than later jobs.

**Memory:** the server idles at about 50 MB, but each WhisperX job on CPU needs about 1.5 GB (`small`, Int8, the template's default profile) to 2 GB (`small`, Float32). Tested on Railway: an 11-second clip finished in about 30 s on a 2 GB / 2 vCPU service with both settings. On a service with less than 1.4 GB of RAM (for example the Free plan's 0.5 GB), jobs fail at once with a clear "Not enough memory" message instead of being killed half-way, and the web app keeps running; raise the service's memory limit on the Hobby plan or higher. Larger models (`medium`, `large-v3`) need 3 to 6 GB and are slow on CPU.

**Not included:** Railway has no GPUs, so NVIDIA Parakeet, Canary and Sortformer models are switched off. Speaker labels (diarization) with pyannote need a free Hugging Face token entered in the transcription settings and about 3 GB of RAM. Summaries and chat need an OpenAI-compatible API key or an Ollama server, added under Settings, LLM.

**Variables:** `ADMIN_USERNAME` (default `admin`) and `ADMIN_PASSWORD` (generated) create the first account on first boot only.

**Updates:** the service builds from the template repo, so Railway shows an update notice when the repo moves to a new Scriberr release. Read the repo's CHANGELOG before you apply it. Your data stays on the volume.

## Why Deploy Scriberr on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Scriberr on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

## What's in this repo

| File | Purpose |
|---|---|
| `Dockerfile` | Copies the binaries from the official image `ghcr.io/rishikanthc/scriberr:v1.2.0@sha256:9e36448fb5a6003b28cd3d9ac783e8cbef5ed916936c20ec353a55fa380484f4` onto `python:3.11.14-slim-trixie` (pinned by digest) and installs WhisperX v3.7.4 (commit `617835dc`) from its own `uv.lock`, with PyTorch 2.8.0 CPU wheels |
| `railway-start.sh` | Fixes volume ownership, caps CPU threads to the service's limit, creates the admin account and a CPU-friendly default transcription profile on a loopback-only first start, then runs Scriberr as an unprivileged user. Exits non-zero on any failure so Railway restarts it |
| `uv-guard.sh` | Installed as `uv`: for transcription jobs it stops with a clear message when the service has less RAM than `SCRIBERR_MIN_MEMORY_MB` (default 1400; set 0 to disable), caps PyTorch threads to the service's CPU limit and turns off transparent huge pages |
| `CHANGELOG.md` | One entry per version, breaking changes first |

Railway service settings used by the template: health check `/health` (timeout 300 s), restart policy on failure, volume at `/app/data`, port 8080.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_USERNAME` | `admin` | First account, created on first boot only |
| `ADMIN_PASSWORD` | `${{secret(24)}}` | Generated; read it in the Variables tab |
| `PORT` | `8080` | Port Scriberr listens on |

Optional: `ALLOWED_ORIGINS` (CORS origins for other sites calling the API), `SCRIBERR_MIN_MEMORY_MB` (memory guard, above), `OPENAI_API_KEY` (lets the `openai_whisper` model transcribe through OpenAI's API), `LOG_LEVEL`.

## License

Scriberr is MIT licensed (c) Scriberr. WhisperX is BSD-2-Clause. This wrapper is MIT.
