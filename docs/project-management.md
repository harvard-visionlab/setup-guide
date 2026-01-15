# Project Management

This guide provides an overview of the project and compute ecosystem, focusing on the core components of our workflows and the reasoning behind them.

## Philosophy: Stability Through Agility

The goal of a neuro-AI project and compute ecosystem is to be both **stable/backed up** and **flexible/portable** between systems. We call this "stability through agility."

Your code should run on the cluster, a lab workstation, or Lightning AI with minimal-to-no changes. If the cluster is full or down, you can pivot to Lightning or a lab station. If you need a cheaper, easier space to develop and then need more compute for part of the project, you can move between lightweight and compute-heavy resources without a lot of work.

The components of this system (and the workflows) are designed with these goals in mind.

## Core Components

### 1. GitHub for Code

All code lives in GitHub repositories.

**Why:**
- Version control tracks changes and enables collaboration
- Pre-cursor step for publicly available repos with publications
- Clarity and transparency in how analyses were done
- Open source by default

### 2. Python Scripts for Analyses

Use `.py` scripts for running analyses and saving outputs.

**Why:**
- Reproducible - anyone can run the same script and get the same results
- Clarity - scripts are self-documenting
- Programmatic outputs - automatically name and organize files in the right output folders
- Git-friendly - scripts diff cleanly, notebooks don't

**When to use notebooks:** Jupyter notebooks (`.ipynb`) should only be used for "work it out" mode - interactive sessions to develop an analysis. Once the analysis is working, shift to `.py` scripts to "lock in" the workflow.

**Why not notebooks for production:**
- Notebooks don't work well with GitHub (messy diffs, merge conflicts)
- Hidden state can make results non-reproducible
- Hard to run programmatically or in batch jobs

### 3. S3 for Data and Outputs

All data and outputs live in S3 buckets.

**Why:**
- **Backed up** - AWS 99.99% durability
- **Accessible** - from any compute environment
- **Portable** - not tied to any single machine
- **Cost effective** - cheaper than cluster storage for large datasets

## Available Compute Environments

| Environment | Best For | Trade-offs |
|-------------|----------|------------|
| **Laptop** | Development, writing, CPU-bound work | No GPU |
| **Kempner Cluster** | Large-scale training, GPU jobs | Queue times, shared resource |
| **Lightning AI** | "Laptop in the cloud", development with GPUs | Cost per hour |
| **Lab Workstation** | Medium-scale training, interactive GPU work | Shared with lab |

We realized any single project usually needs more than one of these, because different systems balance **time**, **scale**, and **cost** differently.

By adopting these core components and workflows, you'll have a system that is:
- **Portable** between systems
- **Stable** because it's backed up in multiple places
- **Shareable** with collaborators who may use different systems

This is more robust than if your code is tailored to work in only one compute environment.

## Other Project Components

Beyond code and compute, projects have other essential components:

### Slack Project Channel

For updates, communication of progress, literature sharing, etc.

### Dropbox Project Folder

For other project documents, automatically backed up and shared among co-authors:
- Lab notebooks
- Conference abstracts
- Posters
- Talk slides
- Manuscripts

**Note:** Dropbox is for documents, not code or data. Code goes in GitHub, data/outputs go in S3.

## Scenarios: Check Your Vulnerabilities

For your projects right now, ask yourself these questions:

### Hardware Failure

**Your laptop hard drive fails tomorrow. How bad is it?**

- Can you recover your code? (It should all be pushed to GitHub)
- Can you recover your data and outputs? (They should all be in S3)
- Can you recover your documents? (They should all be in Dropbox)

If the answer to any of these is "no" or "I'd lose weeks of work," that's a vulnerability to fix.

### System Outage

**The cluster is down and inaccessible - you can't even log in to retrieve files. You have a deadline in a week. Can you still make it?**

- Is your code somewhere other than the cluster? (GitHub)
- Are your outputs somewhere other than the cluster? (S3)
- Can you run your analyses on Lightning or a lab workstation instead?

If you're blocked because everything lives on one system, that's a vulnerability.

### Sharing

**A collaborator is excited about using your stimuli or analysis. How easy is it to share with them?**

- Can you send them a GitHub link to clone?
- Can they access the data in S3?
- Is there documentation so they know how to run things?
- Will the code work on their system, or is it hardcoded to your paths?

If sharing requires you to manually copy files, rewrite paths, or spend hours explaining how things work, that's friction that slows science down.

---

The workflows and components in this guide are designed to give you good answers to all of these questions.
