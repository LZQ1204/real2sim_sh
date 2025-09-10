#!/usr/bin/env bash
set -euo pipefail

# ========== 基本路径（按你的目录已写死为绝对路径） ==========
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
BLENDER_BIN="$BASE_DIR/blender-3.1.2-linux-x64/blender"
REPO_DIR="$BASE_DIR/DISCOVERSE-Real2Sim"

# ========== 参数 ==========
DATASET_NAME="${1:-drawer1_black}"     # 第1个参数：数据集名（默认 drawer1）
OUT_SUBDIR="${2:-}"              # 第2个参数：可选，output 下具体子目录名

IN_DIR="$REPO_DIR/dataset/$DATASET_NAME/glb"
HDR_DIR="$REPO_DIR/dataset/$DATASET_NAME/hdr"
OUT_DIR="$REPO_DIR/dataset/$DATASET_NAME/output"

log() { echo -e "\033[1;34m[$(date '+%F %T')] $*\033[0m"; }
die() { echo -e "\033[1;31mERROR: $*\033[0m" >&2; exit 1; }

# ========== 基础检查 ==========
[ -x "$BLENDER_BIN" ] || die "Blender 不存在或不可执行：$BLENDER_BIN"
[ -d "$REPO_DIR" ]    || die "仓库目录不存在：$REPO_DIR"
[ -d "$IN_DIR" ]      || die "找不到输入 glb 目录：$IN_DIR"
[ -d "$HDR_DIR" ]     || die "找不到 HDR 目录：$HDR_DIR"
mkdir -p "$OUT_DIR"

# ========== Step 1/3: Blender 渲染 ==========
BLENDER_SCRIPT="$REPO_DIR/blender_renderer/glb_render.py"
[ -f "$BLENDER_SCRIPT" ] || die "找不到 Blender 渲染脚本：$BLENDER_SCRIPT"

log "Step 1/3 Blender 渲染：$IN_DIR + $HDR_DIR -> $OUT_DIR"
"$BLENDER_BIN" --background \
  --python "$BLENDER_SCRIPT" -- \
  --root_in_path "$IN_DIR" \
  --root_hdr_path "$HDR_DIR" \
  --root_out_path "$OUT_DIR"

# ========== Step 2/3: 转为 COLMAP 相机格式 ==========
pushd "$REPO_DIR/blender_renderer" >/dev/null
# if   [ -f "tocolmap.py" ]; then PY_CONVERT="tocolmap.py"
# elif [ -f "models2colmap.py" ]; then PY_CONVERT="models2colmap.py"
# else die "blender_renderer 下找不到 tocolmap.py / models2colmap.py"
# fi
PY_CONVERT="models2colmap.py"
log "Step 2/3 相机参数转 COLMAP：python $PY_CONVERT --out_path $OUT_DIR"
python "$PY_CONVERT" --root_path "$OUT_DIR"
popd >/dev/null

# ========== 选取用于 Mesh2GS 训练的子目录 ==========
if [ -n "$OUT_SUBDIR" ]; then
  SRC_DIR="$OUT_DIR/$OUT_SUBDIR"
else
  # 取 output 下“最新”的一级子目录作为训练输入
  SRC_DIR="$(ls -dt "$OUT_DIR"/*/ 2>/dev/null | head -1 | sed 's:/*$::')"
fi
[ -d "$SRC_DIR" ] || die "无法确定 Mesh2GS 的输入目录，请显式指定：第二个参数为 output 下的子目录名。当前 OUT_DIR=$OUT_DIR"

# ========== Step 3/3: Mesh -> 3DGS 训练 ==========
pushd "$REPO_DIR/LitMesh2GS" >/dev/null
log "Step 3/3 Mesh→3DGS 训练：-s $SRC_DIR  -m $SRC_DIR/mesh2gs"
python train.py \
  -s "$SRC_DIR" \
  -m "$SRC_DIR/mesh2gs" \
  --data_device cuda \
  --densify_grad_threshold 0.0002 \
  -r 1
popd >/dev/null

log "全部完成 ✅ 3DGS 输出目录：$SRC_DIR/mesh2gs"
