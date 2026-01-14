# Vision Lab Setup

Setup guides for Vision Lab members to configure their computing environments.

## Guides

| Environment | Guide | Status |
|-------------|-------|--------|
| Harvard FASRC Cluster | [docs/harvard-cluster.md](docs/harvard-cluster.md) | In progress |
| Laptop (macOS/Linux) | docs/laptop.md | Planned |
| Lightning AI | docs/lightning-ai.md | Planned |
| Lab Workstations | docs/lab-workstations.md | Planned |

## Quick Start (Harvard Cluster)

See [docs/harvard-cluster.md](docs/harvard-cluster.md) for the full walkthrough. Summary:

1. **Configure shell** - Add lab environment variables to `~/.bashrc`
2. **Create folder structure** - Set up `Projects/`, `Buckets/`, `Sandbox/` on holylabs
3. **Set up symlinks** - Redirect large cache directories off your home quota
4. **Install uv** - Modern Python package manager
5. **Create your first project** - Initialize a uv project with dependencies

## Lab Affiliation

Set `LAB` to your primary advisor's lab:
- `alvarez_lab`
- `konkle_lab`

This determines paths for holylabs and netscratch storage.

## Contributing

Found an issue or have a suggestion? Open an issue or PR.
