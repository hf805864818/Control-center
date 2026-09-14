# 设置 Theos 构建环境（CI 用）
# 用法: source scripts/setup_theos.sh

set -euo pipefail

# 安装依赖
echo "安装构建依赖..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    fakeroot \
    rsync \
    perl \
    curl \
    unzip \
    dpkg-dev \
    libtinfo5 \
    || sudo apt-get install -y -qq fakeroot rsync perl curl unzip dpkg-dev libtinfo5 || true

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

# 设置 THEOS
export THEOS="${THEOS:-/opt/theos}"

# 安装 Theos
if [ ! -d "$THEOS" ]; then
    echo "安装 Theos 到 $THEOS ..."
    sudo mkdir -p "$THEOS"
    sudo chown -R "$(whoami)" "$THEOS"
    git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
fi

# 下载 iOS SDK
if [ ! -d "$THEOS/sdks" ] || [ -z "$(ls -A "$THEOS/sdks" 2>/dev/null)" ]; then
    echo "下载 iOS SDK..."
    mkdir -p "$THEOS/sdks"
    # 尝试从 theos/sdks 仓库下载
    curl -L -o /tmp/sdks.zip "https://github.com/theos/sdks/archive/refs/heads/master.zip" 2>/dev/null || true
    if [ -f /tmp/sdks.zip ] && unzip -l /tmp/sdks.zip 2>/dev/null | grep -q ".sdk"; then
        unzip -q /tmp/sdks.zip -d /tmp/sdks_extracted
        cp -r /tmp/sdks_extracted/sdks-master/*.sdk "$THEOS/sdks/" 2>/dev/null || true
        rm -rf /tmp/sdks_extracted /tmp/sdks.zip
    fi

    # 如果上面的方法失败，尝试直接下载单个 SDK
    if [ -z "$(ls -A "$THEOS/sdks" 2>/dev/null)" ]; then
        echo "尝试备用 SDK 源..."
        curl -L -o /tmp/sdk.tar.xz "https://github.com/theos/sdks/raw/master/iPhoneOS16.5.sdk.tar.xz" 2>/dev/null || true
        if [ -f /tmp/sdk.tar.xz ]; then
            tar -xf /tmp/sdk.tar.xz -C "$THEOS/sdks/"
            rm /tmp/sdk.tar.xz
        fi
    fi
fi

# 验证安装
echo ""
echo "Theos 安装验证:"
echo "  THEOS = $THEOS"
echo "  ldid: $(command -v ldid 2>/dev/null || echo 'not found')"
echo "  SDKs:"
ls -1 "$THEOS/sdks/" 2>/dev/null || echo "  (无 SDK)"
echo ""

export PATH="$THEOS/bin:$THEOS/toolchain/linux/iphone/bin:$PATH"
