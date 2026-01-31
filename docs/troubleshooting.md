# Troubleshooting

Known issues and fixes for the lab's compute environments.

## Cluster: `~/.bashrc` Not Sourced in JupyterLab Terminals

**Symptoms:**
- Terminal starts with a generic prompt (e.g., `-sh` or `sh-4.2$`)
- Environment variables are missing (`echo $LAB` returns empty)
- Conda/Mamba environments are unavailable

**Cause:** A JupyterLab update defaulted the shell to `/bin/sh`, which ignores `~/.bashrc`.

**Status:** Observed after a cluster JupyterLab update. May not affect all users. Needs further testing.

### Fix

#### 1. Force Bash via `~/.profile`

The default `sh` shell reads `~/.profile` (but ignores `~/.bashrc`). We use this to force a switch to Bash.

Create or edit `~/.profile`:

```bash
nano ~/.profile
```

Add:

```bash
# Force switch to bash for interactive sessions
if [ -z "$BASH_VERSION" ]; then
    export SHELL=/bin/bash
    exec /bin/bash --login
fi
```

#### 2. Bridge `~/.bash_profile` to `~/.bashrc`

Ensure your config loads regardless of whether the shell starts as "login" or "interactive."

Create or edit `~/.bash_profile`:

```bash
nano ~/.bash_profile
```

Add:

```bash
# Load your main bashrc settings
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Load cluster modules once per session
module load gcc/9.5.0-fasrc01  # Or your lab's preferred GCC version
```

#### 3. Optimized `~/.bashrc` for Speed

Network-mounted home directories can make terminal startup feel slow. This structure prioritizes fast string exports and moves heavy initialization to manual triggers.

```bash
# 1. Standard Global Definitions
if [ -f /etc/bashrc ]; then . /etc/bashrc; fi

# 2. Lab Storage Paths (Fast)
export LAB=alvarez_lab
export MY_WORK_DIR=/n/holylabs/LABS/${LAB}/Users/$USER
export PROJECT_DIR=${MY_WORK_DIR}/Projects
export UV_CACHE_DIR=${MY_WORK_DIR}/.uv_cache

# 3. Secure Credential Handling
# DO NOT 'export WANDB_API_KEY' here.
# Run 'wandb login' once in the terminal instead.

# 4. Conda/Mamba "Lazy Loader" (Prevents startup lag)
# Instead of initializing conda every time, use an alias:
alias load_conda='eval "$(/n/sw/eb/apps/centos7/Mamba/4.14.0-0/bin/conda shell.bash hook)"'

# 5. Path Management
export PATH="$HOME/local/bin:$HOME/bin:$PATH"
```

### How It Works

| File | Role |
|------|------|
| `~/.profile` | "First responder" — catches the default `sh` and swaps it for Bash |
| `~/.bashrc` | "Engine room" — contains your variables and aliases |
| `~/.bash_profile` | "Bridge" — ensures Bash reads your `.bashrc` even in login mode |

### Verifying the Fix

```bash
# Should say /bin/bash (not /bin/sh)
echo $0

# Should show your lab variables
echo $LAB
echo $MY_WORK_DIR
```

If `echo $0` still says `/bin/sh`, check `~/.profile`.

If `source ~/.bashrc` fixes your prompt but it doesn't persist, the bridge in step 2 is missing.
