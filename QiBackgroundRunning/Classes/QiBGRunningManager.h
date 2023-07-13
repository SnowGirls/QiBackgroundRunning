
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QiBGRunningManager : NSObject

+ (instancetype)instance ;

#pragma mark - Using One of the ways: A or B
// A. called in `- (BOOL)application: didFinishLaunchingWithOptions:`
- (void)registerAppLifeCycleNotification ;

// B.1. called in `- (void)applicationDidEnterBackground:`
- (void)startBackgroundTask ;

// B.2. called in `- (void)applicationWillEnterForeground:`
- (void)stopBackgroundTask ;


#pragma mark - Interval for keeping alive in background

@property (assign) NSTimeInterval aliveTimeInterval;


#pragma mark - Using the location updating for Keeping alive

@property (assign) BOOL isUsingLocaionUpadate4KeepAlive;

- (void)requestLocationPermission ;


@end

NS_ASSUME_NONNULL_END
