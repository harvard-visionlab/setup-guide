# Changelog

Updates to the setup guides. If you've already completed setup, check here for changes you may need to apply.

---

## 2026-09-30: Python environments move to netscratch; `lab_env.sh`

### What Changed

1. **Python environments (venvs) and the uv cache now live on netscratch**, not holylabs:
   `/n/netscratch/${LAB}/Lab/$USER/venvs/<repo>` and `.../uv-cache`. Your code stays on holylabs.
2. **New shared `lab_env.sh`**, sourced from `~/.bashrc`. It sets all the lab storage variables, the uv cache, and
   makes `uv` put each repo's environment on netscratch automatically. It replaces most of the old bashrc block.
3. **Personal netscratch moved** from `/n/netscratch/${LAB}/Everyone/$USER` to `/n/netscratch/${LAB}/Lab/$USER`
   (`$LAB_SCRATCH`; `$MY_NETSCRATCH` now points there too).
4. **Tier1 is gone**: `LAB_TIER1` is replaced by `LAB_STORAGE=/n/lab_storage/${LAB}/Lab`.
5. Netscratch purges files **unused for 90 days** (not "monthly"). Rebuild environments with `uv sync --frozen`.

### Why

Holylabs limits the **number of files** each lab can own (~1M, never raised). Python environments are 25-60k files
each; in September 2026 they were ~700k of the lab's 1.17M files and installs started failing with
`Disk quota exceeded` for everyone. Details: [Cluster Reference](cluster-reference.md).

### How to Update

Do this in a JupyterLab terminal or interactive job, not on a login node.

#### 1. Replace the lab block in `~/.bashrc`

Delete the old `MY_WORK_DIR` ... `UV_TOOL_DIR` lines (storage roots, folder structure, uv) and put this right after
`export LAB=...`:

```bash
[ -f /n/holylabs/LABS/${LAB}/Lab/setup/lab_env.sh ] && . /n/holylabs/LABS/${LAB}/Lab/setup/lab_env.sh
```

Keep `LAB`, your AWS lines and the `cd` block. The full template: [templates/bashrc-additions.sh](../templates/bashrc-additions.sh).
Then `source ~/.bashrc` and check: `echo $LAB_SCRATCH $UV_CACHE_DIR`.

#### 2. Delete old environments and cache from holylabs

```bash
# list them first
find $MY_WORK_DIR -maxdepth 4 -type d -name .venv -prune
ls -d $MY_WORK_DIR/.uv_cache
# then delete (they rebuild from uv.lock)
find $MY_WORK_DIR -maxdepth 4 -type d -name .venv -prune -exec rm -rf {} +
rm -rf $MY_WORK_DIR/.uv_cache
```

Conda environments on holylabs count too: export them (`conda env export -n <env> > env.yml`) and remove them.

#### 3. Rebuild each project's environment

```bash
cd $PROJECT_DIR/<repo>
uv sync
lab_venv    # shows where the environment now lives
```

Point VS Code / Jupyter interpreters at `$(lab_venv)/bin/python` if you had set `.venv` explicitly. The
"Python (uv auto)" Jupyter kernel needs no change.

#### 4. Move anything you want to keep from your old netscratch dir

```bash
ls /n/netscratch/${LAB}/Everyone/$USER
mkdir -p $LAB_SCRATCH && mv /n/netscratch/${LAB}/Everyone/$USER/* $LAB_SCRATCH/
```

If you had `~/.cache` or `~/.conda` symlinked to the old netscratch dir or tier1, relink them to `$LAB_SCRATCH`
([guide](harvard-cluster.md#4-set-up-home-directory-symlinks)). `~/.lightning` stays on `$LAB_NETSCRATCH`.

---

## 2025-01-17: Environment Variable Updates

### What Changed

1. **`TIER1` renamed to `LAB_TIER1`** - Clearer naming convention
2. **New `LAB_NETSCRATCH` variable** - Shared lab netscratch for litdata caches
3. **`AWS_REGION` renamed to `AWS_DEFAULT_REGION`** - Better AWS CLI compatibility
4. **`.lightning` symlink now points to shared location** - All lab members share cached datasets

### Why

- `LAB_NETSCRATCH` allows all lab members to share the same StreamingDataset caches (litdata), avoiding duplicate downloads of the same datasets
- Consistent naming: `LAB_*` for shared lab resources, `MY_*` for personal directories
- `AWS_DEFAULT_REGION` is recognized by more AWS tools than `AWS_REGION`

### How to Update

If you've already set up your cluster environment, update your `~/.bashrc`:

#### 1. Update environment variables

Open your bashrc:

```bash
nano ~/.bashrc
```

Find and update the storage roots section:

**Before:**
```bash
export MY_WORK_DIR=/n/holylabs/LABS/${LAB}/Users/$USER
export MY_NETSCRATCH=/n/netscratch/${LAB}/Everyone/$USER
export TIER1=/n/alvarez_lab_tier1/Lab/
```

**After:**
```bash
export MY_WORK_DIR=/n/holylabs/LABS/${LAB}/Users/$USER
export MY_NETSCRATCH=/n/netscratch/${LAB}/Everyone/$USER
export LAB_NETSCRATCH=/n/netscratch/${LAB}/Everyone
export LAB_TIER1=/n/alvarez_lab_tier1/Lab/
```

Also update AWS region:

**Before:**
```bash
export AWS_REGION=us-east-1
```

**After:**
```bash
export AWS_DEFAULT_REGION=us-east-1
```

Save and reload:

```bash
source ~/.bashrc
```

#### 2. Update .lightning symlink

```bash
# Remove old symlink
rm ~/.lightning

# Create new symlink to shared lab location
mkdir -p $LAB_NETSCRATCH/.lightning
ln -s $LAB_NETSCRATCH/.lightning ~/.lightning
```

#### 3. Verify

```bash
# Check variables are set
echo "LAB_NETSCRATCH: $LAB_NETSCRATCH"
echo "LAB_TIER1: $LAB_TIER1"
echo "AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"

# Check symlink
ls -la ~/.lightning
# Should show: ~/.lightning -> /n/netscratch/<lab>/Everyone/.lightning
```

---
