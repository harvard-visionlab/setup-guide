#!/bin/bash
#SBATCH --job-name=build-libjpeg-turbo
#SBATCH --partition=shared
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=build-libjpeg-turbo-%j.out
#
# Lab-wide libjpeg-turbo with SIMD (TurboJPEG API: libturbojpeg.so + turbojpeg.h) for slipstream's JPEG decoder.
# FASRC (Rocky 8) ships only the classic libjpeg.so.62 and has no nasm/yasm module (`module spider`, 2026-09-30), so this builds nasm (build-time only,
# not installed) and then libjpeg-turbo into a permanent prefix. See setup-guide docs/cluster-reference.md.
#
#   cd /n/netscratch/$LAB/Lab/$USER && sbatch <setup-guide>/scripts/cluster/build_libjpeg_turbo.sh   # never on the login node
#
# lab_env.sh sets TURBOJPEG_ROOT=<PREFIX> when the default prefix exists (bump its path there for a new version).
# Alvarez lab: already built (2026-09-30). Other labs build their own (LAB=konkle_lab), since lab_storage is group-only.
# The prefix must never move: slipstream's decoder is rpath-linked to it. An existing prefix is never overwritten.
set -euo pipefail

LAB="${LAB:-alvarez_lab}"
JT_VERSION="${JT_VERSION:-3.0.4}"
PREFIX="${PREFIX:-/n/lab_storage/$LAB/Lab/sw/libjpeg-turbo-$JT_VERSION}"
NASM_VERSION="${NASM_VERSION:-2.16.03}"
CMAKE_MODULE="${CMAKE_MODULE:-cmake/3.31.6-fasrc01}"
BUILD="${BUILD:-/n/netscratch/$LAB/Lab/$USER/build/libjpeg-turbo-$JT_VERSION}"
JOBS="${SLURM_CPUS_PER_TASK:-4}"

if [ -z "${SLURM_JOB_ID:-}" ] && command -v sbatch >/dev/null; then
  echo "error: run this as a job: sbatch $0" >&2
  exit 1
fi
if [ -e "$PREFIX" ]; then
  echo "error: $PREFIX exists; it is never overwritten (the decoder is rpath-linked to it)" >&2
  exit 1
fi

umask 0002  # group-writable/readable: the lab shares the prefix
set +u  # /etc/profile and lmod reference unset variables
source /etc/profile >/dev/null 2>&1 || true
module load "$CMAKE_MODULE"
set -u
echo "[build] $(date -Is) host=$(hostname) gcc=$(gcc -dumpversion) $(cmake --version | head -1)"

rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD"

# nasm: the assembler libjpeg-turbo's SIMD code needs (without it cmake builds a slow non-SIMD library)
curl -fsSL "https://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/nasm-$NASM_VERSION.tar.xz" | tar xJ
(cd "nasm-$NASM_VERSION" && ./configure --prefix="$BUILD/nasm" -q && make -j"$JOBS" -s && make install -s)
NASM="$BUILD/nasm/bin/nasm"
"$NASM" -v

curl -fsSL "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/$JT_VERSION/libjpeg-turbo-$JT_VERSION.tar.gz" | tar xz
cmake -S "libjpeg-turbo-$JT_VERSION" -B jt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_ASM_NASM_COMPILER="$NASM" \
  -DWITH_SIMD=1 -DREQUIRE_SIMD=1 \
  -DWITH_TURBOJPEG=1 \
  -DENABLE_STATIC=0
cmake --build jt-build -j"$JOBS"
(cd jt-build && ctest -j"$JOBS" --output-on-failure -R 'tjunittest|djpeg|cjpeg' | tail -5)
cmake --install jt-build

LIB="$PREFIX/lib64"; [ -d "$LIB" ] || LIB="$PREFIX/lib"  # (ls of a missing dir fails under pipefail)
test -f "$PREFIX/include/turbojpeg.h"
ls "$LIB"/libturbojpeg.so*
chmod -R g+rX "$PREFIX"
cat > "$PREFIX/BUILD_INFO" <<EOF
libjpeg-turbo $JT_VERSION (SIMD required), nasm $NASM_VERSION (build only), $(gcc --version | head -1), $(cmake --version | head -1)
built $(date -Is) on $(hostname) by $USER, SLURM job ${SLURM_JOB_ID:-none}; script: setup-guide scripts/cluster/build_libjpeg_turbo.sh
EOF
echo "[build] done: $PREFIX"
echo "next: make sure lab_env.sh sets TURBOJPEG_ROOT=$PREFIX, then rebuild venvs that include slipstream"
