#!/usr/bin/env bash
set -euo pipefail

# # ===== 在非交互脚本里启用 conda 并激活环境（与上个脚本一致）=====
# set +u
# if command -v conda >/dev/null 2>&1; then
#   eval "$(conda shell.bash hook)"
# elif [ -f "/home/qz/anaconda3/etc/profile.d/conda.sh" ]; then
#   . "/home/qz/anaconda3/etc/profile.d/conda.sh"
# elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
#   . "$HOME/miniconda3/etc/profile.d/conda.sh"
# else
#   echo "ERROR: conda 未找到，请把 conda.sh 的实际路径填进脚本。" >&2
#   exit 1
# fi
# export QT_XCB_GL_INTEGRATION="${QT_XCB_GL_INTEGRATION-}"
# conda activate mesh2gs_docker || { echo "ERROR: 激活 mesh2gs_docker 失败"; exit 1; }
# set -u

# ===== 基本路径 =====
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
REPO_DIR="$BASE_DIR/DISCOVERSE-Real2Sim"
DIFF_DIR="$REPO_DIR/DiffusionLight"

# ===== 参数 =====
DATASET="${1:-drawer1}"
# 可选：第二参=输入目录；第三参=输出根目录
# IN_DIR="${2:-$REPO_DIR/dataset/$DATASET/dl_input}"
IN_DIR="${2:-$REPO_DIR/dataset/light/input}"
OUT_DIR="${3:-$REPO_DIR/dataset/light/output}"
# OUT_DIR="${3:-$REPO_DIR/dataset/$DATASET}"

# ===== 日志工具 =====
log() { echo -e "\033[1;34m[$(date '+%F %T')] $*\033[0m"; }
die() { echo -e "\033[1;31mERROR: $*\033[0m" >&2; exit 1; }

# ===== 基础检查 =====
[ -d "$DIFF_DIR" ] || die "找不到 DiffusionLight 目录：$DIFF_DIR"
[ -d "$IN_DIR" ]   || die "输入目录不存在：$IN_DIR（请放入背景图像）"
mkdir -p "$OUT_DIR"

INPAINT="$DIFF_DIR/inpaint.py"
BALL2ENV="$DIFF_DIR/ball2envmap.py"
EXPO2HDR="$DIFF_DIR/exposure2hdr.py"
[ -f "$INPAINT" ] || die "缺少脚本：$INPAINT"
[ -f "$BALL2ENV" ] || die "缺少脚本：$BALL2ENV"
[ -f "$EXPO2HDR" ] || die "缺少脚本：$EXPO2HDR"

# 输入是否有图像（jpg/png/jpeg）
if ! compgen -G "$IN_DIR/*.[jJ][pP][gG]" > /dev/null && \
   ! compgen -G "$IN_DIR/*.[pP][nN][gG]" > /dev/null && \
   ! compgen -G "$IN_DIR/*.[jJ][pP][eE][gG]" > /dev/null; then
  die "在 $IN_DIR 未发现 jpg/png/jpeg 图像，请放入至少一张背景图。"
fi

# ===== Step 1: inpaint -> 输出 OUT_DIR（将生成 OUT_DIR/square 等）=====
log "Step 1/3 inpaint: --dataset $IN_DIR --output_dir $OUT_DIR"
pushd "$DIFF_DIR" >/dev/null
python "$INPAINT" --dataset "$IN_DIR" --output_dir "$OUT_DIR"
popd >/dev/null
[ -d "$OUT_DIR/square" ] || die "inpaint 结果缺少目录：$OUT_DIR/square"

# ===== Step 2: ball2envmap -> 输出 OUT_DIR/envmap =====
log "Step 2/3 ball2envmap: --ball_dir $OUT_DIR/square --envmap_dir $OUT_DIR/envmap"
pushd "$DIFF_DIR" >/dev/null
python "$BALL2ENV" --ball_dir "$OUT_DIR/square" --envmap_dir "$OUT_DIR/envmap"
popd >/dev/null
[ -d "$OUT_DIR/envmap" ] || die "ball2envmap 结果缺少目录：$OUT_DIR/envmap"

# ===== Step 3: exposure2hdr -> 输出 OUT_DIR/hdr（*.exr）=====
log "Step 3/3 exposure2hdr: --input_dir $OUT_DIR/envmap --output_dir $OUT_DIR/hdr"
pushd "$DIFF_DIR" >/dev/null
python "$EXPO2HDR" --input_dir "$OUT_DIR/envmap" --output_dir "$OUT_DIR/hdr"
popd >/dev/null

# 检查是否产出至少一个 .exr
if ! compgen -G "$OUT_DIR/hdr/*.exr" >/dev/null; then
  die "未在 $OUT_DIR/hdr 发现 .exr 输出，请检查前序步骤日志。"
fi

log "全部完成 ✅ HDR 输出目录（给 Blender 用）：$OUT_DIR/hdr"
