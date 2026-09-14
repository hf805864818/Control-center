#!/bin/bash
# build.sh - 同时编译 roothide 和 rootless 两种 .deb 包
# 用法: ./scripts/build.sh
# 需要: THEOS 环境变量已设置

set -euo pipefail

cd "$(dirname "$0")/.."

# 检查 THEOS 环境变量
if [ -z "${THEOS:-}" ]; then
    echo "❌ THEOS 环境变量未设置"
    echo "   请先运行: export THEOS=/opt/theos"
    exit 1
fi

echo "THEOS = $THEOS"
echo ""

# 读取版本号
VERSION=$(cat VERSION 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo "构建版本: $VERSION"

# 创建输出目录
OUTPUT_DIR="build_output"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/roothide" "$OUTPUT_DIR/rootless"

# ============================================
# 构建 roothide 版本
# ============================================
echo ""
echo "=========================================="
echo "  构建 roothide 版本..."
echo "=========================================="

make clean 2>/dev/null || true
make package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1 2>&1

# 查找生成的 .deb 文件
ROOTHIDE_DEB=$(find packages -name "*.deb" -type f 2>/dev/null | head -n 1 || echo "")
if [ -n "$ROOTHIDE_DEB" ]; then
    cp "$ROOTHIDE_DEB" "$OUTPUT_DIR/roothide/"
    # 重命名为包含版本号和架构的名称
    BASENAME=$(basename "$ROOTHIDE_DEB" .deb)
    cp "$ROOTHIDE_DEB" "$OUTPUT_DIR/roothide/CCEnhancer_v${VERSION}_roothide.deb"
    echo "✓ roothide .deb 已生成: $OUTPUT_DIR/roothide/CCEnhancer_v${VERSION}_roothide.deb"
else
    echo "❌ roothide 构建失败: 未找到 .deb 文件"
    exit 1
fi

# ============================================
# 构建 rootless 版本
# ============================================
echo ""
echo "=========================================="
echo "  构建 rootless 版本..."
echo "=========================================="

make clean 2>/dev/null || true
make package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1 2>&1

# 查找生成的 .deb 文件
ROOTLESS_DEB=$(find packages -name "*.deb" -type f 2>/dev/null | head -n 1 || echo "")
if [ -n "$ROOTLESS_DEB" ]; then
    cp "$ROOTLESS_DEB" "$OUTPUT_DIR/rootless/"
    cp "$ROOTLESS_DEB" "$OUTPUT_DIR/rootless/CCEnhancer_v${VERSION}_rootless.deb"
    echo "✓ rootless .deb 已生成: $OUTPUT_DIR/rootless/CCEnhancer_v${VERSION}_rootless.deb"
else
    echo "❌ rootless 构建失败: 未找到 .deb 文件"
    exit 1
fi

# ============================================
# 汇总
# ============================================
echo ""
echo "=========================================="
echo "  构建完成！"
echo "=========================================="
echo ""
echo "版本: $VERSION"
echo ""
echo "roothide 版本:"
ls -lh "$OUTPUT_DIR/roothide/"
echo ""
echo "rootless 版本:"
ls -lh "$OUTPUT_DIR/rootless/"
echo ""
echo "文件列表:"
find "$OUTPUT_DIR" -name "*.deb" -type f
