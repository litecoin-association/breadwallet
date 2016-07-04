//
//  BRSeedViewController.m
//  BreadWallet
//
//  Created by Aaron Voisine on 6/12/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright © 2016 Litecoin Association <loshan1212@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BRSeedViewController.h"
#import "BRWalletManager.h"
#import "BRPeerManager.h"
#import "NSMutableData+Bitcoin.h"
#import "BREventManager.h"
#import "BRTutorial.h"

#define LABEL_MARGIN       20.0
#define WRITE_TOGGLE_DELAY 15.0
#define IDEO_SP   @"\xE3\x80\x80" // ideographic space (utf-8)

int tapCount = 0;

@interface BRSeedViewController ()

//TODO: create a secure version of UILabel and use it for seedLabel, but make sure there's an accessibility work around
@property (nonatomic, strong) IBOutlet UILabel *seedLabel, *writeLabel;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *remindButton, *doneButton;
@property (nonatomic, strong) IBOutlet UIImageView *wallpaper;

@property (nonatomic, strong) NSString *seedPhrase;
@property (nonatomic, strong) id resignActiveObserver, screenshotObserver;
@property (strong, nonatomic) IBOutlet UIButton *continueButton;
@property (strong, nonatomic) IBOutlet UIView *tutorialView;
@property (strong, nonatomic) BRTutorial *tutorial;

@end


@implementation BRSeedViewController

- (instancetype)customInit
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];

    if (manager.noWallet) {
        self.seedPhrase = [manager generateRandomSeed];
        [[BRPeerManager sharedInstance] connect];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:WALLET_NEEDS_BACKUP_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else self.seedPhrase = manager.seedPhrase; // this triggers authentication request

    if (self.seedPhrase.length > 0) _authSuccess = YES;

    return self;
}

- (instancetype)init
{
    if (! (self = [super init])) return nil;
    return [self customInit];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (! (self = [super initWithCoder:aDecoder])) return nil;
    return [self customInit];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (! (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    return [self customInit];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    if (! [defs boolForKey:WALLET_NEEDS_BACKUP_KEY]) {
        self.continueButton.hidden = YES;
    } else if ([defs boolForKey:WALLET_NEEDS_BACKUP_KEY]) {
        self.continueButton.hidden = NO;
    }
    // Do any additional setup after loading the view.
    
    self.tutorialView.hidden = YES;
    
    self.continueButton.layer.cornerRadius = 2;
    self.continueButton.layer.borderWidth = 2;
    self.continueButton.layer.borderColor = (__bridge CGColorRef _Nullable)([UIColor colorWithRed:40.0 green:40.0 blue:40.0 alpha:0.90]);
    self.continueButton.clipsToBounds = YES;
    
    if (self.navigationController.viewControllers.firstObject != self) {
        self.wallpaper.hidden = YES;
        self.view.backgroundColor = [UIColor clearColor];
    }
    
    self.titleLabel.text = NSLocalizedString(@"Pay", nil);
    self.descriptionLabel.text = NSLocalizedString(@"Easily send Litecoin anywhere in the world with LoafWallet's live currency conversion rates, and QR scanner for quick on-the-go payments.", nil);
    
    [self.progessButton addTarget:self action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
    
    @autoreleasepool {  // @autoreleasepool ensures sensitive data will be dealocated immediately
        if (self.seedPhrase.length > 0 && [self.seedPhrase characterAtIndex:0] > 0x3000) { // ideographic language
            CGRect r;
            NSMutableString *s = CFBridgingRelease(CFStringCreateMutable(SecureAllocator(), 0)),
                            *l = CFBridgingRelease(CFStringCreateMutable(SecureAllocator(), 0));
            
            for (NSString *w in CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(),
                                                  (CFStringRef)self.seedPhrase, CFSTR(" ")))) {
                if (l.length > 0) [l appendString:IDEO_SP];
                [l appendString:w];
                r = [l boundingRectWithSize:CGRectInfinite.size options:NSStringDrawingUsesLineFragmentOrigin
                     attributes:@{NSFontAttributeName:self.seedLabel.font} context:nil];
                
                if (r.size.width + LABEL_MARGIN*2.0 >= self.view.bounds.size.width) {
                    [s appendString:@"\n"];
                    l.string = w;
                }
                else if (s.length > 0) [s appendString:IDEO_SP];
                
                [s appendString:w];
            }

            self.seedLabel.text = s;
        }
        else self.seedLabel.text = self.seedPhrase;

        self.seedPhrase = nil;
    }
    
#if DEBUG
    self.seedLabel.userInteractionEnabled = YES; // allow clipboard copy only for debug builds
#endif
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
 
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    
    [UIView animateWithDuration:0.1 animations:^{
        self.seedLabel.alpha = 1.0;
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (! self.resignActiveObserver) {
        self.resignActiveObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
            object:nil queue:nil usingBlock:^(NSNotification *note) {
                if (self.navigationController.viewControllers.firstObject != self) {
                    [self.navigationController popViewControllerAnimated:NO];
                }
            }];
    }
    
    //TODO: make it easy to create a new wallet and transfer balance
    if (! self.screenshotObserver) {
        self.screenshotObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification
            object:nil queue:nil usingBlock:^(NSNotification *note) {
                if (self.navigationController.viewControllers.firstObject != self) {
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"WARNING", nil)
                      message:NSLocalizedString(@"Screenshots are visible to other apps and devices. "
                                                "Your funds are at risk. Transfer your balance to another wallet.", nil)
                      delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
                }
                else {
                    [[BRWalletManager sharedInstance] setSeedPhrase:nil];
                    [self.navigationController.presentingViewController dismissViewControllerAnimated:NO
                     completion:nil];
                    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
                    
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"WARNING", nil)
                      message:NSLocalizedString(@"Screenshots are visible to other apps and devices. "
                                                "Generate a new recovery phrase and keep it secret.", nil)
                      delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil]
                     show];
                }
            }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // don't leave the seed phrase laying around in memory any longer than necessary
    self.seedLabel.text = @"";
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (self.resignActiveObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.resignActiveObserver];
    self.resignActiveObserver = nil;
    if (self.screenshotObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.screenshotObserver];
    self.screenshotObserver = nil;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (self.resignActiveObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.resignActiveObserver];
    if (self.screenshotObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.screenshotObserver];
}

-(void)tap
{
    tapCount += 1;
    
    if (tapCount == 1) {

        self.titleLabel.text = NSLocalizedString(@"Receive", nil);
        self.descriptionLabel.text = NSLocalizedString(@"Receive Litecoins with your receive address. Share you Litecoin Address with others, and request a payment. Your Litecoin address can be copied to your clipboard, sent via email and shared via other forms of social media.", nil);
    } else if (tapCount == 2) {

        self.titleLabel.text = NSLocalizedString(@"History", nil);
        self.descriptionLabel.text = NSLocalizedString(@"Browse through your transaction history, secured with your passcode. This is not visible to others, unless they possess your LoafWallet passcode. Find indepth details about every transaction.", nil);
        [self.progessButton setTitle:@"→" forState:UIControlStateNormal];
    } else if (tapCount == 3) {
        
        [BREventManager saveEvent:@"seed:toggle_write"];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        
        if ([defs boolForKey:WALLET_NEEDS_BACKUP_KEY]) {
            [defs removeObjectForKey:WALLET_NEEDS_BACKUP_KEY];
        }
        else {
            [defs setBool:YES forKey:WALLET_NEEDS_BACKUP_KEY];
        }
        
        [defs synchronize];
        
        [BREventManager saveEvent:@"seed:dismiss"];
        if (self.navigationController.viewControllers.firstObject != self) return;
        
        self.navigationController.presentingViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self.navigationController.presentingViewController.presentingViewController dismissViewControllerAnimated:YES
                                                                                                        completion:nil];
    }
}

#pragma mark - IBAction

- (IBAction)done:(id)sender
{
    self.tutorialView.hidden = NO;
}

@end
