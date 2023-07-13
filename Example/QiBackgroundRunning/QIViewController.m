
#import "QIViewController.h"
#import "QiBGRunningManager.h"


@interface QIViewController ()

@property (assign) int taskSequenceId;

@property (strong) UILabel *countLabel;

@end

@implementation QIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // request permissions
    [QiBGRunningManager.instance requestLocationPermission];

    // count label
    UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    [countLabel setTextColor:[UIColor blackColor]];
    [self.view addSubview:countLabel];
    self.countLabel = countLabel;
    
    // start task
    [self startTask];
//    [self doTask];
}

#pragma mark -

- (void)startTask {
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(doTask) object:nil];
    [thread setName:@"DaddyThread"];
    [thread start];
}

- (void)doTask {
    if ([NSThread isMainThread]) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doTask) object:nil];
        [self updateText];
        [self performSelector:@selector(doTask) withObject:nil afterDelay:1];
        return;
    }
    while (true) {
        [NSThread sleepForTimeInterval:1];
        [self updateText];
    }
}

- (void)updateText {
    self.taskSequenceId++;
    // NSLog(@"[%@] ------->>> TASK: %d", [[NSThread currentThread] name], self.taskSequenceId);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.countLabel.text = [NSString stringWithFormat:@"%d", self.taskSequenceId];
    });
}

@end
