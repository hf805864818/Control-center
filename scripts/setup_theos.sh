#!/bin/bash
# setup_theos.sh - 设置 Theos 构建环境（支持 roothide + rootless）
# 安装两个 Theos 版本 + iOS 工具链:
#   /opt/theos          - 标准 Theos (rootless)
#   /opt/theos-roothide - roothide Theos fork

set -euo pipefail

echo "安装构建依赖..."
sudo apt-get update -qq 2>/dev/null || true
sudo apt-get install -y -qq \
    fakeroot rsync perl curl unzip dpkg-dev libtinfo5 xz-utils \
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
# 安装 iOS 工具链 (clang for iOS cross-compilation)
# ============================================
install_toolchain() {
    local theos_path="$1"
    local toolchain_dir="$theos_path/toolchain/linux/iphone"

    if [ -f "$toolchain_dir/bin/clang" ]; then
        echo "  工具链已存在: $toolchain_dir/bin/clang"
        return 0
    fi

    echo "  下载 iOS 工具链到 $toolchain_dir ..."
    mkdir -p "$toolchain_dir"

    # 检测架构
    local arch=$(uname -m)
    local tc_arch="x86_64"
    if [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
        tc_arch="aarch64"
    fi

    # 从 L1ghtmann/llvm-project 下载预编译的 iOS 工具链
    local tc_url="https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-${tc_arch}.tar.xz"
    echo "  下载: $tc_url"
    curl -sL -o /tmp/iostoolchain.tar.xz "$tc_url" 2>/dev/null || true

    if [ -f /tmp/iostoolchain.tar.xz ] && [ -s /tmp/iostoolchain.tar.xz ]; then
        echo "  解压工具链..."
        tar -xf /tmp/iostoolchain.tar.xz -C /tmp/iotc_extract  2>/dev/null || \
        mkdir -p /tmp/iotc_extract && tar -xf /tmp/iostoolchain.tar.xz -C /tmp/iotc_extract 2>/dev/null || true

        # 工具链解压后可能有不同的目录结构, 尝试几种常见路径
        if [ -d /tmp/iotc_extract/toolchain/linux/iphone ]; then
            cp -r /tmp/iotc_extract/toolchain/linux/iphone/* "$toolchain_dir/"
        elif [ -d /tmp/iotc_extract ]; then
            # 直接解压到 toolchain 目录
            cp -r /tmp/iotc_extract/* "$toolchain_dir/" 2>/dev/null || true
        fi
        rm -rf /tmp/iotc_extract /tmp/iostoolchain.tar.xz
    fi

    # 如果 L1ghtmann 下载失败, 尝试 sbingner 的工具链
    if [ ! -f "$toolchain_dir/bin/clang" ]; then
        echo "  尝试备用工具链源 (sbingner)..."
        local alt_url="https://github.com/sbingner/llvm-project/releases/latest/download/linux-ios-arm64e-clang-toolchain.tar.lzma"
        curl -sL -o /tmp/alt_tc.tar.lzma "$alt_url" 2>/dev/null || true
        if [ -f /tmp/alt_tc.tar.lzma ] && [ -s /tmp/alt_tc.tar.lzma ]; then
            tar --lzma -xf /tmp/alt_tc.tar.lzma -C /tmp/alt_extract 2>/dev/null || true
            if [ -d /tmp/alt_extract/ios-arm64e-clang-toolchain ]; then
                cp -r /tmp/alt_extract/ios-arm64e-clang-toolchain/* "$toolchain_dir/"
            elif [ -d /tmp/alt_extract ]; then
                cp -r /tmp/alt_extract/* "$toolchain_dir/" 2>/dev/null || true
            fi
            rm -rf /tmp/alt_extract /tmp/alt_tc.tar.lzma
        fi
    fi

    # 最终验证
    if [ -f "$toolchain_dir/bin/clang" ]; then
        echo "  ✓ 工具链安装成功"
        ls "$toolchain_dir/bin/" | head -5
    else
        echo "  ✗ 工具链安装失败! 尝试从标准 Theos 复制..."
    fi
}

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
# 安装 iOS 工具链 (两个 Theos 都需要)
# ============================================
echo ""
echo "===== 安装 iOS 工具链 ====="
echo "标准 Theos 工具链:"
install_toolchain "$THEOS"

echo "roothide Theos 工具链:"
install_toolchain "$THEOS_ROOTHIDE"

# 如果 roothide 没有工具链但标准有, 复制过去
if [ ! -f "$THEOS_ROOTHIDE/toolchain/linux/iphone/bin/clang" ] && \
   [ -f "$THEOS/toolchain/linux/iphone/bin/clang" ]; then
    echo "从标准 Theos 复制工具链到 roothide Theos..."
    mkdir -p "$THEOS_ROOTHIDE/toolchain/linux"
    cp -r "$THEOS/toolchain/linux/iphone" "$THEOS_ROOTHIDE/toolchain/linux/iphone"
fi

# ============================================
# 下载 iOS SDK (只下载一次, 复制到两个 Theos)
# ============================================
download_sdks() {
    local target_dir="$1"
    mkdir -p "$target_dir"

    local sdk_count=$(find "$target_dir" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
    if [ "$sdk_count" -gt 0 ]; then
        echo "  SDK 已存在 ($sdk_count 个)"
        return 0
    fi

    echo "  下载 iOS SDK 到 $target_dir ..."

    curl -sL -o /tmp/sdks.zip "https://github.com/theos/sdks/archive/refs/heads/master.zip" 2>/dev/null || true
    if [ -f /tmp/sdks.zip ] && [ -s /tmp/sdks.zip ]; then
        unzip -q /tmp/sdks.zip -d /tmp/sdks_extracted 2>/dev/null || true
        if [ -d /tmp/sdks_extracted/sdks-master ]; then
            cp -r /tmp/sdks_extracted/sdks-master/*.sdk "$target_dir/" 2>/dev/null || true
            rm -rf /tmp/sdks_extracted
        fi
        rm -f /tmp/sdks.zip
    fi

    sdk_count=$(find "$target_dir" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
    if [ "$sdk_count" -eq 0 ]; then
        echo "  尝试直接下载 SDK tar.xz ..."
        for sdk_url in \
            "https://github.com/theos/sdks/raw/master/iPhoneOS16.5.sdk.tar.xz" \
            "https://github.com/theos/sdks/raw/master/iPhoneOS15.5.sdk.tar.xz"; do
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

    sdk_count=$(find "$target_dir" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
    if [ "$sdk_count" -gt 0 ]; then
        echo "  ✓ SDK 安装成功 ($sdk_count 个)"
    else
        echo "  ✗ SDK 安装失败!"
    fi
}

echo ""
echo "===== 安装 iOS SDK ====="
echo "标准 Theos SDK:"
download_sdks "$THEOS/sdks"

echo "roothide Theos SDK:"
download_sdks "$THEOS_ROOTHIDE/sdks"

# 如果 roothide 没有 SDK 但标准有, 复制过去
roothide_sdk_count=$(find "$THEOS_ROOTHIDE/sdks" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
standard_sdk_count=$(find "$THEOS/sdks" -maxdepth 1 -name "*.sdk" -type d 2>/dev/null | wc -l)
if [ "$roothide_sdk_count" -eq 0 ] && [ "$standard_sdk_count" -gt 0 ]; then
    echo "从标准 Theos 复制 SDK 到 roothide Theos..."
    cp -r "$THEOS/sdks/"*.sdk "$THEOS_ROOTHIDE/sdks/"
fi

# ============================================
# 验证安装
# ============================================
echo ""
echo "===== Theos 安装验证 ====="
echo "标准 Theos (rootless):"
echo "  路径: $THEOS"
echo "  ldid: $(command -v ldid 2>/dev/null || echo 'not found')"
echo "  工具链: $([ -f "$THEOS/toolchain/linux/iphone/bin/clang" ] && echo '✓ 已安装' || echo '✗ 缺失')"
echo "  SDK 数量: $standard_sdk_count"

echo ""
echo "roothide Theos:"
echo "  路径: $THEOS_ROOTHIDE"
echo "  工具链: $([ -f "$THEOS_ROOTHIDE/toolchain/linux/iphone/bin/clang" ] && echo '✓ 已安装' || echo '✗ 缺失')"
echo "  SDK 数量: $roothide_sdk_count"
echo ""
