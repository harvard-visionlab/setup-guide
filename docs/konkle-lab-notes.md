# Konkle Lab: Open Notes and Questions

The cluster setup ([cluster reference](cluster-reference.md)) was built and tested for `alvarez_lab`. Nothing gets
built in `konkle_lab` storage until Konkle has agreed to it. This page lists what is known, what has been done, and
what to ask her.

## Already in Konkle lab space

- **2026-10-07: `lab_env.sh` deployed to `/n/holylabs/LABS/konkle_lab/Lab/setup/lab_env.sh`** (the deploy loop in
  cluster-reference §2 covered both labs). This created `Lab/setup/` (`drwxr-sr-x`, owner alvarez, group konkle_lab).
  No one sources it yet, and it was tested only by sourcing it (`LAB=konkle_lab`). **Keep it or remove it, depending
  on what Konkle says.** Until then the deploy loop is alvarez_lab only.

## Facts (2026-10-07)

| what | konkle_lab state |
|---|---|
| holylabs | `/n/holylabs/LABS/konkle_lab/Lab` (`drwxrws---`, root:konkle_lab). File quota not checked (it isn't visible from the CLI) |
| netscratch | `/n/netscratch/konkle_lab/Lab` (`drwxrws---`) has user dirs (`jacobprince`, `jandrade`, `tkonkle`); `Everyone/` has 7 entries |
| lab_storage | `/n/lab_storage/konkle_lab/Lab` (`drwxrwx---`, **no setgid**: new files keep the creator's primary group); only `jacobprince/` inside; no `sw/` |
| libjpeg-turbo / FFmpeg | not built. The alvarez builds (4.8 MB / 34 MB) are under `alvarez_lab/Lab`, which is group-only, so konkle-only members can't read them |
| Kempner | the `kempner_konkle_lab` fairshare account exists; George is in the unix group but has no SLURM association |

## Questions for Konkle

1. **Shared `lab_env.sh`:** OK to keep a lab-wide shell setup in `/n/holylabs/LABS/konkle_lab/Lab/setup/`, maintained
   from this repo? Who in her lab should be able to edit or redeploy it (the dir is writable only by George now)?
2. **Holylabs file quota:** does konkle_lab hit the same ~1M-file limit (ask FASRC for current usage)? Are members
   keeping `.venv`s, conda envs or uv caches on holylabs that should move to netscratch?
3. **Netscratch layout:** is `/n/netscratch/konkle_lab/Lab/$USER` the right place for personal venvs, uv cache and
   scratch (some members use it already), or does her lab use `Everyone/$USER`?
4. **lab_storage:** may we create `/n/lab_storage/konkle_lab/Lab/sw/` for lab software? Should `Lab/` get the setgid
   bit (`chmod g+s`) so shared files stay group `konkle_lab`?
5. **libjpeg-turbo and FFmpeg:** do her members need them (slipstream JPEG decoding, torchcodec video)? If so, which
   option:
   - build copies in konkle lab_storage (`LAB=konkle_lab sbatch scripts/cluster/build_libjpeg_turbo.sh`, same for
     `build_ffmpeg.sh`; ~40 MB total);
   - or a location both labs can read (e.g. ask FASRC for a shared dir, or relax permissions on alvarez `Lab/sw`).
6. **Kempner:** should George (and others who work with both labs) get a SLURM association with `kempner_konkle_lab`?
7. **Migration:** should the [2026-09-30 changelog](changelog.md) steps (move venvs off holylabs, new `.bashrc` block)
   be announced to her lab too?
