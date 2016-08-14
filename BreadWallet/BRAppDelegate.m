//
//  BRAppDelegate.m
//  BreadWallet
//
//  Created by Aaron Voisine on 5/8/13.
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

#import "BRAppDelegate.h"
#import "BRPeerManager.h"
#import "BRWalletManager.h"
#import "BREventManager.h"
#import "breadwallet-Swift.h"
#import "BRPhoneWCSessionManager.h"
#import <WebKit/WebKit.h>
#import <PushKit/PushKit.h>

#if BITCOIN_TESTNET
#pragma message "testnet build"
#endif

#if SNAPSHOT
#pragma message "snapshot build"
#endif

@interface BRAppDelegate () <PKPushRegistryDelegate>

// the nsnotificationcenter observer for wallet balance
@property id balanceObserver;

// the most recent balance as received by notification
@property uint64_t balance;

@property PKPushRegistry *pushRegistry;

@end

@implementation BRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

    // use background fetch to stay synced with the blockchain
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    UIPageControl.appearance.pageIndicatorTintColor = [UIColor lightGrayColor];
    UIPageControl.appearance.currentPageIndicatorTintColor = [UIColor blackColor];

    [[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil]
     setTitleTextAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"HelveticaNeue-Light" size:17.0]}
     forState:UIControlStateNormal];

    if (launchOptions[UIApplicationLaunchOptionsURLKey]) {
        NSData *file = [NSData dataWithContentsOfURL:launchOptions[UIApplicationLaunchOptionsURLKey]];

        if (file.length > 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BRFileNotification object:nil
             userInfo:@{@"file":file}];
        }
    }

    // start the event manager
    [[BREventManager sharedEventManager] up];

    //TODO: bitcoin protocol/payment protocol over multipeer connectivity

    //TODO: accessibility for the visually impaired

    //TODO: fast wallet restore using webservice and/or utxo p2p message

    //TODO: ask user if they need to sweep to a new wallet when restoring because it was compromised

    //TODO: figure out deterministic builds/removing app sigs: http://www.afp548.com/2012/06/05/re-signining-ios-apps/

    //TODO: implement importing of private keys split with shamir's secret sharing:
    //      https://github.com/cetuscetus/btctool/blob/bip/bip-xxxx.mediawiki

    [BRPhoneWCSessionManager sharedInstance];
    
    // observe balance and create notifications
    [self setupBalanceNotification:application];
    [self setupPreferenceDefaults];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.balance == UINT64_MAX) self.balance = [BRWalletManager sharedInstance].wallet.balance;
        [self updatePlatform];
        [self registerForPushNotifications];
    });
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    BRAPIClient *client = [BRAPIClient sharedClient];
    [client.kv sync:^(NSError *err) {
        NSLog(@"Finished syncing. err=%@", err);
    }];
}

// Applications may reject specific types of extensions based on the extension point identifier.
// Constants representing common extension point identifiers are provided further down.
// If unimplemented, the default behavior is to allow the extension point identifier.
- (BOOL)application:(UIApplication *)application
shouldAllowExtensionPointIdentifier:(NSString *)extensionPointIdentifier
{
    return NO; // disable extensions such as custom keyboards for security purposes
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
annotation:(id)annotation
{
    if (! [url.scheme isEqual:@"litecoin"] && ! [url.scheme isEqual:@"loaf"]) {
        [[[UIAlertView alloc] initWithTitle:@"Not a bitcoin URL" message:url.absoluteString delegate:nil
          cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return NO;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC/10), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BRURLNotification object:nil userInfo:@{@"url":url}];
    });

    return YES;
}

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    __block id protectedObserver = nil, syncFinishedObserver = nil, syncFailedObserver = nil;
    __block void (^completion)(UIBackgroundFetchResult) = completionHandler;
    void (^cleanup)() = ^() {
        completion = nil;
        if (protectedObserver) [[NSNotificationCenter defaultCenter] removeObserver:protectedObserver];
        if (syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:syncFinishedObserver];
        if (syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:syncFailedObserver];
        protectedObserver = syncFinishedObserver = syncFailedObserver = nil;
    };

    if ([BRPeerManager sharedInstance].syncProgress >= 1.0) {
        NSLog(@"background fetch already synced");
        if (completion) completion(UIBackgroundFetchResultNoData);
        return;
    }

    // timeout after 25 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (completion) {
            NSLog(@"background fetch timeout with progress: %f", [BRPeerManager sharedInstance].syncProgress);
            completion(([BRPeerManager sharedInstance].syncProgress > 0.1) ? UIBackgroundFetchResultNewData :
                       UIBackgroundFetchResultFailed);
            cleanup();
        }
        //TODO: disconnect
    });

    protectedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationProtectedDataDidBecomeAvailable object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            NSLog(@"background fetch protected data available");
            [[BRPeerManager sharedInstance] connect];
        }];

    syncFinishedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerSyncFinishedNotification object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            NSLog(@"background fetch sync finished");
            if (completion) completion(UIBackgroundFetchResultNewData);
            cleanup();
        }];

    syncFailedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerSyncFailedNotification object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            NSLog(@"background fetch sync failed");
            if (completion) completion(UIBackgroundFetchResultFailed);
            cleanup();
        }];

    NSLog(@"background fetch starting");
    [[BRPeerManager sharedInstance] connect];

    // sync events to the server
    [[BREventManager sharedEventManager] sync];
}

- (void)setupBalanceNotification:(UIApplication *)application
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
    self.balance = UINT64_MAX; // this gets set in applicationDidBecomActive:
    
    self.balanceObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:BRWalletBalanceChangedNotification object:nil queue:nil
        usingBlock:^(NSNotification * _Nonnull note) {
            if (self.balance < manager.wallet.balance) {
                BOOL send = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_KEY];
                NSString *noteText = [NSString stringWithFormat:NSLocalizedString(@"received %@", nil),
                                      [manager stringForAmount:manager.wallet.balance - self.balance]];
                
                NSLog(@"local notifications enabled=%d", send);
                
                // send a local notification if in the background
                if (application.applicationState == UIApplicationStateBackground ||
                    application.applicationState == UIApplicationStateInactive) {
                    [UIApplication sharedApplication].applicationIconBadgeNumber =
                        [UIApplication sharedApplication].applicationIconBadgeNumber + 1;
                    
                    if (send) {
                        UILocalNotification *note = [[UILocalNotification alloc] init];
                        
                        note.alertBody = noteText;
                        note.soundName = @"coinflip";
                        [[UIApplication sharedApplication] presentLocalNotificationNow:note];
                        NSLog(@"sent local notification %@", note);
                    }
                }
                
                // send a custom notification to the watch if the watch app is up
                [[BRPhoneWCSessionManager sharedInstance] notifyTransactionString:noteText];
            }
            
            self.balance = manager.wallet.balance;
        }];
}

- (void)setupPreferenceDefaults {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    // turn on local notifications by default
    if (! [defs boolForKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_SWITCH_KEY]) {
        NSLog(@"enabling local notifications by default");
        [defs setBool:true forKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_SWITCH_KEY];
        [defs setBool:true forKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_KEY];
    }
}

- (void)updatePlatform {
    if ([WKWebView class]) { // platform features are only available on iOS 8.0+
        BRAPIClient *client = [BRAPIClient sharedClient];
        
        // set up bundles
#if DEBUG
        NSArray *bundles = @[@"bread-buy-staging"];
#else
        NSArray *bundles = @[@"bread-buy"];
#endif
        [bundles enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [client updateBundle:(NSString *)obj handler:^(NSString * _Nullable error) {
                if (error != nil) {
                    NSLog(@"error updating bundle %@: %@", obj, error);
                } else {
                    NSLog(@"successfully updated bundle %@", obj);
                }
            }];
        }];
        
        // set up feature flags
        [client updateFeatureFlags];
        
        // set up the kv store
        BRKVStoreObject *obj;
        NSError *kvErr = nil;
        // store a sentinel so we can be sure the kv store replication is functioning properly
        obj = [client.kv get:@"sentinel" error:&kvErr];
        if (kvErr != nil) {
            NSLog(@"Error getting sentinel, trying again. err=%@", kvErr);
            obj = [[BRKVStoreObject alloc] initWithKey:@"sentinel" version:0 lastModified:[NSDate date]
                                               deleted:false data:[NSData data]];
        }
        [client.kv set:obj error:&kvErr];
        if (kvErr != nil) {
            NSLog(@"Error setting kv object err=%@", kvErr);
        }
        
        [client.kv sync:^(NSError * _Nullable err) {
            NSLog(@"Finished syncing: error=%@", err);
        }];
    }
}

- (void)registerForPushNotifications {
    BOOL hasNotification = [UIUserNotificationSettings class] != nil;
    NSString *userDefaultsKey = @"has_asked_for_push";
    BOOL hasAskedForPushNotification = [[NSUserDefaults standardUserDefaults] boolForKey:userDefaultsKey];
    
    if (hasAskedForPushNotification && hasNotification && !self.pushRegistry) {
        self.pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        self.pushRegistry.delegate = self;
        self.pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
        
        UIUserNotificationType types = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge
                                        | UIUserNotificationTypeSound);
        UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings
                                                            settingsForTypes:types categories:nil];
        
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    }
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier
  completionHandler:(void (^)())completionHandler
{
    NSLog(@"Handle events for background url session; identifier=%@", identifier);
}

- (void)dealloc
{
    if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
}

#pragma mark PKPushRegistry

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials
             forType:(NSString *)type
{
#if DEBUG
    NSString *svcType = @"d"; // push notification environment "development"
#else
    NSString *svcType = @"p"; // ^ "production"
#endif
    
    NSLog(@"Push registry did update push credentials: %@", credentials);
    BRAPIClient *client = [BRAPIClient sharedClient];
    [client savePushNotificationToken:credentials.token pushNotificationType:svcType];
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type
{
    NSLog(@"Push registry did invalidate push token for type: %@", type);
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
             forType:(NSString *)type
{
    NSLog(@"Push registry received push payload: %@ type: %@", payload, type);
}

@end
