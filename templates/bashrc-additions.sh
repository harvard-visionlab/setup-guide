# ==============================================================================
# Vision Lab Configuration
# ==============================================================================

# Lab affiliation - determines storage paths
# Set to your primary advisor's lab: alvarez_lab or konkle_lab
export LAB=alvarez_lab

# Lab environment: storage paths (MY_WORK_DIR, LAB_SCRATCH, LAB_STORAGE, PROJECT_DIR, ...), uv cache and
# venv location, TURBOJPEG_ROOT. Shared by the whole lab; source: setup-guide scripts/cluster/lab_env.sh
[ -f /n/holylabs/LABS/${LAB}/Lab/setup/lab_env.sh ] && . /n/holylabs/LABS/${LAB}/Lab/setup/lab_env.sh

# AWS configuration
# Ask George to send you your credentials; keep these secret always, never commit to any public repo.
# Bots crawl and find exposed credentials - it will cost you tens of thousands of dollars
# and could bork the entire lab infrastructure.
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION=us-east-1

# Convenience aliases (optional - uncomment if desired)
# alias cdw='cd $MY_WORK_DIR'
# alias cdn='cd $LAB_SCRATCH'
# alias cdl='cd $LAB_STORAGE'
# alias cdp='cd $PROJECT_DIR'
# alias cdb='cd $BUCKET_DIR'
# alias cds='cd $SANDBOX_DIR'

# Default working directory for interactive shells (e.g., Jupyter terminals)
if [[ $- == *i* ]]; then
    if [[ -n "${MY_WORK_DIR}" && -d "${MY_WORK_DIR}" ]]; then
        cd "${MY_WORK_DIR}"
    else
        cd "$HOME"
    fi
fi
