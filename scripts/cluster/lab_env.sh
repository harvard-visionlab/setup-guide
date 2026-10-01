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
# Safe under `set -e` / `set -u`.

export LAB="${LAB:-alvarez_lab}"

# Storage roots
export MY_WORK_DIR="/n/holylabs/LABS/$LAB/Users/$USER"   # code (inode quota: no venvs/caches here)
export LAB_SCRATCH="/n/netscratch/$LAB/Lab/$USER"         # venvs, uv cache, run dirs, temp (90-day purge)
export MY_NETSCRATCH="$LAB_SCRATCH"                       # older name, same dir
export LAB_NETSCRATCH="/n/netscratch/$LAB/Everyone"       # lab-shared scratch (e.g. ~/.lightning)
export LAB_STORAGE="/n/lab_storage/$LAB/Lab"              # durable lab NFS (datasets, lab software); slow

# Holylabs folder structure
export PROJECT_DIR="$MY_WORK_DIR/Projects"   # git repos
export BUCKET_DIR="$MY_WORK_DIR/Buckets"     # S3 bucket mounts
export SANDBOX_DIR="$MY_WORK_DIR/Sandbox"    # testing/scratch

# uv
export UV_CACHE_DIR="$LAB_SCRATCH/uv-cache"   # same filesystem as the venvs: uv hard-links, no copies
export UV_TOOL_DIR="$MY_WORK_DIR/.uv_tools"   # a few small CLI tools (s5cmd); must survive the purge

# `uv` inside a git checkout on holylabs uses $LAB_SCRATCH/venvs/<repo name> instead of <repo>/.venv.
# (An explicit UV_PROJECT_ENVIRONMENT wins. Two checkouts of one repo name share that venv.)
uv() {
  if [ -z "${UV_PROJECT_ENVIRONMENT:-}" ]; then
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null) || top=""  # not in a checkout: fine under set -e
    case "$(readlink -f "${top:-/nonexistent}" 2>/dev/null)" in
      /n/holylabs/*)
        UV_PROJECT_ENVIRONMENT="$LAB_SCRATCH/venvs/$(basename "$top")" command uv "$@"
        return ;;
    esac
  fi
  command uv "$@"
}

# `lab_venv`: print the venv the current checkout uses (for VS Code / Jupyter kernel paths).
lab_venv() {
  local top; top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git checkout" >&2; return 1; }
  echo "${UV_PROJECT_ENVIRONMENT:-$LAB_SCRATCH/venvs/$(basename "$top")}"
}

# Lab-wide libjpeg-turbo with SIMD (TurboJPEG API) for slipstream's JPEG decoder: building slipstream (uv sync)
# needs it. Never move this prefix: the decoder is rpath-linked to it. Built by scripts/cluster/build_libjpeg_turbo.sh.
if [ -d "$LAB_STORAGE/sw/libjpeg-turbo-3.0.4" ]; then
  export TURBOJPEG_ROOT="$LAB_STORAGE/sw/libjpeg-turbo-3.0.4"
fi
