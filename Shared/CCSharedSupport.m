#import "CCSharedSupport.h"
#import <objc/runtime.h>
#import <os/lock.h>
#import <notify.h>

NSString * const CCPrefsDomain = @"dylv.ccenhancer";
CFStringRef const CCPrefsChangedNotification = CFSTR("dylv.ccenhancer/Reload");

static NSString * const sCCInProcessReloadNotification = @"dylv.ccenhancer.InProcessReload";

static NSDictionary<NSString *, id> *sCCCachedPreferences = nil;
static os_unfair_lock sCCPrefsLock = OS_UNFAIR_LOCK_INIT;
static dispatch_once_t sCCPrefsSetupOnce;

// --- Preference cache ---

static NSDictionary<NSString *, id> *CCCopyPreferencesDictionary(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)CCPrefsDomain);
    CFDictionaryRef values = CFPreferencesCopyMultiple(NULL,
                                                       (__bridge CFStringRef)CCPrefsDomain,
                                                       kCFPreferencesCurrentUser,
                                                       kCFPreferencesAnyHost);
    NSDictionary *dictionary = CFBridgingRelease(values);
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return @{};
    }
    return dictionary;
}

static void CCPreferencesChanged(CFNotificationCenterRef center,
                                 void *observer,
                                 CFStringRef name,
                                 const void *object,
                                 CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        CCReloadPreferences();
        [[NSNotificationCenter defaultCenter] postNotificationName:sCCInProcessReloadNotification object:nil];
    });
}

static void CCIEnsurePreferenceCacheInitialized(void) {
    dispatch_once(&sCCPrefsSetupOnce, ^{
        CCReloadPreferences();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        CCPreferencesChanged,
                                        CCPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}

void CCReloadPreferences(void) {
    NSDictionary<NSString *, id> *dictionary = CCCopyPreferencesDictionary();
    os_unfair_lock_lock(&sCCPrefsLock);
    sCCCachedPreferences = dictionary;
    os_unfair_lock_unlock(&sCCPrefsLock);
}

void CCObservePreferenceChanges(dispatch_block_t block) {
    if (!block) return;
    [[NSNotificationCenter defaultCenter] addObserverForName:sCCInProcessReloadNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        block();
    }];
}

static id CCPreferenceValue(NSString *key) {
    if (!key.length) return nil;
    CCIEnsurePreferenceCacheInitialized();
    os_unfair_lock_lock(&sCCPrefsLock);
    NSDictionary *prefs = sCCCachedPreferences;
    os_unfair_lock_unlock(&sCCPrefsLock);
    return prefs[key];
}

// --- Preference readers ---

BOOL CC_prefBool(NSString *key, BOOL fallback) {
    id value = CCPreferenceValue(key);
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    return fallback;
}

CGFloat CC_prefFloat(NSString *key, CGFloat fallback) {
    id value = CCPreferenceValue(key);
    if ([value isKindOfClass:[NSNumber class]]) return (CGFloat)[value doubleValue];
    return fallback;
}

NSInteger CC_prefInteger(NSString *key, NSInteger fallback) {
    id value = CCPreferenceValue(key);
    if ([value isKindOfClass:[NSNumber class]]) return [value integerValue];
    return fallback;
}

NSString *CC_prefString(NSString *key, NSString *fallback) {
    id value = CCPreferenceValue(key);
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    return fallback;
}

// --- Process detection ---

BOOL CCIsSpringBoardProcess(void) {
    static BOOL cached;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cached = [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"];
    });
    return cached;
}

// --- View hierarchy helpers ---

BOOL CCAncestorNameContains(UIView *v, NSString *sub) {
    for (UIView *cur = v; cur; cur = cur.superview)
        if ([NSStringFromClass(cur.class) containsString:sub]) return YES;
    return NO;
}

BOOL CCHasAncestorOfClassName(UIView *v, NSString *clsName) {
    Class cls = NSClassFromString(clsName);
    if (!cls) return NO;
    for (UIView *cur = v; cur; cur = cur.superview)
        if ([cur isKindOfClass:cls]) return YES;
    return NO;
}

BOOL CCIsExactClass(UIView *v, NSString *name) {
    return v && [NSStringFromClass(v.class) isEqualToString:name];
}
