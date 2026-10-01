# FASRC Cluster Reference

Background, measurements and maintenance notes behind the [cluster setup guide](harvard-cluster.md). Measured
2026-09-29/30 on FASRC `shared`-partition nodes (lab account) unless noted.

This repo is the source of truth for:

| file | deployed to / used as |
|---|---|
| [`scripts/cluster/lab_env.sh`](../scripts/cluster/lab_env.sh) | `/n/holylabs/LABS/<lab>/Lab/setup/lab_env.sh` |
| [`scripts/cluster/build_libjpeg_turbo.sh`](../scripts/cluster/build_libjpeg_turbo.sh) | sbatch script; builds `/n/lab_storage/<lab>/Lab/sw/libjpeg-turbo-<ver>` |
| [`skills/fasrc-cluster/SKILL.md`](../skills/fasrc-cluster/SKILL.md) | Claude Code skill (see [below](#claude-code-skill)) |

## 1. Where things live

| what | where | why |
|---|---|---|
| code checkouts | `$PROJECT_DIR` = `/n/holylabs/LABS/$LAB/Users/$USER/Projects` | durable, small |
| **Python venvs** | `$LAB_SCRATCH/venvs/<repo>` = `/n/netscratch/$LAB/Lab/$USER/venvs/<repo>` | holylabs **file** quota (below) |
| **uv cache** | `$LAB_SCRATCH/uv-cache` (`UV_CACHE_DIR`) | same filesystem as the venvs: uv hard-links (verified), so a venv costs no extra bytes or inodes |
| datasets, lab software | `$LAB_STORAGE` = `/n/lab_storage/$LAB/Lab` | durable lab storage (8 TB NFS; the old "tier1" moved here) |
| run dirs, logs, temp | `$LAB_SCRATCH` | fast scratch; final outputs go to S3 |
| lab shell setup | `/n/holylabs/LABS/$LAB/Lab/setup/lab_env.sh` | one file, sourced from `~/.bashrc` |

**The holylabs quota is on files (inodes), not bytes.** `alvarez_lab`: ~1.05M files (FASRC: "we do not increase
storage quota on holylabs"). It counts every file *owned by the group* on that filesystem, wherever it is.
2026-09-30 scan: 1.17M unique inodes, ~700k of them Python environments (each project `.venv` is 25-60k files; the
old holylabs uv cache 269k). A `uv sync` there failed with `Disk quota exceeded`; all holylabs `.venv`s and the old
cache were then deleted. Conda envs are just as bad (one was 50k files).

`lfs quota` no longer works: holylabs and netscratch are NFS exports of `netscratch-data01` (not Lustre), and the
file quota is not visible from the command line.

**netscratch vs lab_storage for venvs** (same fresh node, cold then warm):

| | netscratch | holylabs (old venv) | lab_storage |
|---|---|---|---|
| `import torch` cold / warm | 12.8 s / 3.1 s | 12.3 s / 2.7 s | uv could not even extract the CUDA wheels (I/O timeout) |

netscratch (VAST, 50 TB per lab) is as fast as holylabs, has no small lab quota, and suits many-small-file job I/O.
Its catch is the **purge of files unused for ~90 days**; touching files to dodge it is forbidden. A venv is rebuilt
exactly from `uv.lock`, so job scripts run `uv sync --frozen` first. A node-local copy of a venv is not worth it
(2 min to copy 7 GB for ~1 s saved). A university NVMe "compute" store is expected soon and may become the better
home for environments (change one line in `lab_env.sh`).

lab_storage is durable but slow: ~50 MB/s per stream, ~115 MB/s max. S3 from the cluster: ~15-50 MB/s.

## 2. `lab_env.sh`

Sets `LAB` (default `alvarez_lab`), the storage variables (`MY_WORK_DIR`, `LAB_SCRATCH`/`MY_NETSCRATCH`,
`LAB_NETSCRATCH`, `LAB_STORAGE`, `PROJECT_DIR`, `BUCKET_DIR`, `SANDBOX_DIR`), `UV_CACHE_DIR`, `UV_TOOL_DIR`,
`TURBOJPEG_ROOT` (if the lab's build exists), and wraps `uv` so that inside any git checkout on holylabs the venv is
`$LAB_SCRATCH/venvs/<repo name>` automatically. An explicit `UV_PROJECT_ENVIRONMENT` wins; two checkouts with one
repo name share a venv. `lab_venv` prints the path (for VS Code / Jupyter kernels). Tools that look for a literal
`.venv` need `uv run ...` or that path. Safe under `set -eu`.

Known issues:
- `uv run` can hang on a file lock on the login node (NFS locking). In jobs, `uv sync --frozen` first or call
  `$(lab_venv)/bin/<tool>` directly.
- Two processes sharing one uv cache on NFS can break a build ("Directory not empty" removing egg-info; `.nfs*`
  placeholders): don't run `uv sync` in parallel against the same cache.

### Deploying

Edit `scripts/cluster/lab_env.sh` here, commit and push. Then, on the cluster (the whole lab sources this file, so
keep a backup):

```bash
cd $PROJECT_DIR/setup-guide && git pull --ff-only
for lab in alvarez_lab konkle_lab; do
  f=/n/holylabs/LABS/$lab/Lab/setup/lab_env.sh
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] && cp -p "$f" "$f.bak-$(date +%Y%m%d-%H%M)"
  install -m 664 scripts/cluster/lab_env.sh "$f"
done
# check it sources cleanly under strict mode
for lab in alvarez_lab konkle_lab; do LAB=$lab bash -eu -c ". /n/holylabs/LABS/$lab/Lab/setup/lab_env.sh && echo $lab ok"; done
```

## 3. Login nodes vs jobs

Login nodes: editing, git, `squeue`/`sacct`/`sbatch`, reading logs, small checks. Everything else is a job:
`uv sync` of a new env, test suites, data syncs, scans (`find`/`du` over the lab dir), profiling, builds.

Partitions: `shared` (CPU jobs; starts quickly), `test` (12 h, near-immediate start), `gpu_test` (MIG slices, smoke
tests), Kempner partitions for training (section 5).

## 4. libjpeg-turbo (slipstream's JPEG decoder)

FASRC (Rocky 8) has libjpeg-turbo 1.5.3's classic `libjpeg.so.62` but **not** the TurboJPEG API
(`libturbojpeg.so`, `turbojpeg.h`) that slipstream's C++ decoder links. slipstream >= 0.9.2 fails the install
without it (earlier versions silently installed without the decoder) and searches `$TURBOJPEG_ROOT`, `$CONDA_PREFIX`
and `~/.local` (lib and lib64). No nasm module exists, so a plain cmake build has no SIMD (slow decode).

**Alvarez lab build** (2026-09-30, job 49429014, ctest 207/207): `/n/lab_storage/alvarez_lab/Lab/sw/libjpeg-turbo-3.0.4`
(`lib64/libturbojpeg.so.0`, `include/turbojpeg.h`, SIMD required; `BUILD_INFO` in the prefix). Konkle lab: not built
yet; lab_storage is group-only, so run the script with `LAB=konkle_lab`:

```bash
cd /n/netscratch/konkle_lab/Lab/$USER && LAB=konkle_lab sbatch $PROJECT_DIR/setup-guide/scripts/cluster/build_libjpeg_turbo.sh
```

The script builds nasm for the build only, uses `module load cmake/3.31.6-fasrc01`, and refuses to overwrite a
prefix. **The prefix must never move**: the decoder is rpath-linked to it. `lab_env.sh` sets `TURBOJPEG_ROOT` when
the prefix exists. No conda (the lab is uv-only).

Gotcha: slipstream builds its decoder inside its source tree, and uv caches git checkouts
(`$UV_CACHE_DIR/git-v0/checkouts/<hash>/<rev>`), so a rev built once never relinks (fixed in slipstream >= 0.9.3).
Check with `ldd <venv>/lib/python3.*/site-packages/libslipstream/_libslipstream*.so | grep turbojpeg`; fix by
deleting that checkout dir. The decoder's rpath lists `~/.local/lib{,64}` before the lab prefix: a stray
libturbojpeg there would win.

## 5. Kempner partitions (checked 2026-09-30)

Sources: [FASRC Kempner partitions](https://docs.rc.fas.harvard.edu/kb/kempner-partitions/),
[Kempner policies](https://handbook.eng.kempnerinstitute.harvard.edu/s1_high_performance_computing/kempner_cluster/kempner_policies_for_responsible_use.html),
[parallel I/O](https://handbook.eng.kempnerinstitute.harvard.edu/s5_ai_scaling_and_engineering/scalability/parallel_io.html).

| partition | GPU | GPUs/node | cores/node | RAM/node | max cores/GPU | max mem/GPU | node-local `/tmp` | limit |
|---|---|---|---|---|---|---|---|---|
| `kempner` | A100 40GB | 4 | 64 | 1 TB | 16 | 240 GB | ~400 GB | 2 d |
| `kempner_h100` | H100 80GB | 4 | 96 | 1.5 TB | 24 | 360 GB | ~840 GB | 2 d |
| `kempner_h200` | H200 141GB | 4 | 64 | 1.5 TB | 16 | 360 GB | ~840 GB | 2 d |
| `kempner_rtx` | RTX PRO 6000 96GB | 8 | 128 | 1.5 TB | 16 | 180 GB | ~6.9 TB | 2 d |
| `kempner_interactive` | A100 MIG 3g.20gb | | | | 8 | 120 GB | | 8 h |
| `kempner_requeue` | (under the above) | | | | | | | 2 d (`scontrol`; the handbook's 7 d is stale) |

- Accounts are fairshare pools `kempner_<lab>` (`kempner_alvarez_lab`, `kempner_konkle_lab`); fairshare affects
  priority only. Check yours: `sacctmgr -nP show assoc user=$USER format=account`. Being in the unix group is not
  enough: without a SLURM association the account is rejected (ask FASRC to add it).
- Caps: 16 GPUs per user, 96 per account at once. Multi-partition submission (`-p a,b`) is forbidden.
  Queue view: `showq -o -p kempner_h100`.
- `kempner_requeue` costs half the fairshare but is preemptible: SLURM sends SIGTERM and requeues the job. Whole-node
  jobs get preempted often; fine for short checkpointed 1-GPU jobs (probes, evals).
- Network: H100 is 2:1 oversubscribed; H200/RTX are non-blocking. Multi-node: `--constraint=holyndr` (400 Gb/s).
  Kempner recommends no `NCCL_*` settings; single-node jobs use NVLink.
- Kempner advises staging data reused every epoch onto node-local `/tmp`. For slipstream we don't: epoch 1 reads
  from lab_storage, later epochs from the OS page cache (1-1.5 TB RAM per node), which beats copying.
- Kempner's shared ImageNet (`kempner_shared/Everyone/testbed`) is Winter21, not ILSVRC-2012.

## 6. Other facts

- `SLURM_STEP_ID` is `-5` in a batch script and `>= 0` inside `srun` steps; `SLURM_STEP_NUM_TASKS` is the step's
  task count.
- `sacct` rejects wide date ranges at FASRC.

## Claude Code skill

[`skills/fasrc-cluster/SKILL.md`](../skills/fasrc-cluster/SKILL.md) teaches Claude Code how to use the cluster
(connecting, login-node rules, storage, jobs). Install it for all your projects by linking it into your user skills:

```bash
mkdir -p ~/.claude/skills
ln -s "$(pwd)/skills/fasrc-cluster" ~/.claude/skills/fasrc-cluster   # run from your setup-guide checkout
```

`git pull` in setup-guide then keeps it current. Project-specific skills (e.g. training launchers) should point to
this one rather than repeat it.
