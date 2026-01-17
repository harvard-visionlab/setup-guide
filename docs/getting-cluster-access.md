# Getting Cluster Access

This guide walks you through the one-time setup to get access to the Harvard FASRC cluster.

## Overview

You'll need to:

1. Get an FASRC account
2. Set your password
3. Enable two-factor authentication (2FA)
4. Install VPN software
5. Verify SSH access
6. Submit your info to the lab

## 1. Get an FASRC Account

Request an account using the FASRC account request tool:

- **Direct link:** https://portal.rc.fas.harvard.edu/request/account/new
- **Official quickstart guide:** https://docs.rc.fas.harvard.edu/kb/quickstart-guide/

## 2. Set Your Password

Set your FASRC password (this is separate from your Harvard password):

https://portal.rc.fas.harvard.edu/p3/pwreset/

## 3. Enable Two-Factor Authentication

You can use the Duo Mobile app for 2FA:

1. Open Duo Mobile on your phone
2. Add a new service/account
3. Scan the QR code from the FASRC setup page

**Reference:** https://docs.rc.fas.harvard.edu/kb/duo-mobile/

> **Note:** The official instructions can be a bit circular. The key steps are: add a new service in Duo Mobile, then scan the QR code displayed on the FASRC website.

## 4. Install VPN Software

You must be connected to the VPN to access the cluster.

### Download Cisco AnyConnect

1. Search for "Harvard VPN" or go to https://vpn.harvard.edu
2. Sign in with your Harvard account
3. Download and install Cisco AnyConnect

> **Note:** You don't need to enable the extra privacy/telemetry options during installation.

### Connect to the VPN

1. Open Cisco AnyConnect
2. Enter the server address:
   ```
   vpn.rc.fas.harvard.edu
   ```
3. Login with your FASRC credentials:
   - **Username:** `yourusername@fasrc` (note the `@fasrc` suffix)
   - **Password:** Your FASRC password
   - **Second authentication:** 6-digit code from Duo Mobile

**Reference:** https://docs.rc.fas.harvard.edu/kb/vpn-setup/

> **Troubleshooting:** If login fails, verify your credentials at https://portal.rc.fas.harvard.edu/

## 5. Verify SSH Access

With the VPN connected, verify you can SSH into the cluster.

Open a terminal and run:

```bash
ssh <your-username>@login.rc.fas.harvard.edu
```

Enter your FASRC password when prompted, then your 2FA code.

> **Important:** This logs you into a shared login node. Don't run heavy computations here—it's only for light tasks and launching jobs.

### Verify Your Username

Once logged in, confirm your username:

```bash
echo $USER
```

This should match your FASRC username. If it differs, note this username for the lab info form.

### Check Your SLURM Accounts

See which accounts you have access to:

```bash
sacctmgr show assoc user=$USER format=account%30
```

Save this output—you'll need it for the lab info form.

## 6. Submit Your Info to the Lab

Once you've verified access, fill out the lab information form with:

- Your FASRC username (from `echo $USER`)
- Your SLURM accounts (from `sacctmgr show assoc`)
- Your GitHub username (create an account at github.com if needed)

Submit this information to George.

## 7. Test Interactive Access (Optional)

Verify you can launch an interactive session:

1. Go to https://rcood.rc.fas.harvard.edu/pun/sys/dashboard
2. Login with:
   - **Username:** Your FASRC username (without `@fasrc`)
   - **Password:** Your FASRC password
3. Under Interactive Apps, click "Jupyter notebook / Jupyterlab"
4. Try launching a session on the `gpu_test` partition

If the session launches successfully, your access is fully configured.

## Next Steps

Once you have cluster access:

1. **[Configure your cluster environment](harvard-cluster.md)** - Set up your shell, storage paths, and tools
2. **[Learn cluster usage](cluster-usage.md)** - How to use interactive sessions and submit jobs
3. **[Review compute guidelines](compute-guidelines.md)** - Lab policies and best practices
