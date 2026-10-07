# Setup Repository

This repo contains setup guides and scripts for Vision Lab members to configure their computing environments.

## Project Status

We are building a comprehensive setup guide covering multiple environments (Harvard cluster, laptops, Lightning AI, lab workstations).

### Completed

- [x] Investigated Harvard cluster storage topology
- [x] uv cache + venvs moved to netscratch (2026-09-30; holylabs inode quota), hardlinks verified there
- [x] Tested uv project creation and package installation
- [x] Created Jupyter kernel spec for uv auto-detection
- [x] Draft guide started (see `docs/harvard-cluster.md`)
- [x] Organized repo structure (README, docs/, scripts/, templates/)
- [x] Created `templates/bashrc-additions.sh` - standard lab environment variables
- [x] Documented symlink strategy (`.cache`, `.conda` -> netscratch)
- [x] AWS/S3 setup section (awscli, s5cmd, fsspec, boto3)
- [x] S3 bucket mounting scripts (rclone FUSE)
- [x] SLURM job submission basics
- [x] Laptop setup guide (macOS) - see `docs/laptop-macos.md`
- [x] Create accounts guide - see `docs/create-accounts.md`
- [x] Getting cluster access guide - see `docs/getting-cluster-access.md`
- [x] Cluster usage guide - see `docs/cluster-usage.md`
- [x] Terminal & SSH setup guide - see `docs/terminal-ssh-setup.md`
- [x] Compute guidelines - see `docs/compute-guidelines.md`
- [x] Cluster reference (quotas, storage measurements, Kempner) - see `docs/cluster-reference.md`
- [x] `scripts/cluster/lab_env.sh` - source of truth for the deployed lab env (deployed 2026-10-07)
- [x] libjpeg-turbo build (alvarez_lab, 2026-09-30) and FFmpeg 7.1.3 build (alvarez_lab, 2026-10-07, job 51135227)
- [x] Lab-wide Claude skill `skills/fasrc-cluster/SKILL.md`

### TODO

#### Harvard Cluster Setup
- [ ] Module loading (if needed)
- [ ] Add screenshots to cluster-usage.md (user must extract from PDFs)
- [ ] Konkle lab: nothing built or deployed in konkle_lab space without Konkle's OK; questions in `docs/konkle-lab-notes.md`
- [ ] Test NVDEC decode with the lab FFmpeg on a GPU node

#### Other Environments
- [ ] Lightning AI setup guide
- [ ] Lab workstations (Lambda Labs GPUs) setup guide

## Key Findings

### Storage Topology (Harvard Cluster)

| Storage | Path | Characteristics | Use for |
|---------|------|-----------------|---------|
| Home | `~/` | 100GB limit, persistent | Config files, symlinks only |
| Holylabs | `/n/holylabs/LABS/${LAB}/Users/$USER/` | Persistent, **~1M-file group quota** (never raised) | Code only; no venvs/caches/conda |
| Netscratch | `/n/netscratch/${LAB}/Lab/$USER/` (`$LAB_SCRATCH`) | Free, large, fast, ephemeral | venvs, uv cache, scratch |
| Lab storage | `/n/lab_storage/${LAB}/Lab/` (`$LAB_STORAGE`) | Persistent, ~8TB, slow NFS (can't host venvs) | Datasets, lab software (`sw/`) |

Tier1 (`/n/alvarez_lab_tier1`) no longer exists; replaced by lab_storage.

**Critical:** Netscratch purges files unused for 90 days (touching to dodge it is forbidden). Never store irreplaceable data there; venvs rebuild with `uv sync --frozen`.

### Filesystem Boundaries

```
Device 43: /n/netscratch, /n/holylabs (same server, but hardlinks fail across them)
Device 57: /n/home02
lab_storage: separate NFS server (slow)
```

**Hardlinks work within a filesystem** — UV_CACHE_DIR and venvs are both on netscratch, so uv hard-links.

### uv Configuration

`~/.bashrc` sets `LAB` and sources `/n/holylabs/LABS/${LAB}/Lab/setup/lab_env.sh` (source: `scripts/cluster/lab_env.sh`;
deploy steps in `docs/cluster-reference.md` §2; never edit the deployed copy). It sets the storage vars,
`UV_CACHE_DIR=$LAB_SCRATCH/uv-cache`, `TURBOJPEG_ROOT`, `FFMPEG_ROOT` (+PATH/LD_LIBRARY_PATH), and wraps `uv` so a git
checkout on holylabs uses `$LAB_SCRATCH/venvs/<repo>` instead of `.venv` (`lab_venv` prints it).

### Jupyter Kernel

The "Python (uv auto)" kernel runs `uv run python -m ipykernel`, which auto-detects the project from the notebook's location. Projects need `ipykernel` as a dependency.

## File Structure

```
setup/
├── README.md                   # Repo overview and quick start
├── CLAUDE.md                   # This file (project tracking)
├── docs/
│   ├── project-management.md      # Project management overview
│   ├── create-accounts.md         # GitHub, FASRC, AWS account setup
│   ├── laptop-macos.md            # macOS laptop setup guide
│   ├── getting-cluster-access.md  # VPN, 2FA, SSH verification
│   ├── harvard-cluster.md         # Cluster environment configuration
│   ├── cluster-usage.md           # Day-to-day cluster usage
│   ├── terminal-ssh-setup.md      # Advanced SSH configuration
│   ├── compute-guidelines.md      # Lab policies and best practices
│   ├── cluster-reference.md       # Quotas, storage measurements, lab_env deploy, Kempner
│   ├── konkle-lab-notes.md        # Pending questions for Konkle lab
│   ├── changelog.md               # Migration steps for existing users
│   └── slurm-basics.md            # SLURM job submission
├── scripts/
│   ├── s3_bucket_mount.sh      # Mount S3 bucket via rclone FUSE
│   ├── s3_bucket_unmount.sh    # Unmount S3 bucket
│   ├── s3_zombie_sweep.sh      # Clean up orphaned mounts
│   └── cluster/
│       ├── lab_env.sh               # Deployed to /n/holylabs/LABS/<lab>/Lab/setup/
│       ├── build_libjpeg_turbo.sh   # sbatch: lab libjpeg-turbo (slipstream)
│       └── build_ffmpeg.sh          # sbatch: lab FFmpeg (torchcodec)
├── skills/
│   └── fasrc-cluster/SKILL.md  # Lab-wide Claude Code skill (symlink into ~/.claude/skills)
└── templates/
    └── bashrc-additions.sh     # Standard bashrc additions template
```

Future additions:
- `docs/lightning-ai.md` - Lightning AI setup
- `docs/lab-workstations.md` - Lambda Labs workstations

## Lab Affiliation

The `LAB` environment variable should be set to the user's primary advisor's lab:
- `alvarez_lab`
- `konkle_lab`

This determines paths for holylabs, netscratch and lab_storage. Everything so far is built/tested for alvarez_lab only.

## Conventions

- All paths should use `${LAB}` variable where appropriate
- Scripts should be idempotent (safe to run multiple times)
- Guides should include verification steps
- Cluster changes: edit here, push, `git pull` in `$PROJECT_DIR/setup-guide` on the cluster, then deploy/run from there
- sbatch scripts: request only the cores used in parallel (Job Defense Shield flags idle `shared` cores)
- Keep instructions copy-pasteable where possible
