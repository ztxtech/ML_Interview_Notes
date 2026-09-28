#!/usr/bin/env bash
# 安装/更新 Git 钩子配置：让本仓库使用仓库内 script/hooks/
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"

if [ ! -f "$ROOT/script/hooks/pre-commit" ]; then
  echo "缺少 $ROOT/script/hooks/pre-commit，无法安装。" >&2
  exit 1
fi

git config core.hooksPath script/hooks
echo "已启用仓库内钩子目录：script/hooks（pre-commit 将自动执行个人信息安全检查）"
