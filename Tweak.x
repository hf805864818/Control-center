// CCEnhancer - 液态控制中心增强
// 功能: 亮度/音量百分比显示 + 随机颜色 + 触感反馈 + 自定义背景
// 版本号通过编译宏 CC_PACKAGE_VERSION 注入

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import "Shared/CCSharedSupport.h"

#ifndef CC_PACKAGE_VERSION
#define CC_PACKAGE_VERSION @"unknown"
#endif

__attribute__((unused))
static NSString *ccGetVersionString(void) {
    static NSString *version = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        version = [NSString stringWithUTF8String:[CC_PACKAGE_VERSION UTF8String]] ?: @"unknown";
    });
    return version;
}

#pragma mark - Slider Percentage Display

static const void *kCCSliderPercentLabelKey = &kCCSliderPercentLabelKey;

static BOOL ccSliderPercentEnabled(void) {
    return CC_prefBool(@"SliderPercent.Enabled", YES);
}

static BOOL ccSliderRandomColorEnabled(void) {
    return CC_prefBool(@"SliderPercent.RandomColor", NO);
}

// 预定义的鲜艳色板,确保可读性
static NSArray<UIColor *> *ccVibrantColorPalette(void) {
    static NSArray *palette = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        palette = @[
            [UIColor colorWithRed:1.00 green:0.27 blue:0.27 alpha:1.0], // 红
            [UIColor colorWithRed:1.00 green:0.60 blue:0.20 alpha:1.0], // 橙
            [UIColor colorWithRed:1.00 green:0.83 blue:0.20 alpha:1.0], // 金黄
            [UIColor colorWithRed:0.30 green:0.85 blue:0.39 alpha:1.0], // 绿
            [UIColor colorWithRed:0.20 green:0.68 blue:1.00 alpha:1.0], // 天蓝
            [UIColor colorWithRed:0.39 green:0.62 blue:1.00 alpha:1.0], // 蓝
            [UIColor colorWithRed:0.68 green:0.40 blue:1.00 alpha:1.0], // 紫
            [UIColor colorWithRed:1.00 green:0.35 blue:0.79 alpha:1.0], // 粉
            [UIColor colorWithRed:0.00 green:0.97 blue:0.93 alpha:1.0], // 青
            [UIColor colorWithRed:1.00 green:0.58 blue:0.98 alpha:1.0], // 粉紫
        ];
    });
    return palette;
}

static UIColor *ccPickRandomPaletteColor(void) {
    NSArray *palette = ccVibrantColorPalette();
    return palette[arc4random_uniform((uint32_t)palette.count)];
}

static UILabel *ccSliderGetOrCreatePercentLabel(UIView *slider) {
    UILabel *label = objc_getAssociatedObject(slider, kCCSliderPercentLabelKey);
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = [UIColor clearColor];
        // Subtle shadow for readability on any background
        label.layer.shadowColor = [UIColor blackColor].CGColor;
        label.layer.shadowOffset = CGSizeMake(0, 1);
        label.layer.shadowRadius = 2.0;
        label.layer.shadowOpacity = 0.6;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.hidden = YES;
        [slider addSubview:label];
        objc_setAssociatedObject(slider, kCCSliderPercentLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return label;
}

// 用 KVC 获取滑块百分比值
static CGFloat ccSliderGetNormalizedValue(UIView *slider) {
    if (!slider) return 0.5;
    for (NSString *key in @[@"value", @"_value", @"normalizedValue", @"_normalizedValue",
                            @"sliderValue", @"_sliderValue", @"continuousValue",
                            @"_continuousValue", @"rawValue", @"_rawValue",
                            @"representedValue", @"_representedValue"]) {
        @try {
            id val = [slider valueForKey:key];
            if ([val isKindOfClass:[NSNumber class]]) {
                CGFloat v = [val floatValue];
                if (v >= 0.0 && v <= 1.0) return v;
                if (v > 1.0 && v <= 100.0) return v / 100.0;
            }
        } @catch (__unused NSException *e) {}
    }
    return 0.5;
}

static void *kCCSliderLastColorPercentKey = &kCCSliderLastColorPercentKey;

static void ccSliderUpdatePercentLabel(UIView *slider) {
    if (!ccSliderPercentEnabled()) {
        UILabel *label = objc_getAssociatedObject(slider, kCCSliderPercentLabelKey);
        if (label) label.hidden = YES;
        return;
    }
    CGFloat value = ccSliderGetNormalizedValue(slider);
    NSInteger percent = (NSInteger)round(value * 100.0);
    UILabel *label = ccSliderGetOrCreatePercentLabel(slider);
    NSString *percentText = [NSString stringWithFormat:@"%ld%%", (long)percent];
    label.text = percentText;
    label.hidden = NO;

    // 随机颜色: 百分比值变化时换一个新颜色, 平滑过渡
    if (ccSliderRandomColorEnabled()) {
        NSString *lastPercent = objc_getAssociatedObject(slider, kCCSliderLastColorPercentKey);
        if (lastPercent && ![percentText isEqualToString:lastPercent]) {
            // 百分比变了 → 换新颜色, 带平滑动画
            UIColor *newColor = ccPickRandomPaletteColor();
            // 确保不和上一个颜色重复
            if ([newColor isEqual:label.textColor]) {
                newColor = ccPickRandomPaletteColor();
            }
            [UIView animateWithDuration:0.3
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                label.textColor = newColor;
            } completion:nil];
        } else if (!lastPercent) {
            // 首次显示: 直接设随机色
            label.textColor = ccPickRandomPaletteColor();
        }
        objc_setAssociatedObject(slider, kCCSliderLastColorPercentKey,
                                 percentText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        // 随机颜色关闭: 恢复白色
        if (![label.textColor isEqual:[UIColor whiteColor]]) {
            [UIView animateWithDuration:0.2 animations:^{
                label.textColor = [UIColor whiteColor];
            }];
        }
    }

    // Size to fit text
    [label sizeToFit];
    CGFloat labelWidth = CGRectGetWidth(label.bounds) + 4;
    CGFloat labelHeight = CGRectGetHeight(label.bounds) + 2;
    CGFloat sliderWidth = CGRectGetWidth(slider.bounds);
    CGFloat sliderHeight = CGRectGetHeight(slider.bounds);

    // Center the label. Apply a small right offset only for the fine/narrow
    // volume HUD slider — the extremely thin vertical slider used in precise
    // volume mode. We distinguish it by aspect ratio (width << height) rather
    // than absolute width, since both wide and narrow volume HUD sliders can
    // be under 120pt. Control Center sliders and wide volume HUD stay centered.
    BOOL isVolumeHUD = CCAncestorNameContains(slider, @"SBElastic");
    CGFloat aspectRatio = sliderHeight > 0.0 ? sliderWidth / sliderHeight : 1.0;
    CGFloat rightOffset = (isVolumeHUD && aspectRatio < 0.25) ? 10.0 : 0.0;
    CGFloat labelX = (sliderWidth - labelWidth) / 2.0 + rightOffset;
    CGFloat labelY = (sliderHeight - labelHeight) / 2.0;
    label.frame = CGRectMake(labelX, labelY, labelWidth, labelHeight);
}

#pragma mark - Slider Haptic Feedback

static const void *kCCSliderHapticFeedbackKey = &kCCSliderHapticFeedbackKey;
static const void *kCCSliderLastPercentTextKey = &kCCSliderLastPercentTextKey;

static BOOL ccSliderHapticsEnabled(void) {
    return CC_prefBool(@"SliderHaptics.Enabled", YES);
}

static CGFloat ccSliderHapticIntensity(void) {
    return CC_prefFloat(@"SliderHaptics.Intensity", 0.6);
}

static BOOL ccSliderEdgeFeedbackEnabled(void) {
    return CC_prefBool(@"SliderHaptics.EdgeFeedback", YES);
}

static UIImpactFeedbackGenerator *ccSliderHapticGenerator(UIView *slider) {
    UIImpactFeedbackGenerator *gen = objc_getAssociatedObject(slider, kCCSliderHapticFeedbackKey);
    if (!gen) {
        gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        objc_setAssociatedObject(slider, kCCSliderHapticFeedbackKey, gen, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [gen prepare];
    return gen;
}

static void ccSliderTriggerHaptic(UIView *slider, BOOL isEdge) {
    if (!ccSliderHapticsEnabled()) return;

    CGFloat intensity = ccSliderHapticIntensity();

    if (isEdge && ccSliderEdgeFeedbackEnabled()) {
        UIImpactFeedbackGenerator *gen = ccSliderHapticGenerator(slider);
        [gen impactOccurredWithIntensity:MIN(1.0, intensity * 1.5)];
    } else if (!isEdge) {
        UIImpactFeedbackGenerator *gen = ccSliderHapticGenerator(slider);
        [gen impactOccurredWithIntensity:MAX(0.15, intensity)];
    }
}

// 追踪百分比标签文本变化 - 文本每变一次就震一次
static void ccSliderUpdateHapticState(UIView *slider) {
    if (!ccSliderHapticsEnabled()) return;

    // 读取百分比标签的当前文本
    UILabel *label = objc_getAssociatedObject(slider, kCCSliderPercentLabelKey);
    if (!label) return;
    NSString *currentText = label.text ?: @"";

    // 获取上次记录的百分比文本
    NSString *lastText = objc_getAssociatedObject(slider, kCCSliderLastPercentTextKey);

    // 文本变化了 → 触发震动
    if (lastText && ![currentText isEqualToString:lastText]) {
        // 判断是否到达边缘
        NSInteger percent = 0;
        NSScanner *scanner = [NSScanner scannerWithString:currentText];
        [scanner scanInteger:&percent];

        if (percent <= 1 || percent >= 99) {
            // 边缘: 稍强震动
            ccSliderTriggerHaptic(slider, YES);
        } else {
            // 中间: 轻震动, 每次百分比变化都震
            ccSliderTriggerHaptic(slider, NO);
        }
    }

    // 记录当前百分比文本
    objc_setAssociatedObject(slider, kCCSliderLastPercentTextKey, currentText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Display Link for Real-Time Slider Value Polling

static const void *kCCSliderDisplayLinkKey = &kCCSliderDisplayLinkKey;

@interface CCEnhancerDisplayLinkTarget : NSObject
+ (void)tick:(CADisplayLink *)link;
@end

@implementation CCEnhancerDisplayLinkTarget
+ (void)tick:(CADisplayLink *)link {
    UIView *slider = objc_getAssociatedObject(link, kCCSliderDisplayLinkKey);
    if (!slider || !slider.window) {
        [link invalidate];
        return;
    }
    ccSliderUpdateHapticState(slider);
    ccSliderUpdatePercentLabel(slider);
}
@end

static void ccSliderUpdateAll(UIView *slider) {
    ccSliderUpdateHapticState(slider);
    ccSliderUpdatePercentLabel(slider);
}

static void ccSliderStartDisplayLink(UIView *slider) {
    CADisplayLink *existing = objc_getAssociatedObject(slider, kCCSliderDisplayLinkKey);
    if (existing && !existing.isPaused) return;
    [existing invalidate];

    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:[CCEnhancerDisplayLinkTarget class]
                                                      selector:@selector(tick:)];
    objc_setAssociatedObject(link, kCCSliderDisplayLinkKey, slider, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, kCCSliderDisplayLinkKey, link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // 【修复卡死】从 30fps 降到 10fps，大幅减少主线程负载
    // 滑块百分比只需 ~10fps 就足够流畅显示，30fps 会叠加多个滑块时拖慢主线程
    link.preferredFramesPerSecond = 10;
    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

static void ccSliderStopDisplayLink(UIView *slider) {
    CADisplayLink *link = objc_getAssociatedObject(slider, kCCSliderDisplayLinkKey);
    if (link) {
        [link invalidate];
        objc_setAssociatedObject(slider, kCCSliderDisplayLinkKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - Hooks

// 控制中心滑块 (CCUIContinuousSliderView)
%hook CCUIContinuousSliderView
- (void)layoutSubviews {
    %orig;
    ccSliderUpdateAll((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    ccSliderUpdatePercentLabel((UIView *)self);
    if ([(UIView *)self window]) {
        // 【修复卡死】仅在触摸时启动 DisplayLink，不在 didMoveToWindow 时持续运行
        // layoutSubviews 已经会在每次布局时更新百分比，无需 30fps 持续轮询
    } else {
        ccSliderStopDisplayLink((UIView *)self);
    }
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderStartDisplayLink((UIView *)self);
    ccSliderUpdateAll((UIView *)self);
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderUpdateAll((UIView *)self);
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderUpdateAll((UIView *)self);
    // 【修复卡死】触摸结束后立即停止 DisplayLink，避免持续消耗 CPU
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
        if (![(UIControl *)self isTracking]) {
            ccSliderStopDisplayLink((UIView *)self);
        }
    });
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderUpdateAll((UIView *)self);
    // 【修复卡死】触摸取消后立即停止 DisplayLink
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
        ccSliderStopDisplayLink((UIView *)self);
    });
}
- (void)dealloc {
    ccSliderStopDisplayLink((UIView *)self);
    %orig;
}
%end

// 音量 HUD 滑块 (MRUContinuousSliderView)
%hook MRUContinuousSliderView
- (void)layoutSubviews {
    %orig;
    ccSliderUpdateAll((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    ccSliderUpdatePercentLabel((UIView *)self);
    if ([(UIView *)self window]) {
        // 【修复卡死】同上，不在 didMoveToWindow 持续运行 DisplayLink
    } else {
        ccSliderStopDisplayLink((UIView *)self);
    }
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderStartDisplayLink((UIView *)self);
    ccSliderUpdateAll((UIView *)self);
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderUpdateAll((UIView *)self);
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderUpdateAll((UIView *)self);
    if (![(UIView *)self window]) {
        ccSliderStopDisplayLink((UIView *)self);
    } else {
        // 【修复卡死】延迟停止，避免持续运行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                        dispatch_get_main_queue(), ^{
            if (![(UIControl *)self isTracking]) {
                ccSliderStopDisplayLink((UIView *)self);
            }
        });
    }
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    ccSliderUpdateAll((UIView *)self);
    if (![(UIView *)self window]) {
        ccSliderStopDisplayLink((UIView *)self);
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                        dispatch_get_main_queue(), ^{
            ccSliderStopDisplayLink((UIView *)self);
        });
    }
}
- (void)dealloc {
    ccSliderStopDisplayLink((UIView *)self);
    %orig;
}
%end

#pragma mark - Constructor

%ctor {
    if (!CCIsSpringBoardProcess()) return;

    CCObservePreferenceChanges(^{
        // 偏好设置变更时, 下一次 layoutSubviews 会自动更新
    });
}
