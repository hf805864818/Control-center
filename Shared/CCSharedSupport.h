#pragma once

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Preference domain for CCEnhancer
FOUNDATION_EXPORT NSString * const CCPrefsDomain;
FOUNDATION_EXPORT CFStringRef const CCPrefsChangedNotification;

// Process detection
BOOL CCIsSpringBoardProcess(void);

// Preference reading
BOOL CC_prefBool(NSString *key, BOOL fallback);
CGFloat CC_prefFloat(NSString *key, CGFloat fallback);
NSInteger CC_prefInteger(NSString *key, NSInteger fallback);
NSString *CC_prefString(NSString *key, NSString *fallback);

// Preference reload
void CCReloadPreferences(void);
void CCObservePreferenceChanges(dispatch_block_t block);

// View hierarchy helpers
BOOL CCAncestorNameContains(UIView *v, NSString *sub);
BOOL CCHasAncestorOfClassName(UIView *v, NSString *clsName);
BOOL CCIsExactClass(UIView *v, NSString *name);
