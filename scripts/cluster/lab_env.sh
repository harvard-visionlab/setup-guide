# Vision Lab shell setup for the FASRC cluster. Source of truth: harvard-visionlab/setup-guide
# scripts/cluster/lab_env.sh; deployed to /n/holylabs/LABS/<lab>/Lab/setup/lab_env.sh (see docs/cluster-reference.md).
# Do not edit the deployed copy: edit here, commit, redeploy.
#
# Source from ~/.bashrc (and explicitly in job scripts / non-interactive ssh, which don't read .bashrc):
#     export LAB=alvarez_lab   # or konkle_lab
#     . /n/holylabs/LABS/$LAB/Lab/setup/lab_env.sh
#
# Why: holylabs has a group FILE quota (~1M inodes per lab, never raised). A single Python venv is 25-60k files,
# so venvs and the uv cache live on netscratch (fast, no small lab quota; files unused ~90 days are purged, and a
# venv rebuilds exactly from uv.lock with `uv sync --frozen`). Code stays on holylabs.
# Safe under `set -e` / `set -u`. Per-user scratch is $MY_NETSCRATCH ($LAB_SCRATCH is the old name).

export LAB="${LAB:-alvarez_lab}"

# Storage roots
export MY_WORK_DIR="/n/holylabs/LABS/$LAB/Users/$USER"   # code (inode quota: no venvs/caches here)
export MY_NETSCRATCH="/n/netscratch/$LAB/Lab/$USER"       # yours (per user): venvs, uv cache, run dirs, temp (90-day purge)
export LAB_SCRATCH="$MY_NETSCRATCH"                       # old name, same dir: kept for scripts that use it
export LAB_NETSCRATCH="/n/netscratch/$LAB/Everyone"       # lab-shared scratch (e.g. ~/.lightning)
export LAB_STORAGE="/n/lab_storage/$LAB/Lab"              # durable lab NFS (datasets, lab software); slow

# Holylabs folder structure
export PROJECT_DIR="$MY_WORK_DIR/Projects"   # git repos
export BUCKET_DIR="$MY_WORK_DIR/Buckets"     # S3 bucket mounts
export SANDBOX_DIR="$MY_WORK_DIR/Sandbox"    # testing/scratch

# uv
export UV_CACHE_DIR="$MY_NETSCRATCH/uv-cache"   # same filesystem as the venvs: uv hard-links, no copies
export UV_TOOL_DIR="$MY_WORK_DIR/.uv_tools"   # a few small CLI tools (s5cmd); must survive the purge

# Venv of the git checkout containing the current dir: $MY_NETSCRATCH/venvs/<repo name> for checkouts on holylabs,
# <repo>/.venv elsewhere. An explicit UV_PROJECT_ENVIRONMENT wins. Two checkouts of one repo name share that venv.
_lab_venv_for() {  # <checkout top>
  if [ -n "${UV_PROJECT_ENVIRONMENT:-}" ]; then echo "$UV_PROJECT_ENVIRONMENT"; return; fi
  case "$(readlink -f "$1" 2>/dev/null)" in
    /n/holylabs/*) echo "$MY_NETSCRATCH/venvs/$(basename "$1")" ;;
    *) echo "$1/.venv" ;;
  esac
}

# `uv` inside a git checkout on holylabs uses $MY_NETSCRATCH/venvs/<repo name> instead of <repo>/.venv.
# (Elsewhere uv keeps its default, the project's .venv.)
uv() {
  local top
  if [ -z "${UV_PROJECT_ENVIRONMENT:-}" ] && top=$(git rev-parse --show-toplevel 2>/dev/null); then
    case "$(readlink -f "$top" 2>/dev/null)" in
      /n/holylabs/*)
        UV_PROJECT_ENVIRONMENT="$(_lab_venv_for "$top")" command uv "$@"
        return ;;
    esac
  fi
  command uv "$@"
}

# `lab_venv`: print the venv the current checkout uses (for VS Code / Jupyter kernel paths).
lab_venv() {
  local top; top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git checkout" >&2; return 1; }
  _lab_venv_for "$top"
}

# `mr` (model-rearing CLI): the current checkout's own mr (each lab project venv has model-rearing plus its plugins);
# outside a checkout, model-rearing's venv. Runs the venv's binary directly: no uv, so no sync or install, and no
# NFS lock hang on the login node. Replaces `alias mr=...` (remove that alias: an alias overrides this function).
function mr {
  local top venv
  if top=$(git rev-parse --show-toplevel 2>/dev/null); then
    venv=$(_lab_venv_for "$top")
    [ -x "$venv/bin/mr" ] || { echo "mr: no $venv/bin/mr (run 'uv sync' for $(basename "$top") in a job)" >&2; return 127; }
  else
    venv="$MY_NETSCRATCH/venvs/model-rearing"
    [ -x "$venv/bin/mr" ] || { echo "mr: not in a git checkout, and no $venv/bin/mr" >&2; return 127; }
  fi
  "$venv/bin/mr" "$@"
}

# Lab-wide libjpeg-turbo with SIMD (TurboJPEG API) for slipstream's JPEG decoder: building slipstream (uv sync)
# needs it. Never move this prefix: the decoder is rpath-linked to it. Built by scripts/cluster/build_libjpeg_turbo.sh.
if [ -d "$LAB_STORAGE/sw/libjpeg-turbo-3.0.4" ]; then
  export TURBOJPEG_ROOT="$LAB_STORAGE/sw/libjpeg-turbo-3.0.4"
fi

# Lab-wide FFmpeg (shared libs, libx264/libx265, NVDEC) for torchcodec and video encoding. torchcodec dlopens
# libavutil.so.N etc. by soname, hence LD_LIBRARY_PATH. Built by scripts/cluster/build_ffmpeg.sh; never move it.
if [ -d "$LAB_STORAGE/sw/ffmpeg-7.1.3" ]; then
  export FFMPEG_ROOT="$LAB_STORAGE/sw/ffmpeg-7.1.3"
  case ":$PATH:" in *":$FFMPEG_ROOT/bin:"*) ;; *) export PATH="$FFMPEG_ROOT/bin:$PATH" ;; esac
  case ":${LD_LIBRARY_PATH:-}:" in
    *":$FFMPEG_ROOT/lib:"*) ;;
    *) export LD_LIBRARY_PATH="$FFMPEG_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
  esac
fi
