# Deploy and Host Scriberr on Railway

Scriberr is an open-source, self-hosted audio transcription app. Upload or record audio (or paste a YouTube link) and it turns speech into text with word-level timestamps using WhisperX, runs on your own server with no cloud transcription service, and lets you add notes, summaries and chat about a transcript through an OpenAI-compatible or Ollama model you connect.

## About Hosting Scriberr

This template runs one Scriberr v1.2.0 service built from a public GitHub repo, with a Railway volume at `/app/data` for the SQLite database, uploads, transcripts and downloaded models. The image ships a CPU build of WhisperX, so the app is ready seconds after the first start instead of installing several GB of GPU packages on boot. An admin account is created on first boot from generated variables, so nobody can claim your instance through the sign-up screen. Transcription is CPU-heavy: the web app runs in 0.5 GB, but a transcription job needs about 1.5 to 2 GB of RAM, so use the Hobby plan or higher for real work.

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

**After deploy:** open the service's public URL and sign in as `admin` with the password in the service's `ADMIN_PASSWORD` variable (Variables tab). Change it under Settings if you like. Upload an audio file and press Transcribe. The first job downloads the chosen Whisper model (about 0.5 GB for `small`) into the volume, so it takes a minute longer than later jobs.

**Memory:** the server idles at about 50 MB, but each WhisperX job on CPU needs about 1.5 GB (`small`, Int8) to 2 GB (`small`, Float32, the default). On a service with less than 1.4 GB of RAM, jobs fail at once with a clear "Not enough memory" message instead of being killed half-way; raise the service's memory limit on the Hobby plan or higher. Larger models (`medium`, `large-v3`) need 3 to 6 GB and are slow on CPU. Picking Int8 in the transcription settings is the fastest and lightest choice.

**Not included:** Railway has no GPUs, so NVIDIA Parakeet, Canary and Sortformer models are switched off. Speaker labels (diarization) with pyannote need a free Hugging Face token entered in the transcription settings and about 3 GB of RAM. Summaries and chat need an OpenAI-compatible API key or an Ollama server, added under Settings, LLM.

**Variables:** `ADMIN_USERNAME` (default `admin`) and `ADMIN_PASSWORD` (generated) create the first account on first boot only.

**Updates:** the service builds from the template repo, so Railway shows an update notice when the repo moves to a new Scriberr release. Read the repo's CHANGELOG before you apply it. Your data stays on the volume.

## Why Deploy Scriberr on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Scriberr on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
