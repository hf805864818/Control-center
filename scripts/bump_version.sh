#!/bin/bash
# bump_version.sh - 自动递增版本号
# 用法: ./scripts/bump_version.sh [patch|minor|major]
# 默认: patch (例如 1.0.0 → 1.0.1)

set -euo pipefail

cd "$(dirname "$0")/.."

# 读取当前版本
CURRENT_VERSION=$(cat VERSION 2>/dev/null | tr -d '[:space:]' || echo "1.0.0")
echo "当前版本: $CURRENT_VERSION"

# 拆分版本号
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# 确保各部分是数字
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

# 递增类型
BUMP_TYPE="${1:-patch}"
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "用法: $0 [patch|minor|major]"
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "新版本: $NEW_VERSION"

# 1. 更新 VERSION 文件
echo "$NEW_VERSION" > VERSION
echo "✓ VERSION 已更新"

# 2. 更新 control 文件的 Version 字段
if command -v sed &> /dev/null; then
    # macOS sed 和 GNU sed 兼容写法
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/^Version: .*/Version: $NEW_VERSION/" control
    else
        sed -i "s/^Version: .*/Version: $NEW_VERSION/" control
    fi
    echo "✓ control 文件已更新"
fi

# 3. 更新 CCToggle/Info.plist 中的版本号
if [ -f CCToggle/Info.plist ]; then
    if command -v plutil &> /dev/null; then
        plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" CCToggle/Info.plist 2>/dev/null || true
        plutil -replace CFBundleVersion -string "$NEW_VERSION" CCToggle/Info.plist 2>/dev/null || true
        echo "✓ CCToggle/Info.plist 已更新"
    elif command -v /usr/bin/plutil &> /dev/null; then
        /usr/bin/plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" CCToggle/Info.plist 2>/dev/null || true
        /usr/bin/plutil -replace CFBundleVersion -string "$NEW_VERSION" CCToggle/Info.plist 2>/dev/null || true
        echo "✓ CCToggle/Info.plist 已更新"
    fi
fi

# 4. 更新 CCBgPrefs/Resources/Info.plist
if [ -f CCBgPrefs/Resources/Info.plist ]; then
    if command -v plutil &> /dev/null; then
        plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" CCBgPrefs/Resources/Info.plist 2>/dev/null || true
        plutil -replace CFBundleVersion -string "$NEW_VERSION" CCBgPrefs/Resources/Info.plist 2>/dev/null || true
        echo "✓ CCBgPrefs/Resources/Info.plist 已更新"
    fi
fi

# 5. 更新 CCSliderPrefs/Resources/Info.plist
if [ -f CCSliderPrefs/Resources/Info.plist ]; then
    if command -v plutil &> /dev/null; then
        plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" CCSliderPrefs/Resources/Info.plist 2>/dev/null || true
        plutil -replace CFBundleVersion -string "$NEW_VERSION" CCSliderPrefs/Resources/Info.plist 2>/dev/null || true
        echo "✓ CCSliderPrefs/Resources/Info.plist 已更新"
    fi
fi

echo ""
echo "✅ 版本号已递增至 $NEW_VERSION"
echo "   - VERSION 文件"
echo "   - control 文件"
echo "   - CCToggle/Info.plist"
echo "   - CCBgPrefs/Resources/Info.plist"
echo "   - CCSliderPrefs/Resources/Info.plist"
