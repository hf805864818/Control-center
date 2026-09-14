#!/bin/bash
# setup_theos.sh - 设置 Theos 构建环境（支持 roothide + rootless）
# 安装两个 Theos 版本:
#   /opt/theos          - 标准 Theos (rootless)
#   /opt/theos-roothide - roothide Theos fork

set -euo pipefail

echo "安装构建依赖..."
sudo apt-get update -qq 2>/dev/null || true
sudo apt-get install -y -qq \
    fakeroot rsync perl curl unzip dpkg-dev libtinfo5 \
    2>/dev/null || true

# 安装 ldid
if ! command -v ldid &> /dev/null; then
    echo "安装 ldid..."
    curl -sL -o /tmp/ldid "https://github.com/opa334/ldid/releases/latest/download/ldid_linux_x86_64" 2>/dev/null || \
    curl -sL -o /tmp/ldid "https://github.com/opa334/ldid/releases/download/v2.1.5-procursus3/ldid_linux_x86_64" 2>/dev/null || true
    if [ -f /tmp/ldid ] && [ -s /tmp/ldid ]; then
        chmod +x /tmp/ldid
        sudo mv /tmp/ldid /usr/local/bin/ldid
    fi
fi

# ============================================
# 安装标准 Theos (rootless)
# ============================================
export THEOS="${THEOS:-/opt/theos}"

if [ ! -f "$THEOS/makefiles/common.mk" ]; then
    echo "安装标准 Theos 到 $THEOS ..."
    sudo mkdir -p "$THEOS"
    sudo chown -R "$(whoami)" "$THEOS"
    git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
else
    echo "标准 Theos 已安装: $THEOS"
fi

# ============================================
# 安装 roothide Theos fork
# ============================================
THEOS_ROOTHIDE="/opt/theos-roothide"

if [ ! -f "$THEOS_ROOTHIDE/makefiles/common.mk" ]; then
    echo "安装 roothide Theos 到 $THEOS_ROOTHIDE ..."
    sudo mkdir -p "$THEOS_ROOTHIDE"
    sudo chown -R "$(whoami)" "$THEOS_ROOTHIDE"
    git clone --recursive --depth 1 https://github.com/roothide/Theos.git "$THEOS_ROOTHIDE"
else
    echo "roothide Theos 已安装: $THEOS_ROOTHIDE"
fi

# ============================================
# 下载 iOS SDK (只下载一次, 复制到两个 Theos)
# ============================================
download_sdks() {
    local target_dir="$1"
    mkdir -p "$target_dir"

    # 检查是否已有 .sdk 目录
    local sdk_count=$(find "$target_dir" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
    if [ "$sdk_count" -gt 0 ]; then
        echo "  SDK 已存在 ($sdk_count 个): $(ls "$target_dir" | head -3)"
        return 0
    fi

    echo "  下载 iOS SDK 到 $target_dir ..."

    # 方法1: 从 theos/sdks 仓库下载
    curl -sL -o /tmp/sdks.zip "https://github.com/theos/sdks/archive/refs/heads/master.zip" 2>/dev/null || true
    if [ -f /tmp/sdks.zip ] && [ -s /tmp/sdks.zip ]; then
        unzip -q /tmp/sdks.zip -d /tmp/sdks_extracted 2>/dev/null || true
        if [ -d /tmp/sdks_extracted/sdks-master ]; then
            cp -r /tmp/sdks_extracted/sdks-master/*.sdk "$target_dir/" 2>/dev/null || true
            cp -r /tmp/sdks_extracted/sdks-master/*.sdk.* "$target_dir/" 2>/dev/null || true
            rm -rf /tmp/sdks_extracted
        fi
        rm -f /tmp/sdks.zip
    fi

    # 检查是否成功
    sdk_count=$(find "$target_dir" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
    if [ "$sdk_count" -eq 0 ]; then
        # 方法2: 直接下载 .tar.xz 格式的 SDK
        echo "  尝试直接下载 SDK tar.xz ..."
        for sdk_url in \
            "https://github.com/theos/sdks/raw/master/iPhoneOS16.5.sdk.tar.xz" \
            "https://github.com/theos/sdks/raw/master/iPhoneOS15.5.sdk.tar.xz" \
            "https://github.com/theos/sdks/raw/master/iPhoneOS14.5.sdk.tar.xz"; do
            echo "  尝试: $sdk_url"
            curl -sL -o /tmp/sdk.tar.xz "$sdk_url" 2>/dev/null || true
            if [ -f /tmp/sdk.tar.xz ] && [ -s /tmp/sdk.tar.xz ]; then
                tar -xf /tmp/sdk.tar.xz -C "$target_dir/" 2>/dev/null && {
                    rm -f /tmp/sdk.tar.xz
                    break
                }
                rm -f /tmp/sdk.tar.xz
            fi
        done
    fi

    # 最终检查
    sdk_count=$(find "$target_dir" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
    if [ "$sdk_count" -gt 0 ]; then
        echo "  ✓ SDK 安装成功 ($sdk_count 个)"
        ls -1 "$target_dir" | head -5
    else
        echo "  ✗ SDK 安装失败!"
    fi
}

echo "安装 SDK 到标准 Theos..."
download_sdks "$THEOS/sdks"

echo "安装 SDK 到 roothide Theos..."
download_sdks "$THEOS_ROOTHIDE/sdks"

# 如果 roothide 没有 SDK 但标准有, 复制过去
roothide_sdk_count=$(find "$THEOS_ROOTHIDE/sdks" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
standard_sdk_count=$(find "$THEOS/sdks" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
if [ "$roothide_sdk_count" -eq 0 ] && [ "$standard_sdk_count" -gt 0 ]; then
    echo "从标准 Theos 复制 SDK 到 roothide Theos..."
    cp -r "$THEOS/sdks/"*.sdk "$THEOS_ROOTHIDE/sdks/"
    roothide_sdk_count=$(find "$THEOS_ROOTHIDE/sdks" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
fi

# ============================================
# 验证安装
# ============================================
echo ""
echo "===== Theos 安装验证 ====="
echo "标准 Theos (rootless):"
echo "  路径: $THEOS"
echo "  ldid: $(command -v ldid 2>/dev/null || echo 'not found')"
echo "  SDK 数量: $standard_sdk_count"
ls -1 "$THEOS/sdks/" 2>/dev/null || echo "  (无 SDK)"

echo ""
echo "roothide Theos:"
echo "  路径: $THEOS_ROOTHIDE"
echo "  SDK 数量: $roothide_sdk_count"
ls -1 "$THEOS_ROOTHIDE/sdks/" 2>/dev/null || echo "  (无 SDK)"
echo ""
