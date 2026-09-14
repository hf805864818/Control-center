#import "CCSliderRootListController.h"

#ifndef CC_PACKAGE_VERSION
#define CC_PACKAGE_VERSION @"unknown"
#endif

static NSString * const kCCSliderPrefsDomain = @"dylv.ccenhancer";

@implementation CCSliderRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"滑块增强";
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *specs = [NSMutableArray array];

    // --- 百分比显示 ---
    [specs addObject:@{
        @"cell": @"PSGroupCell",
        @"label": @"百分比显示",
    }];

    [specs addObject:@{
        @"cell": @"PSSwitchCell",
        @"default": @YES,
        @"defaults": kCCSliderPrefsDomain,
        @"key": @"SliderPercent.Enabled",
        @"label": @"显示百分比",
        @"PostNotification": @"dylv.ccenhancer/Reload",
        @"cellClass": @"PSSwitchTableCell",
    }];

    [specs addObject:@{
        @"cell": @"PSSwitchCell",
        @"default": @NO,
        @"defaults": kCCSliderPrefsDomain,
        @"key": @"SliderPercent.RandomColor",
        @"label": @"随机颜色",
        @"PostNotification": @"dylv.ccenhancer/Reload",
        @"cellClass": @"PSSwitchTableCell",
    }];

    [specs addObject:@{
        @"cell": @"PSStaticTextCell",
        @"label": @"在音量和亮度滑块上方显示当前百分比值。开启随机颜色后，百分比文字每次数值变化时切换为不同的鲜艳颜色。",
    }];

    // --- 触感反馈 ---
    [specs addObject:@{
        @"cell": @"PSGroupCell",
        @"label": @"触感反馈",
    }];

    [specs addObject:@{
        @"cell": @"PSSwitchCell",
        @"default": @YES,
        @"defaults": kCCSliderPrefsDomain,
        @"key": @"SliderHaptics.Enabled",
        @"label": @"震动反馈",
        @"PostNotification": @"dylv.ccenhancer/Reload",
        @"cellClass": @"PSSwitchTableCell",
    }];

    [specs addObject:@{
        @"cell": @"PSSwitchCell",
        @"default": @YES,
        @"defaults": kCCSliderPrefsDomain,
        @"key": @"SliderHaptics.EdgeFeedback",
        @"label": @"边缘震动",
        @"PostNotification": @"dylv.ccenhancer/Reload",
        @"cellClass": @"PSSwitchTableCell",
    }];

    [specs addObject:@{
        @"cell": @"PSStaticTextCell",
        @"label": @"滑动亮度/音量滑块时触发触感震动。边缘震动在到达 0% 或 100% 时给予更强反馈。",
    }];

    // --- 关于 ---
    [specs addObject:@{
        @"cell": @"PSGroupCell",
        @"label": @"关于",
    }];

    [specs addObject:@{
        @"cell": @"PSStaticTextCell",
        @"label": [NSString stringWithFormat:@"CCEnhancer v%@",
                   [NSString stringWithUTF8String:[CC_PACKAGE_VERSION UTF8String]] ?: @"unknown"],
    }];

    [specs addObject:@{
        @"cell": @"PSStaticTextCell",
        @"label": @"液态控制中心增强插件\n提取自 Liquid-state 项目\n支持 roothide / rootless",
    }];

    _specifiers = specs;
    return _specifiers;
}

@end
