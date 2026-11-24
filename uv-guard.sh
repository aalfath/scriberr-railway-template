#!/bin/bash
# Wrapper around uv (installed as /usr/local/bin/uv; the real binary is /usr/local/lib/uv-real).
# Scriberr starts every transcription as `uv run ... python -m whisperx ...`. On CPU a WhisperX
# job needs about 1.5 GB (small model, int8) to 2.1 GB (small model, float32: the default) of
# RAM, so on a smaller service the kernel would kill it half-way. Fail fast with a clear
# message instead. Set SCRIBERR_MIN_MEMORY_MB=0 to turn the check off.
REAL=/usr/local/lib/uv-real
is_job=0
prev=""
for a in "$@"; do
  if [ "$prev" = "-m" ] && [ "$a" = "whisperx" ]; then is_job=1; break; fi
  prev="$a"
done
if [ "$is_job" = 1 ]; then
  min_mb="${SCRIBERR_MIN_MEMORY_MB:-1400}"
  lim=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
  if [ "$min_mb" -gt 0 ] 2>/dev/null && [ "$lim" != "max" ] && [ -n "$lim" ]; then
    lim_mb=$(( lim / 1048576 ))
    if [ "$lim_mb" -lt "$min_mb" ]; then
      echo "Not enough memory for transcription: this service has ${lim_mb} MB RAM, and a WhisperX job on CPU needs about 1.5-2 GB (2 GB+ recommended; more for medium/large models)." >&2
      echo "Raise the service's memory limit in Railway (Hobby plan or higher), then start the job again." >&2
      exit 1
    fi
  fi
fi
exec "$REAL" "$@"
