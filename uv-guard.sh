#!/bin/bash
# Wrapper around uv (installed as /usr/local/bin/uv; the real binary is /usr/local/lib/uv-real).
# Scriberr starts every transcription as `uv run ... python -m whisperx ...`. For those calls it:
#  - fails fast with a clear message when the service has too little RAM for a CPU WhisperX job
#    (the kernel would otherwise kill it half-way). SCRIBERR_MIN_MEMORY_MB=0 turns this off.
#  - replaces `--threads 0` (auto) with the service's CPU limit; Railway shows the host's CPUs.
#  - turns off transparent huge pages for the job (Railway hosts run THP "always", which adds
#    hundreds of MB to PyTorch's resident memory).
REAL=/usr/local/lib/uv-real
is_job=0
prev=""
for a in "$@"; do
  if [ "$prev" = "-m" ] && [ "$a" = "whisperx" ]; then is_job=1; break; fi
  prev="$a"
done
[ "$is_job" = 1 ] || exec "$REAL" "$@"

min_mb="${SCRIBERR_MIN_MEMORY_MB:-1400}"
lim=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
if [ "$min_mb" -gt 0 ] 2>/dev/null && [ "$lim" != "max" ] && [ -n "$lim" ]; then
  lim_mb=$(( lim / 1048576 ))
  if [ "$lim_mb" -lt "$min_mb" ]; then
    echo "Not enough memory for transcription: this service has ${lim_mb} MB RAM, and a WhisperX job on CPU needs about 1.5 GB (Int8) to 2.5 GB (Float32) with the small model." >&2
    echo "Raise the service's memory limit in Railway (Hobby plan or higher), then start the job again." >&2
    exit 1
  fi
fi

cpus="${OMP_NUM_THREADS:-1}"
args=()
prev=""
for a in "$@"; do
  if [ "$prev" = "--threads" ] && [ "$a" = "0" ]; then a="$cpus"; fi
  args+=("$a"); prev="$a"
done

# PR_SET_THP_DISABLE (41) is inherited by the child processes uv starts.
exec python3 -c 'import ctypes, os, sys
ctypes.CDLL(None, use_errno=True).prctl(41, 1, 0, 0, 0)
os.execv(sys.argv[1], sys.argv[1:])' "$REAL" "${args[@]}"
