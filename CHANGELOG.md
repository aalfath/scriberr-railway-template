# Changelog

## v1.2.0-railway.1 (2026-11-24)

First release of the Railway template.

- Scriberr v1.2.0 (official image `ghcr.io/rishikanthc/scriberr:v1.2.0@sha256:9e36448f…`), WhisperX v3.7.4 on CPU (PyTorch 2.8.0+cpu), Python 3.11.14.
- All state on the `/app/data` volume; Whisper models are cached there after the first job.
- Admin account created on first boot from `ADMIN_USERNAME` / `ADMIN_PASSWORD`.
- NVIDIA Parakeet, Canary and Sortformer (GPU models) are not installed.
