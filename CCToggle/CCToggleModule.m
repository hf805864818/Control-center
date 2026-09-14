// CCEnhancer Control Center Quick Toggle
// CCModule bundle for toggling CC background from Control Center

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>

// Forward declarations for CCUI protocols
@protocol CCUIContentModuleContentViewController <NSObject>
@optional
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) CGSize preferredContentSize;
- (void)viewWillTransitionToSize:(CGSize)arg1 withTransitionCoordinator:(id)arg2;
@end

@protocol CCUIContentModule <NSObject>
@required
@property (nonatomic, readonly) UIViewController<CCUIContentModuleContentViewController> *contentViewController;
@optional
@property (nonatomic, readonly) UIViewController *backgroundViewController;
- (void)setContentModuleContext:(id)context;
@end

// CCBg preference domain
static NSString * const kCCBgPrefsDomain = @"dylv.Deepliquid.ccbg";

@interface CCToggleContentViewController : UIViewController <CCUIContentModuleContentViewController>
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign) BOOL isBgEnabled;
- (void)refreshState;
- (void)toggleTapped;
@end

@implementation CCToggleContentViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];
    self.view.clipsToBounds = YES;
    self.view.layer.cornerRadius = 22.0;

    // Create toggle button
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleButton.frame = self.view.bounds;
    self.toggleButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.toggleButton addTarget:self
                          action:@selector(toggleTapped)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.toggleButton];

    // Create icon view
    self.iconView = [[UIImageView alloc] init];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.tintColor = [UIColor whiteColor];
    [self.toggleButton addSubview:self.iconView];

    // Draw icon
    [self updateIcon];

    // Refresh state
    [self refreshState];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat iconSize = MIN(CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds)) * 0.6;
    self.iconView.frame = CGRectMake((CGRectGetWidth(self.view.bounds) - iconSize) / 2,
                                     (CGRectGetHeight(self.view.bounds) - iconSize) / 2,
                                     iconSize, iconSize);
}

- (CGSize)preferredContentSize {
    return CGSizeMake(44, 44);
}

- (void)updateIcon {
    // Draw a simple background/image icon
    CGSize iconSize = CGSizeMake(40, 40);
    UIGraphicsBeginImageContextWithOptions(iconSize, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Rounded rect shape (representing background)
    CGRect rect = CGRectMake(4, 4, 32, 32);
    UIBezierPath *bgPath = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:8];
    CGContextAddPath(ctx, bgPath.CGPath);
    CGContextClip(ctx);

    // Gradient fill
    CGFloat colors[] = {
        1.0, 1.0, 1.0, 0.9,
        0.8, 0.9, 1.0, 0.7,
    };
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
    CGContextDrawLinearGradient(ctx, gradient,
                                CGPointMake(0, 0),
                                CGPointMake(0, 40),
                                0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    // Highlight
    UIBezierPath *highlightPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10, 6, 10, 14)];
    [[UIColor colorWithWhite:1.0 alpha:0.6] setFill];
    [highlightPath fill];

    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    self.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)refreshState {
    // Read current CC background enabled state
    CFBooleanRef enabled = CFPreferencesCopyAppValue(CFSTR("FullscreenBgEnabled"),
                                                      (__bridge CFStringRef)kCCBgPrefsDomain);
    self.isBgEnabled = (enabled && CFBooleanGetValue(enabled));
    if (enabled) CFRelease(enabled);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isBgEnabled) {
            self.view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
            self.iconView.tintColor = [UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0];
        } else {
            self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
            self.iconView.tintColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        }
        self.iconView.alpha = 1.0;
    });
}

- (void)toggleTapped {
    self.isBgEnabled = !self.isBgEnabled;

    // Write new state to preferences
    CFPreferencesSetAppValue(CFSTR("FullscreenBgEnabled"),
                             self.isBgEnabled ? kCFBooleanTrue : kCFBooleanFalse,
                             (__bridge CFStringRef)kCCBgPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kCCBgPrefsDomain);

    // Notify CCBg tweak to reload
    notify_post("dylv.Deepliquid.ccbg.reload");

    // Update UI
    [self refreshState];

    // Haptic feedback
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator impactOccurred];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@interface CCToggleModule : NSObject <CCUIContentModule>
@property (nonatomic, strong) CCToggleContentViewController *contentViewController;
@property (nonatomic, strong) id contentModuleContext;
@end

@implementation CCToggleModule

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)setContentModuleContext:(id)context {
    _contentModuleContext = context;
}

- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController {
    if (!_contentViewController) {
        _contentViewController = [[CCToggleContentViewController alloc] init];
    }
    return _contentViewController;
}

- (UIViewController *)backgroundViewController {
    return nil;
}

@end
