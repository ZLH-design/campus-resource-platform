#!/usr/bin/env bash
# campus-resource-platform 目录骨架创建脚本
# 用法：在仓库根目录执行 bash create-structure.sh
# 依据：需求基线 §7.3 + 给 E 的交付说明 + 本周治理文件补充

set -e

ROOT="campus-resource-platform"

mkdir -p "$ROOT"
cd "$ROOT"

# 前端
mkdir -p frontend

# 四个后端服务（每个带自己的 Flyway 迁移目录）
for svc in m1 m2 m3 d; do
  mkdir -p "services/${svc}-service/src/main/java"
  mkdir -p "services/${svc}-service/src/main/resources/db/migration"
  mkdir -p "services/${svc}-service/src/test/java"
done

# 跨模块接口契约
mkdir -p openapi

# 部署与环境
mkdir -p deploy/nginx deploy/initdb

# 文档
mkdir -p docs/requirements docs/adr docs/ai docs/risks

# GitHub 治理
mkdir -p .github/workflows

# Git 不跟踪空目录，逐个占位（只排除真正的 .git 目录，不影响 .github）
find . -type d -not -path './.git' -not -path './.git/*' | while read -r d; do
  [ -f "$d/.gitkeep" ] || touch "$d/.gitkeep"
done

echo "目录骨架创建完成："
find . -type d -not -path './.git' -not -path './.git/*' | sort | sed 's|^\./||' | sed 's|[^/]*/|  |g'
