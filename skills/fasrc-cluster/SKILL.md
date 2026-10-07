---
name: fasrc-cluster
description: How to reach and use the Harvard FASRC cluster (Cannon, Kempner partitions) from a lab laptop. Covers ssh through a 2FA-authenticated persistent connection, what may and may not run on the login node, storage tiers (holylabs, netscratch, lab_storage, $HOME) with their quotas and purge rules, lab_env.sh, partitions and accounts, submitting jobs by piping scripts to sbatch, watching jobs and getting into a running job's node, and pitfalls. Use whenever a task touches the cluster (FASRC, Cannon, Kempner, SLURM, sbatch, holylabs, netscratch, lab_storage, "on the cluster", "login node").
---

# FASRC cluster (Cannon / Kempner) from a lab laptop

Vision Lab skill. Source of truth: `harvard-visionlab/setup-guide` (`skills/fasrc-cluster/SKILL.md`); background and
measurements in its `docs/cluster-reference.md`. Read that before changing anything cluster-wide.

`$LAB` below is the user's lab (`alvarez_lab` or `konkle_lab`). Ask if unknown.

## 1. Connecting

- The user's `~/.ssh/config` has a host alias for the login node (setup-guide `docs/terminal-ssh-setup.md` uses
  `holylogin`) with `ControlMaster auto`. The user opens it once interactively (password + 2FA); while that master
  connection lives (keep the terminal open, or `ControlPersist` in the config), `ssh <alias>` needs no 2FA.
- Always run `ssh -o BatchMode=yes -o ConnectTimeout=15 <alias> '<cmd>'`. If it fails or hangs, the master connection
  is down. Stop and ask the user to reconnect (e.g. `! ssh holylogin` in another terminal). Don't retry in a loop.
- **Compute nodes:** `ssh <node>` from the login node works only while you have a job there. Always works:
  `srun --jobid=<id> --overlap --ntasks=1 <cmd>` (runs inside the allocation, sees its GPUs and CPUs).
- Move code by **git only**: commit and push on the laptop, `git pull` in the cluster checkout. Exception: scratch
  scripts piped to sbatch.

## 2. The login node is shared: light work only

OK there: editing, git, `squeue`/`sacct`/`sbatch`, reading logs, `ls`, small `python3 -c` checks.
**Never** there: `uv sync`/installs, test suites, data copies or syncs, hashing, `du`/`find` over lab dirs (a `du` of
a datasets dir ran > 60 s), benchmarks, training. Submit a job instead (`shared` or `test` start fast).

## 3. Storage

| what | where | notes |
|---|---|---|
| code checkouts | `$PROJECT_DIR` = `/n/holylabs/LABS/$LAB/Users/$USER/Projects` | group **inode** quota (~1M files per lab, never raised): no venvs, caches, conda envs or many-small-file outputs here |
| venvs, uv cache, run dirs, build logs | `$LAB_SCRATCH` = `/n/netscratch/$LAB/Lab/$USER` | fast VAST; 50 TB per lab; **purged by mtime after 90 days**, and touching files to dodge that is forbidden. Rebuild instead (`uv sync --frozen`) |
| datasets, lab software | `$LAB_STORAGE` = `/n/lab_storage/$LAB/Lab` | durable NFS but slow: ~50 MB/s per stream, ~115 MB/s max; can't host venvs |
| outputs (weights, results) | S3 (`s3://visionlab-members/$USER/...`) | from the cluster ~15-50 MB/s; use `s5cmd` |
| home | `$HOME` | 100 GB, slow; config only |

- Node-local `/tmp` (400 GB-6.9 TB on Kempner nodes) is per job and wiped after.
- `lfs quota` doesn't work (holylabs/netscratch are NFS exports now); the inode quota isn't visible from the CLI.
  `Disk quota exceeded` on holylabs means the lab's file count, not bytes.

## 4. Shell environment: `lab_env.sh`

`/n/holylabs/LABS/$LAB/Lab/setup/lab_env.sh` (sourced from `~/.bashrc` after `export LAB=...`) sets the storage vars
above, `UV_CACHE_DIR=$LAB_SCRATCH/uv-cache`, `TURBOJPEG_ROOT` (if the lab built libjpeg-turbo), and wraps `uv` so
that inside any git checkout on holylabs the venv is `$LAB_SCRATCH/venvs/<repo name>` (not `.venv`). `lab_venv`
prints that path (for VS Code / Jupyter). An explicit `UV_PROJECT_ENVIRONMENT` wins.

- Non-interactive ssh and jobs may not read `.bashrc`: **source it explicitly** in every job script and remote
  command: `export LAB=<lab>; . /n/holylabs/LABS/$LAB/Lab/setup/lab_env.sh`. It is `set -eu` safe.
- Never edit the deployed copy. Edit `scripts/cluster/lab_env.sh` in setup-guide, commit, then redeploy (backup
  first; the whole lab sources it): see setup-guide `docs/cluster-reference.md`.

## 5. Partitions and accounts

- Check access: `sacctmgr -nP show assoc user=$USER format=account`. Unix group membership is not enough: a Kempner
  account works only with a SLURM association.
- `shared`: CPU jobs (syncs, builds, scans); starts fast. `test`: 12 h, near-immediate. `gpu_test`: MIG slices,
  smoke tests, 12 h.
- Kempner (`--account=kempner_$LAB`, e.g. `kempner_alvarez_lab`), 2-day limit each, 4 GPUs/node unless noted:
  `kempner` (A100 40GB, 16 cores/GPU), `kempner_h100` (H100 80GB, 24 cores/GPU), `kempner_h200` (H200, 16 cores/GPU),
  `kempner_rtx` (8x RTX PRO 6000 96GB), `kempner_interactive` (A100 MIG, 8 h).
  `kempner_requeue` is preemptible (SIGTERM + requeue): OK for short checkpointed 1-GPU jobs, not long training.
- Caps: 16 GPUs per user, 96 per account. Multi-partition `-p a,b` is forbidden on Kempner.
- Ask for time proportional to the job (expected x 1.25 + 30 min): shorter requests schedule sooner.

## 6. Submitting jobs: the pattern that works

Pipe the script to sbatch so nothing is copied into a repo. Give `--output` as an absolute path:
```bash
cat <<'EOF' | ssh -o BatchMode=yes <alias> 'mkdir -p /n/netscratch/<lab>/Lab/$USER/logs && sbatch --parsable'
#!/bin/bash
#SBATCH --job-name=<name>
#SBATCH --partition=shared
#SBATCH --cpus-per-task=1      # more only for code that runs in parallel (see below)
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=/n/netscratch/<lab>/Lab/<user>/logs/<name>-%j.out
set -eo pipefail
export LAB=<lab>; . /n/holylabs/LABS/$LAB/Lab/setup/lab_env.sh
cd $PROJECT_DIR/<repo> && git pull -q --ff-only
uv sync --frozen        # repairs a venv the netscratch purge ate; no-op otherwise
uv run python ...
EOF
```
- **Decide the core count per job, before submitting: what in this script runs in parallel?** Request that many
  cores, no more. FASRC's Job Defense Shield emails the PI about `shared` jobs whose CPU use is about
  100% / cores (a 16-core hashing job that used 5% got flagged).
  - **I/O-bound or serial: 1-2 cores.** Syncs, copies, hashing and verify loops, `du`/inode scans, `uv`/`git` steps.
    Measured: such jobs used 0.4-5.6% of 8-16 cores; they wait on lab_storage/netscratch, so more cores can't help
    (more parallel streams might, e.g. s5cmd `--numworkers`).
  - **Really parallel: N cores** where N matches the workers: test suites run with N workers, native builds with
    `make -j N`, s5cmd or xargs `-P N`.
  - Memory is requested separately (`--mem`); extra memory needs no extra cores.
  - GPU jobs: cores come with the GPUs (e.g. 24 per H100, used by data loaders). The emails are about `shared`.
  - **After a new kind of job's first run, check `jobstats <id>`** (or `sacct -j <id> -o Elapsed,TotalCPU`; with
    `-u`/date ranges, sum TotalCPU over the job's steps, as the allocation line shows 0) and size the next one from it.
- Quote the heredoc (`<<'EOF'`) so `$VARS` expand on the cluster, not the laptop. `#SBATCH` lines don't expand
  variables: use literal paths.
- Chain dependent work with `--dependency=afterok:<id>` (`afterany` to run regardless). Change a queued job with
  `scontrol update JobId=<id> Dependency=afterany:<id>`.
- **Never let two jobs `uv sync` the same venv (or share a uv cache) at once** on NFS: chain them. For one-off
  package versions, make a separate venv: `uv venv $LAB_SCRATCH/venvs/<name>; VIRTUAL_ENV=... uv pip install ...`.
- `uv run` can hang on a file lock on the login node (NFS locking). In jobs, `uv sync --frozen` first, or call
  `$(lab_venv)/bin/<tool>` directly.
- uv caches git checkouts of git dependencies: a native extension built once is not rebuilt when its build env
  changes. Check with `ldd <ext>.so`; fix by deleting the checkout under `$UV_CACHE_DIR/git-v0/checkouts/`.

## 7. Watching jobs

- State: `sacct -j <id> -X -n -o State,Elapsed`. Queue: `squeue -u $USER`. (`sacct` rejects wide date ranges at FASRC.)
- Logs: `tail`/`grep` the `--output` file. Filter tqdm redraws with `tr "\r" "\n" | tail`.
- Inside a running job: `srun --jobid=<id> --overlap --ntasks=1 bash -c 'top -b -n1 | head; nvidia-smi'`, or
  `ssh <node>`. CPU near zero plus a thread in state D means blocked on I/O.
- From Claude: wait with one background loop, `until sacct -j <id> -X -n -o State | grep -qE
  'COMPLETED|FAILED|CANCELLED|TIMEOUT|OUT_OF_ME|NODE_FAIL'; do sleep 60; done`, or a Monitor that greps the log for
  progress **and** failure patterns.
- Cancel: `scancel <id>`. Failure within seconds plus an empty log usually means the script died before printing
  (e.g. under `set -e`); reproduce the first lines on the login node.

## 8. Pitfalls seen

- macOS has no `timeout`; use ssh `-o ConnectTimeout` and the tool timeout.
- Benchmarks: a second read of a file on the same node comes from the page cache (fake GB/s). Use different files or
  a fresh node for each measurement.
- `SLURM_STEP_ID` is `-5` in a batch script and `>= 0` inside `srun` steps.
- slipstream (>= 0.9.2) needs `TURBOJPEG_ROOT` at install: source `lab_env.sh` before `uv sync`.
