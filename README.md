# CCEnhancer - 液态控制中心

控制中心增强插件，提取自 [Liquid-state](https://github.com/hf805864818/Liquid-state) 项目。

## 功能

- **控制中心自定义背景** - 支持图片、循环视频、毛玻璃效果
- **亮度/音量百分比显示** - 在滑块上方实时显示百分比数值
- **随机颜色** - 百分比文字每次数值变化时切换鲜艳颜色
- **触感反馈** - 滑动时震动反馈，到达 0%/100% 时更强震动
- **快捷开关** - 控制中心内一键开关背景效果

## 兼容性

- iOS 14.0 - 26.x
- 支持 roothide 和 rootless 越狱
- arm64 / arm64e

## 安装

从 [Releases](../../releases) 页面下载对应版本的 `.deb` 文件：
- **roothide** 越狱：下载 `CCEnhancer_vX.X.X_roothide.deb`
- **rootless** 越狱：下载 `CCEnhancer_vX.X.X_rootless.deb`

## 设置

安装后，打开 **设置** App，找到以下两个入口：
- **控制中心背景** - 配置背景图片/视频、毛玻璃强度等
- **滑块增强** - 开关百分比显示、随机颜色、触感反馈

## 构建

### 本地构建

```bash
# 设置 Theos
export THEOS=/opt/theos

# 同时编译 roothide 和 rootless
./scripts/build.sh
```

### 自动构建

每次推送到 `main` 分支时，GitHub Actions 会自动：
1. 递增版本号（patch 级别）
2. 编译 roothide 和 rootless 两个 .deb 包
3. 创建 GitHub Release 并附带两个安装包

## 项目结构

```
CCEnhancer/
├── Makefile              顶层构建（聚合 5 个子项目）
├── control               Debian 包信息
├── VERSION               版本号文件
├── Tweak.x               主 Tweak：滑块百分比 + 随机颜色 + 触感反馈
├── CCEnhancer.plist      MobileSubstrate 过滤器
├── Shared/
│   ├── CCSharedSupport.h  偏好读写 + 视图工具
│   └── CCSharedSupport.m
├── CCBg/                 控制中心自定义背景 Tweak
├── CCBgPrefs/            背景偏好设置 Bundle
├── CCSliderPrefs/        滑块增强偏好设置 Bundle
├── CCToggle/             控制中心快捷开关 Module
├── scripts/
│   ├── bump_version.sh   版本号自动递增
│   ├── build.sh          双架构编译脚本
│   └── setup_theos.sh    Theos 环境安装
└── .github/workflows/
    └── build.yml         GitHub Actions 工作流
```

## 致谢

- 原项目：[Liquid-state](https://github.com/hf805864818/Liquid-state)
- 构建工具：[Theos](https://theos.dev)
