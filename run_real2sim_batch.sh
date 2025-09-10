#!/usr/bin/env bash
set -euo pipefail

# 找到当前脚本所在目录，避免依赖固定工作目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 仓库根 / dataset 根（沿用你原来的结构）
REPO_DIR="$SCRIPT_DIR/DISCOVERSE-Real2Sim"
DATASET_ROOT="$REPO_DIR/dataset"

# 可选：给“训练用的 output 子目录名”一个统一的指定
# 不传则沿用 run_real2sim.sh 的默认逻辑（自动选 output 下最新的子目录）
OUT_SUBDIR="${1:-}"

# 基础检查
[ -d "$DATASET_ROOT" ] || { echo "ERROR: 找不到 dataset 目录：$DATASET_ROOT"; exit 1; }

echo "批处理开始：遍历 $DATASET_ROOT 下的所有数据集目录..."
# 只遍历一级子目录（dataset/*/）
shopt -s nullglob
for d in "$DATASET_ROOT"/*/ ; do
  DATASET_NAME="$(basename "$d")"

  echo "============================================================"
  echo ">>> 处理数据集：$DATASET_NAME"
  echo "    路径：$d"
  echo "------------------------------------------------------------"

  if [ -n "$OUT_SUBDIR" ]; then
    bash "$SCRIPT_DIR/run_real2sim.sh" "$DATASET_NAME" "$OUT_SUBDIR"
  else
    bash "$SCRIPT_DIR/run_real2sim.sh" "$DATASET_NAME"
  fi

  echo "<<< 完成：$DATASET_NAME"
  echo
done
echo "✅ 全部处理完成。"
