
#import "QiBGRunningManager.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>

#ifdef DEBUG
    #define QiDLOG(frmt, ...) NSLog((frmt), ##__VA_ARGS__)
#else
    #define QiDLOG(...)
#endif


@interface QiBGRunningManager() <CLLocationManagerDelegate>

@property (nonatomic, strong) NSTimer *taskTimer;
@property (nonatomic, assign) NSTimeInterval taskStartTime;

@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (nonatomic, strong) CLLocationManager *locationManager;

@end

@implementation QiBGRunningManager

+ (instancetype)instance {
    static QiBGRunningManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[QiBGRunningManager alloc] init];
    });
    return instance;
}

# pragma mark - Register if not explictly call start & stop

- (void)registerAppLifeCycleNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)appWillEnterForeground {
    NSLog(@"%@ appWillEnterForeground", NSStringFromClass([self class]));
    [self stopBackgroundTask];
}

- (void)appDidEnterBackground {
    NSLog(@"%@ appDidEnterBackground", NSStringFromClass([self class]));
    [self startBackgroundTask];
}

# pragma mark - Task start & stop

- (void)stopBackgroundTask {
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid ) {
        [[UIApplication sharedApplication] endBackgroundTask: self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    [self stopTaskTimer];
}

- (void)startBackgroundTask {
    if ([UIApplication sharedApplication].backgroundRefreshStatus != UIBackgroundRefreshStatusAvailable) {
        NSLog(@"Current background refresh not enable in Settings !!!");
        return;
    }
    NSLog(@"Current background task id: %ld", self.backgroundTaskIdentifier);
    
    // Stop previous first
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid ) {
        [[UIApplication sharedApplication] endBackgroundTask: self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask: self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        
        // Will be end soon in 4 seconds, let's apply for more time now
        [self apply4MoreBackgroundTime];
    }];
    NSLog(@"Newest background task id: %ld", self.backgroundTaskIdentifier);
    NSLog(@"Current background task remaining time: %f", [UIApplication sharedApplication].backgroundTimeRemaining);
    
    // Start task timer for checking remaining time or do some custom jobs ...
    [self startTaskTimer];
}

- (void)apply4MoreBackgroundTime {
    if (self.aliveTimeInterval  != 0 && self.aliveTimeInterval < [NSDate date].timeIntervalSince1970 - self.taskStartTime ) {
        NSLog(@"Specified a limit time meet, just return");
        return;
    }
    NSTimeInterval remainTime = [UIApplication sharedApplication].backgroundTimeRemaining;
    if (remainTime >= 0 && remainTime < 30) {
        NSLog(@"Try to apply more background running time: %f", [UIApplication sharedApplication].backgroundTimeRemaining);
        [self startBackgroundTask];
        
        if (self.isUsingLocaionUpadate4KeepAlive) {
            [self startRequestLocation];
        } else {
            [self startPlayAudio];
        }
        
    }
}

#pragma mark - Timer

- (void)startTaskTimer {
    if (self.taskTimer == nil) {
        [self stopTaskTimer];
        self.taskTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector: @selector(doingTask) userInfo:nil repeats:YES];
        self.taskStartTime = [NSDate date].timeIntervalSince1970;
    }
}

- (void)stopTaskTimer {
    if (self.taskTimer != nil) {
        [self.taskTimer invalidate];
        self.taskTimer = nil;
        self.taskStartTime = 0;
    }
}

- (void)doingTask {
    QiDLOG(@"Doing task... Background Remaining Time: %f", [UIApplication sharedApplication].backgroundTimeRemaining);
}

#pragma mark - Audio

- (void)startPlayAudio {
    // 1. Get the audio file
    NSBundle *bundle = [NSBundle bundleForClass:QiBGRunningManager.class]; // [NSBundle bundleWithIdentifier:@"org.cocoapods.QiBackgroundRunning"];
    NSString *assetPath = [bundle pathForResource:@"QiBackgroundRunning" ofType:@"bundle"];
    NSBundle *assetBundle = [NSBundle bundleWithPath:assetPath];
    NSString *wavFilePath = [assetBundle pathForResource:@"Silence" ofType:@"wav"];
    if (wavFilePath == nil) {
        NSLog(@"Error: the silence wav file not existed");
        return;
    }
    NSURL *audioFileURL = [[NSURL alloc] initFileURLWithPath:wavFilePath];
    if (!audioFileURL) {
        NSLog(@"Error: cannot find the silence wav file");
        return;
    }
    
    // 2. Setting the audio session
    AVAudioSessionMode mode = [AVAudioSession sharedInstance].mode;
    AVAudioSessionCategory category = [AVAudioSession sharedInstance].category;
    AVAudioSessionCategoryOptions options = [AVAudioSession sharedInstance].categoryOptions;
    AVAudioSessionRouteSharingPolicy policy = AVAudioSessionRouteSharingPolicyDefault;
    // Important!!! if not set the category correctly, background task will not apply successfully
    NSError *error = nil;
    if (@available(iOS 11.0, *)) {
        policy = [AVAudioSession sharedInstance].routeSharingPolicy;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault routeSharingPolicy:AVAudioSessionRouteSharingPolicyDefault options:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    } else {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    }
    if (error) {
        NSLog(@"Setting the audio session error: %@", error);
    }
    
    // 3. Start the audio
    NSError *mError = nil;
    self.audioPlayer = nil;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileURL error:&mError];
    if (mError) {
        NSLog(@"Alloc the audio player instance error: %@", error);
    }
    self.audioPlayer.volume = 0.0;
    [self.audioPlayer prepareToPlay];
    [self.audioPlayer play];
    [self.audioPlayer stop];
    
    // 4. Reset the audio session
    if (@available(iOS 11.0, *)) {
        [[AVAudioSession sharedInstance] setCategory:category mode:mode routeSharingPolicy:policy options:options error:&error];
    } else {
        [[AVAudioSession sharedInstance] setCategory:category mode:mode options:options error:&error];
    }
    if (error) {
        NSLog(@"Reset the audio session error: %@", error);
    }
}

#pragma mark - Location

- (void)startRequestLocation {
    if (self.isUsingLocaionUpadate4KeepAlive && [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
        // [self.locationManager requestLocation];  // request a single location update  // not working using just one locaion update
        [self.locationManager stopUpdatingLocation];
        [self.locationManager startUpdatingLocation];
    }
}

- (void)requestLocationPermission {
    [self.locationManager requestAlwaysAuthorization];
    [self.locationManager requestWhenInUseAuthorization];
}

- (CLLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.allowsBackgroundLocationUpdates = YES;
    }
    return _locationManager;
}

#pragma mark - Location <CLLocationManagerDelegate>

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    QiDLOG(@"Location update error: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    QiDLOG(@"Location update success: %@", locations);
}

@end
