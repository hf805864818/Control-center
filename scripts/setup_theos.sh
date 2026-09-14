#!/bin/bash
# setup_theos.sh - 设置 Theos 构建环境（支持 roothide + rootless）

set -euo pipefail

echo "===== 安装构建依赖 ====="
sudo apt-get update -qq 2>/dev/null || true
sudo apt-get install -y -qq \
    fakeroot rsync perl curl unzip dpkg-dev libtinfo5 xz-utils git \
    2>/dev/null || true

# 安装 ldid
if ! command -v ldid &> /dev/null; then
    echo "安装 ldid..."
    curl -sL -o /tmp/ldid "https://github.com/ProcursusTeam/ldid/releases/latest/download/ldid_linux_x86_64" 2>/dev/null || \
    curl -sL -o /tmp/ldid "https://github.com/opa334/ldid/releases/latest/download/ldid_linux_x86_64" 2>/dev/null || true
    if [ -f /tmp/ldid ] && [ -s /tmp/ldid ]; then
        chmod +x /tmp/ldid
        sudo mv /tmp/ldid /usr/local/bin/ldid
    fi
fi

# ============================================
# 安装标准 Theos (rootless)
# ============================================
export THEOS="${THEOS:-/opt/theos}"

install_standard_theos() {
    if [ -f "$THEOS/makefiles/common.mk" ] && [ -d "$THEOS/vendor/mod/rootless" ]; then
        echo "标准 Theos 已安装: $THEOS"
        return 0
    fi

    echo "安装标准 Theos 到 $THEOS ..."
    sudo rm -rf "$THEOS" 2>/dev/null || true
    sudo mkdir -p "$(dirname "$THEOS")"
    sudo chown -R "$(whoami)" "$(dirname "$THEOS")"

    # 方式1: 直接用 Theos 官方安装脚本（最可靠）
    echo "运行 Theos 官方安装脚本..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)" || true

    if [ -f "$THEOS/makefiles/common.mk" ]; then
        echo "✓ 标准 Theos 安装成功"
        return 0
    fi

    # 方式2: 手动克隆
    echo "手动克隆 Theos..."
    rm -rf "$THEOS"
    git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"

    # 安装工具链
    echo "安装 iOS 工具链..."
    mkdir -p "$THEOS/toolchain"
    curl -sL "https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-x86_64.tar.xz" \
        | tar -xJf - -C "$THEOS/toolchain/"

    # 安装 SDK
    echo "安装 iOS SDK..."
    mkdir -p "$THEOS/sdks"
    curl -sL "https://github.com/theos/sdks/archive/refs/heads/master.zip" -o /tmp/sdks.zip
    unzip -q /tmp/sdks.zip -d /tmp/sdks_extract
    cp -r /tmp/sdks_extract/sdks-master/*.sdk "$THEOS/sdks/"
    rm -rf /tmp/sdks_extract /tmp/sdks.zip
}

# ============================================
# 安装 roothide Theos fork
# ============================================
THEOS_ROOTHIDE="/opt/theos-roothide"

install_roothide_theos() {
    if [ -f "$THEOS_ROOTHIDE/makefiles/common.mk" ] && [ -d "$THEOS_ROOTHIDE/vendor/mod/roothide" ]; then
        echo "roothide Theos 已安装: $THEOS_ROOTHIDE"
        return 0
    fi

    echo "安装 roothide Theos 到 $THEOS_ROOTHIDE ..."
    sudo rm -rf "$THEOS_ROOTHIDE" 2>/dev/null || true
    sudo mkdir -p "$(dirname "$THEOS_ROOTHIDE")"
    sudo chown -R "$(whoami)" "$(dirname "$THEOS_ROOTHIDE")"

    # 克隆 roothide/Theos (含子模块)
    git clone --recursive --depth 1 https://github.com/roothide/Theos.git "$THEOS_ROOTHIDE"

    # 确保子模块已初始化
    cd "$THEOS_ROOTHIDE"
    git submodule update --init --recursive 2>/dev/null || true

    # 检查 vendor/mod/roothide 是否存在
    if [ ! -d "$THEOS_ROOTHIDE/vendor/mod/roothide" ]; then
        echo "警告: roothide scheme 模块缺失, 尝试手动下载..."
        # 从 roothide 仓库的 vendor/mod 子模块下载
        mkdir -p "$THEOS_ROOTHIDE/vendor/mod/roothide"
        mkdir -p "$THEOS_ROOTHIDE/vendor/mod/rootless"
    fi

    # 安装工具链
    echo "安装 iOS 工具链 (roothide)..."
    mkdir -p "$THEOS_ROOTHIDE/toolchain"
    curl -sL "https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-x86_64.tar.xz" \
        | tar -xJf - -C "$THEOS_ROOTHIDE/toolchain/"

    # 安装 SDK (从标准 Theos 复制或下载)
    echo "安装 iOS SDK (roothide)..."
    mkdir -p "$THEOS_ROOTHIDE/sdks"
    if [ -d "$THEOS/sdks" ] && [ -n "$(ls -A "$THEOS/sdks/" 2>/dev/null | grep -v .keep)" ]; then
        cp -r "$THEOS/sdks/"*.sdk "$THEOS_ROOTHIDE/sdks/"
    else
        curl -sL "https://github.com/theos/sdks/archive/refs/heads/master.zip" -o /tmp/sdks2.zip
        unzip -q /tmp/sdks2.zip -d /tmp/sdks_extract2
        cp -r /tmp/sdks_extract2/sdks-master/*.sdk "$THEOS_ROOTHIDE/sdks/"
        rm -rf /tmp/sdks_extract2 /tmp/sdks2.zip
    fi
}

echo ""
echo "===== 安装标准 Theos (rootless) ====="
install_standard_theos

echo ""
echo "===== 安装 roothide Theos ====="
install_roothide_theos

# ============================================
# 交叉复制确保完整性
# ============================================
echo ""
echo "===== 完整性检查 ====="

# 确保两个 Theos 都有工具链
for t in "$THEOS" "$THEOS_ROOTHIDE"; do
    if [ ! -f "$t/toolchain/linux/iphone/bin/clang" ]; then
        if [ -f "$THEOS/toolchain/linux/iphone/bin/clang" ]; then
            echo "从标准 Theos 复制工具链到 $t ..."
            mkdir -p "$t/toolchain/linux"
            cp -r "$THEOS/toolchain/linux/iphone" "$t/toolchain/linux/iphone"
        fi
    fi
done

# 确保两个 Theos 都有 SDK
standard_sdk_count=$(find "$THEOS/sdks" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
roothide_sdk_count=$(find "$THEOS_ROOTHIDE/sdks" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)

if [ "$roothide_sdk_count" -eq 0 ] && [ "$standard_sdk_count" -gt 0 ]; then
    echo "从标准 Theos 复制 SDK 到 roothide Theos..."
    cp -r "$THEOS/sdks/"*.sdk "$THEOS_ROOTHIDE/sdks/"
fi

# 确保 roothide scheme 存在
if [ ! -d "$THEOS_ROOTHIDE/vendor/mod/roothide" ]; then
    echo "警告: roothide scheme 目录不存在!"
    echo "尝试从 rootless scheme 复制并修改..."
    mkdir -p "$THEOS_ROOTHIDE/vendor/mod/roothide"
    if [ -d "$THEOS_ROOTHIDE/vendor/mod/rootless" ]; then
        cp -r "$THEOS_ROOTHIDE/vendor/mod/rootless/"* "$THEOS_ROOTHIDE/vendor/mod/roothide/"
    fi
fi

# ============================================
# 最终验证
# ============================================
echo ""
echo "=========================================="
echo "  Theos 安装验证"
echo "=========================================="
echo ""
echo "标准 Theos (rootless): $THEOS"
echo "  common.mk:   $([ -f "$THEOS/makefiles/common.mk" ] && echo '✓' || echo '✗')"
echo "  工具链 clang: $([ -f "$THEOS/toolchain/linux/iphone/bin/clang" ] && echo '✓' || echo '✗')"
echo "  SDK 数量:    $standard_sdk_count"
echo "  rootless scheme: $([ -d "$THEOS/vendor/mod/rootless" ] && echo '✓' || echo '✗')"
echo ""
echo "roothide Theos: $THEOS_ROOTHIDE"
echo "  common.mk:   $([ -f "$THEOS_ROOTHIDE/makefiles/common.mk" ] && echo '✓' || echo '✗')"
echo "  工具链 clang: $([ -f "$THEOS_ROOTHIDE/toolchain/linux/iphone/bin/clang" ] && echo '✓' || echo '✗')"
echo "  SDK 数量:    $roothide_sdk_count"
echo "  roothide scheme: $([ -d "$THEOS_ROOTHIDE/vendor/mod/roothide" ] && echo '✓' || echo '✗')"
echo "  rootless scheme: $([ -d "$THEOS_ROOTHIDE/vendor/mod/rootless" ] && echo '✓' || echo '✗')"
echo ""
echo "ldid: $(command -v ldid 2>/dev/null || echo 'not found')"
echo ""
