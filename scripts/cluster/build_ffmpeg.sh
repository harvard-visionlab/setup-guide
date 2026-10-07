#!/bin/bash
#SBATCH --job-name=build-ffmpeg
#SBATCH --partition=shared
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=build-ffmpeg-%j.out
#
# Lab-wide FFmpeg (shared libs + ffmpeg/ffprobe) with libx264/libx265 encoders and NVDEC/CUVID, for torchcodec
# (slipstream's DecodeVideoWindow) and for encoding on the cluster. FASRC has no FFmpeg libs (no libavcodec in
# `ldconfig -p`, no module), so torchcodec fails at the first decode without this.
#
#   cd /n/netscratch/$LAB/Lab/$USER && sbatch <setup-guide>/scripts/cluster/build_ffmpeg.sh   # never on the login node
#
# Builds nasm (build only), x264 (8-bit), x265 (8-bit) and FFmpeg into one permanent prefix; everything is
# rpath-linked to $PREFIX/lib, so the prefix must never move. An existing prefix is never overwritten; a failed build
# removes the prefix it created. Uses the system gcc 8.5 (not a gcc module): x265 is C++, and a module's libstdc++
# would be missing at runtime for anyone who didn't load it.
# lab_env.sh sets FFMPEG_ROOT, PATH and LD_LIBRARY_PATH when the default prefix exists (torchcodec dlopens
# libavutil.so.N etc. by soname, so it needs LD_LIBRARY_PATH; ffmpeg's own binaries don't).
# CPU AV1 decoding needs dav1d (not built: FFmpeg's native av1 decoder is hwaccel-only); NVDEC decodes AV1 on GPUs.
# Set WITH_NVDEC=0 to build CPU-only.
set -euo pipefail

LAB="${LAB:-alvarez_lab}"
FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.3}"
PREFIX="${PREFIX:-/n/lab_storage/$LAB/Lab/sw/ffmpeg-$FFMPEG_VERSION}"
X264_COMMIT="${X264_COMMIT:-b35605ace3ddf7c1a5d67a2eb553f034aef41d55}"  # x264 stable branch, 2025-06-08
X265_VERSION="${X265_VERSION:-3.6}"  # 4.x changed the encode API; 3.6 is the safe pair for FFmpeg 7.1
NVCODEC_VERSION="${NVCODEC_VERSION:-12.1.14.0}"  # needs NVIDIA driver >= 530.41 at runtime
WITH_NVDEC="${WITH_NVDEC:-1}"
NASM_VERSION="${NASM_VERSION:-2.16.03}"
CMAKE_MODULE="${CMAKE_MODULE:-cmake/3.31.6-fasrc01}"
BUILD="${BUILD:-/n/netscratch/$LAB/Lab/$USER/build/ffmpeg-$FFMPEG_VERSION}"
JOBS="${SLURM_CPUS_PER_TASK:-4}"
# Optional torchcodec check against an existing venv (read-only: uv run --no-sync). Skipped if the dir is missing.
TORCHCODEC_PROJECT="${TORCHCODEC_PROJECT:-/n/holylabs/LABS/$LAB/Users/$USER/Projects/datasets}"
TORCHCODEC_GROUP="${TORCHCODEC_GROUP:-video}"

if [ -z "${SLURM_JOB_ID:-}" ] && command -v sbatch >/dev/null; then
  echo "error: run this as a job: sbatch $0" >&2
  exit 1
fi
if [ -e "$PREFIX" ]; then
  echo "error: $PREFIX exists; it is never overwritten (everything is rpath-linked to it)" >&2
  exit 1
fi

umask 0002  # group-writable/readable: the lab shares the prefix
set +u  # /etc/profile and lmod reference unset variables
source /etc/profile >/dev/null 2>&1 || true
module purge
module load "$CMAKE_MODULE"
set -u
export CC=/usr/bin/gcc CXX=/usr/bin/g++
echo "[build] $(date -Is) host=$(hostname) $($CC --version | head -1) $(cmake --version | head -1)"

mkdir -p "$PREFIX"
done_ok=0
trap '[ "$done_ok" = 1 ] || { echo "[build] FAILED: removing $PREFIX" >&2; rm -rf "$PREFIX"; }' EXIT

rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD"
export PATH="$BUILD/nasm/bin:$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
RPATH="-Wl,-rpath,$PREFIX/lib"

# nasm: x264/x265/FFmpeg assembly (no nasm/yasm module on FASRC)
curl -fsSL "https://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/nasm-$NASM_VERSION.tar.xz" | tar xJ
(cd "nasm-$NASM_VERSION" && ./configure --prefix="$BUILD/nasm" -q && make -j"$JOBS" -s && make install -s)
nasm -v

# x264 (8-bit, shared)
curl -fsSL "https://code.videolan.org/videolan/x264/-/archive/$X264_COMMIT/x264-$X264_COMMIT.tar.bz2" | tar xj
(cd "x264-$X264_COMMIT" \
  && ./configure --prefix="$PREFIX" --enable-shared --enable-pic --disable-cli --bit-depth=8 --extra-ldflags="$RPATH" \
  && make -j"$JOBS" && make install)

# x265 (8-bit, shared)
mkdir x265 && curl -fsSL "https://bitbucket.org/multicoreware/x265_git/get/$X265_VERSION.tar.gz" | tar xz -C x265 --strip-components=1
cmake -S x265/source -B x265-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DLIB_INSTALL_DIR=lib \
  -DCMAKE_INSTALL_RPATH="$PREFIX/lib" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_SHARED=ON -DENABLE_CLI=OFF -DHIGH_BIT_DEPTH=OFF -DENABLE_LIBNUMA=OFF
cmake --build x265-build -j"$JOBS"
cmake --install x265-build
rm -f "$PREFIX"/lib/libx265.a

# nv-codec-headers (headers + .pc only; FFmpeg dlopens libcuda/libnvcuvid at runtime, no CUDA toolkit needed)
NV_FLAGS=()
if [ "$WITH_NVDEC" = 1 ]; then
  curl -fsSL "https://github.com/FFmpeg/nv-codec-headers/releases/download/n$NVCODEC_VERSION/nv-codec-headers-$NVCODEC_VERSION.tar.gz" | tar xz
  make -C "nv-codec-headers-$NVCODEC_VERSION" install PREFIX="$PREFIX"
  NV_FLAGS=(--enable-ffnvcodec --enable-cuvid --enable-nvdec --enable-nvenc)
fi

# FFmpeg
curl -fsSL "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" | tar xJ
(cd "ffmpeg-$FFMPEG_VERSION" && ./configure \
  --prefix="$PREFIX" --libdir="$PREFIX/lib" \
  --cc="$CC" --cxx="$CXX" \
  --enable-shared --disable-static --enable-pic \
  --enable-gpl --enable-libx264 --enable-libx265 \
  "${NV_FLAGS[@]}" \
  --disable-doc --disable-debug \
  --extra-cflags="-I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib $RPATH" \
  && make -j"$JOBS" && make install)

# ---- verification (a failed check fails the job and removes the prefix) ----
fail() { echo "[check] FAILED: $*" >&2; exit 1; }
FF="$PREFIX/bin/ffmpeg"
"$FF" -hide_banner -version | head -1
LDD=$(ldd "$FF" "$PREFIX"/lib/libavcodec.so "$PREFIX"/lib/libavformat.so)
echo "[check] linked libs:"; grep -E 'libav|libsw|libx26|not found' <<<"$LDD" | sort -u
if grep -q 'not found' <<<"$LDD"; then fail "unresolved libraries"; fi
ENC=$("$FF" -hide_banner -encoders); DEC=$("$FF" -hide_banner -decoders)
grep -E 'libx264|libx265' <<<"$ENC"
grep -q libx264 <<<"$ENC" && grep -q libx265 <<<"$ENC" || fail "libx264/libx265 encoders missing"
grep -E ' (h264|hevc|mjpeg|av1)(_cuvid)? ' <<<"$DEC"
grep -q ' h264 ' <<<"$DEC" && grep -q ' hevc ' <<<"$DEC" && grep -q ' mjpeg ' <<<"$DEC" || fail "h264/hevc/mjpeg decoders missing"
if [ "$WITH_NVDEC" = 1 ]; then
  echo "[check] hwaccels: $("$FF" -hide_banner -hwaccels | tail -n +2 | tr '\n' ' ')"
  grep -q h264_cuvid <<<"$DEC" || fail "NVDEC/CUVID decoders missing"
fi

TEST="$BUILD/test"; mkdir -p "$TEST"
for enc in libx264 libx265; do
  "$FF" -nostdin -hide_banner -loglevel error -y -f lavfi -i testsrc2=size=640x360:rate=30 -t 4 \
    -c:v "$enc" -g 60 -pix_fmt yuv420p "$TEST/test_$enc.mp4"
  "$PREFIX/bin/ffprobe" -v error -select_streams v:0 -count_frames \
    -show_entries stream=codec_name,width,height,nb_read_frames -of csv=p=0 "$TEST/test_$enc.mp4"
done

# torchcodec: reported, not fatal (a problem in that venv shouldn't discard a good FFmpeg build)
TC_STATUS="skipped (no $TORCHCODEC_PROJECT or no uv)"
if [ -d "$TORCHCODEC_PROJECT" ] && command -v uv >/dev/null; then
  echo "[check] torchcodec decode via $TORCHCODEC_PROJECT (uv run --no-sync --group $TORCHCODEC_GROUP)"
  (
    set +eu
    . "/n/holylabs/LABS/$LAB/Lab/setup/lab_env.sh"
    set -e
    export LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    cd "$TORCHCODEC_PROJECT"
    for enc in libx264 libx265; do
      uv run --no-sync --group "$TORCHCODEC_GROUP" python -c "
from torchcodec.decoders import VideoDecoder
d = VideoDecoder('$TEST/test_$enc.mp4')
print('$enc', d.metadata, tuple(d.get_frames_in_range(0, 10).data.shape))"
    done
  ) && TC_STATUS=ok || TC_STATUS="FAILED (FFmpeg checks passed; see the torchcodec output above)"
fi
echo "[check] torchcodec: $TC_STATUS"

chmod -R g+rX "$PREFIX"
cat > "$PREFIX/BUILD_INFO" <<EOF
FFmpeg $FFMPEG_VERSION (shared, GPL; libx264 $X264_COMMIT, libx265 $X265_VERSION 8-bit; nvdec/cuvid: $WITH_NVDEC, nv-codec-headers $NVCODEC_VERSION)
nasm $NASM_VERSION (build only), $($CC --version | head -1), $(cmake --version | head -1); rpath $PREFIX/lib
built $(date -Is) on $(hostname) by $USER, SLURM job ${SLURM_JOB_ID:-none}; script: setup-guide scripts/cluster/build_ffmpeg.sh
checks: x264/x265 encode + ffprobe ok; torchcodec: $TC_STATUS
EOF
done_ok=1
echo "[build] done: $PREFIX"
echo "next: make sure lab_env.sh sets FFMPEG_ROOT=$PREFIX (adds bin to PATH, lib to LD_LIBRARY_PATH); redeploy it"
