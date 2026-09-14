#!/bin/bash
# setup_theos.sh - 设置 Theos 构建环境（支持 roothide + rootless）
# 安装两个 Theos 版本:
#   /opt/theos          - 标准 Theos (rootless)
#   /opt/theos-roothide - roothide Theos fork

set -euo pipefail

echo "安装构建依赖..."
sudo apt-get update -qq 2>/dev/null || true
sudo apt-get install -y -qq \
    fakeroot \
    rsync \
    perl \
    curl \
    unzip \
    dpkg-dev \
    libtinfo5 \
    2>/dev/null || true

# 安装 ldid
if ! command -v ldid &> /dev/null; then
    echo "安装 ldid..."
    curl -L -o /tmp/ldid https://github.com/opa334/ldid/releases/latest/download/ldid_linux_x86_64 2>/dev/null || \
    curl -L -o /tmp/ldid https://github.com/opa334/ldid/releases/download/v2.1.5-procursus3/ldid_linux_x86_64 2>/dev/null || true
    if [ -f /tmp/ldid ]; then
        chmod +x /tmp/ldid
        sudo mv /tmp/ldid /usr/local/bin/ldid
    fi
fi

# ============================================
# 安装标准 Theos (rootless)
# ============================================
export THEOS="${THEOS:-/opt/theos}"

if [ ! -d "$THEOS" ] || [ ! -f "$THEOS/makefiles/common.mk" ]; then
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

if [ ! -d "$THEOS_ROOTHIDE" ] || [ ! -f "$THEOS_ROOTHIDE/makefiles/common.mk" ]; then
    echo "安装 roothide Theos 到 $THEOS_ROOTHIDE ..."
    sudo mkdir -p "$THEOS_ROOTHIDE"
    sudo chown -R "$(whoami)" "$THEOS_ROOTHIDE"
    git clone --recursive --depth 1 https://github.com/roothide/Theos.git "$THEOS_ROOTHIDE"
else
    echo "roothide Theos 已安装: $THEOS_ROOTHIDE"
fi

# ============================================
# 下载 iOS SDK (两个 Theos 共享)
# ============================================
install_sdk() {
    local theos_path="$1"
    if [ -d "$theos_path/sdks" ] && [ -n "$(ls -A "$theos_path/sdks" 2>/dev/null)" ]; then
        echo "SDK 已存在于 $theos_path/sdks"
        return 0
    fi

    mkdir -p "$theos_path/sdks"

    # 尝试从 theos/sdks 仓库下载
    echo "下载 iOS SDK 到 $theos_path/sdks ..."
    curl -L -o /tmp/sdks.zip "https://github.com/theos/sdks/archive/refs/heads/master.zip" 2>/dev/null || true
    if [ -f /tmp/sdks.zip ] && unzip -l /tmp/sdks.zip 2>/dev/null | grep -q ".sdk"; then
        unzip -q /tmp/sdks.zip -d /tmp/sdks_extracted 2>/dev/null || true
        cp -r /tmp/sdks_extracted/sdks-master/*.sdk "$theos_path/sdks/" 2>/dev/null || true
        rm -rf /tmp/sdks_extracted /tmp/sdks.zip
    fi

    # 备用源: 直接下载单个 SDK
    if [ -z "$(ls -A "$theos_path/sdks" 2>/dev/null)" ]; then
        echo "尝试备用 SDK 源..."
        curl -L -o /tmp/sdk.tar.xz "https://github.com/theos/sdks/raw/master/iPhoneOS16.5.sdk.tar.xz" 2>/dev/null || true
        if [ -f /tmp/sdk.tar.xz ]; then
            tar -xf /tmp/sdk.tar.xz -C "$theos_path/sdks/"
            rm /tmp/sdk.tar.xz
        fi
    fi
}

install_sdk "$THEOS"

# roothide Theos 可能自带 SDK, 如果没有就从标准 Theos 复制
if [ -z "$(ls -A "$THEOS_ROOTHIDE/sdks" 2>/dev/null)" ]; then
    if [ -n "$(ls -A "$THEOS/sdks" 2>/dev/null)" ]; then
        echo "从标准 Theos 复制 SDK 到 roothide Theos..."
        cp -r "$THEOS/sdks/"* "$THEOS_ROOTHIDE/sdks/" 2>/dev/null || true
    else
        install_sdk "$THEOS_ROOTHIDE"
    fi
fi

# ============================================
# 验证安装
# ============================================
echo ""
echo "===== Theos 安装验证 ====="
echo "标准 Theos (rootless):"
echo "  路径: $THEOS"
echo "  ldid: $(command -v ldid 2>/dev/null || echo 'not found')"
echo "  SDKs:"
ls -1 "$THEOS/sdks/" 2>/dev/null || echo "  (无 SDK)"

echo ""
echo "roothide Theos:"
echo "  路径: $THEOS_ROOTHIDE"
echo "  SDKs:"
ls -1 "$THEOS_ROOTHIDE/sdks/" 2>/dev/null || echo "  (无 SDK)"
echo ""
