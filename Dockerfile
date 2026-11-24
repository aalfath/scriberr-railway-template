# Scriberr for Railway: the official Scriberr v1.2.0 binaries on a slim Python
# runtime, with a CPU-only WhisperX environment baked in at build time.
#
# Upstream's image installs CUDA PyTorch, NVIDIA NeMo and pyannote environments
# (several GB) on first boot, before the web server listens. Railway has no GPU,
# so this image ships a pinned CPU build of WhisperX instead and the server is
# ready seconds after start.

# Official upstream image, pinned by version and digest (binaries are copied out of it).
FROM ghcr.io/rishikanthc/scriberr:v1.2.0@sha256:9e36448fb5a6003b28cd3d9ac783e8cbef5ed916936c20ec353a55fa380484f4 AS scriberr

# Same Python minor version and Debian release as the upstream runtime stage.
FROM python:3.11.14-slim-trixie@sha256:c8271b1f627d0068857dce5b53e14a9558603b527e46f1f901722f935b786a39

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=scriberr /usr/local/bin/uv /usr/local/lib/uv-real
COPY --from=scriberr /usr/local/bin/yt-dlp /usr/local/bin/deno /usr/local/bin/
COPY uv-guard.sh /usr/local/bin/uv
COPY --from=scriberr /app/scriberr /app/scriberr
COPY --from=scriberr /app/bin/cli /app/bin/cli

# WhisperX v3.7.4 (the release Scriberr v1.2.0 was built against), installed from
# WhisperX's own uv.lock so every Python package is the exact tested version.
# Only PyTorch is swapped for its CPU build (no CUDA, nvidia-* or triton wheels).
ARG WHISPERX_REF=617835dc27ca8d6e92f9536f94a710e9d44f3903
RUN set -eux; \
    mkdir -p /opt/whisperx-env/WhisperX; cd /opt/whisperx-env/WhisperX; \
    curl -fsSL "https://codeload.github.com/m-bain/whisperX/tar.gz/${WHISPERX_REF}" | tar xz --strip-components=1; \
    export UV_PYTHON=/usr/local/bin/python3.11 UV_PYTHON_DOWNLOADS=never UV_LINK_MODE=copy UV_NO_CACHE=1; \
    uv export --frozen --no-dev --no-hashes --no-emit-project --format requirements-txt -o /tmp/req.txt; \
    sed -i -E -e 's/^(torch|torchaudio)==([0-9.]+)\+cu[0-9]+/\1==\2+cpu/' \
              -e '/^(nvidia-|triton==)/d' /tmp/req.txt; \
    grep -E '^(torch|torchaudio|lightning|pyannote-audio)==' /tmp/req.txt; \
    uv venv .venv; \
    uv pip install --python .venv/bin/python --index-strategy unsafe-best-match \
      --extra-index-url https://download.pytorch.org/whl/cpu -r /tmp/req.txt; \
    uv pip install --python .venv/bin/python --no-deps --compile-bytecode .; \
    rm -f /tmp/req.txt; \
    .venv/bin/python -c "import torch, faster_whisper, whisperx.asr, whisperx.alignment, whisperx.vads; assert not torch.cuda.is_available(); print('torch', torch.__version__)"; \
    chmod -R a+rX /opt/whisperx-env

RUN groupadd -g 1000 appuser && useradd -m -u 1000 -g 1000 appuser && mkdir -p /app/data

ENV PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=8080 \
    APP_ENV=production \
    DATABASE_PATH=/app/data/scriberr.db \
    UPLOAD_DIR=/app/data/uploads \
    TRANSCRIPTS_DIR=/app/data/transcripts \
    WHISPERX_ENV=/opt/whisperx-env \
    UV_CACHE_DIR=/tmp/uv-cache \
    UV_PYTHON_DOWNLOADS=never \
    UV_PYTHON=/opt/whisperx-env/WhisperX/.venv/bin/python \
    UV_FROZEN=1 \
    UV_NO_SYNC=1 \
    HF_HOME=/app/data/models/huggingface \
    TORCH_HOME=/app/data/models/torch \
    NLTK_DATA=/app/data/models/nltk \
    XDG_CACHE_HOME=/app/data/models/cache

COPY railway-start.sh /usr/local/bin/railway-start.sh
RUN chmod 755 /usr/local/bin/railway-start.sh /usr/local/bin/uv && uv --version

WORKDIR /app
EXPOSE 8080
CMD ["/usr/local/bin/railway-start.sh"]
