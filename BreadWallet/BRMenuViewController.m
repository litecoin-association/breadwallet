//
//  BRMenuViewController.m
//  LoafWallet
//
//  Created by Yifei Zhou on 7/21/16.
//  Copyright © 2016 Litecoin Association <loshan1212@gmail.com>
//

#import "BRMenuViewController.h"
#import "BREventManager.h"
#import "BRWalletManager.h"
#import "BRPeerManager.h"
#import "BRRootViewController.h"
#import "UIViewController+BRDrawerViewController.h"

@interface BRMenuViewController () <UITableViewDelegate, UITableViewDataSource>

@property (readonly, nonatomic) NSArray *menuTitles;

@end

@implementation BRMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

#pragma mark - Table View Delegate & DataSources

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 8;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 35.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *menuIdent = @"MenuCell";
    UITableViewCell *cell = nil;
    UILabel *textLabel;
    cell = [tableView dequeueReusableCellWithIdentifier:menuIdent];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:menuIdent];
    }
    
    textLabel = (id)[cell viewWithTag:1];
    textLabel.text = self.menuTitles[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.drawerViewController setPanelShowing:NO animated:YES];
    
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
    switch (indexPath.row) {
        case 0:
            [BREventManager saveEvent:@"settings:import_priv_key"];
            [self scanQR:nil];
            break;
        case 1:
            NSLog(@"row2");
//            [self showRecoveryPhrase];
            break;
        case 2:
            NSLog(@"row3");
            break;
        case 3:
            NSLog(@"row4");
            break;
        case 4:
            [BREventManager saveEvent:@"settings:change_pin"];
            [manager performSelector:@selector(setPin) withObject:nil afterDelay:0.0];
            break;
        case 5:
            NSLog(@"row6");
            break;
        case 6:
            [BREventManager saveEvent:@"settings:rescan"];
            [[BRPeerManager sharedInstance] rescan];
            break;
        case 7:
            NSLog(@"row8");
//            [self showAbout];
            break;
        break;
    }
}

#pragma mark -

- (NSArray *)menuTitles
{
    return @[
             @"Import Private Key",
             @"Export Private Key",
             @"Recovery Phrase",
             @"Local Currency",
             @"Change Passcode",
             @"Recover Wallet",
             @"Re-scan Blockchain",
             @"About"
             ];
}

// MARK: - IBAction

- (IBAction)scanQR:(id)sender {
    //TODO: show scanner in settings rather than dismissing
    [BREventManager saveEvent:@"tx_history:scan_qr"];
    
    UINavigationController *nav = nil;
    UIViewController *mainViewController = self.drawerViewController.mainViewController;
    if ([mainViewController isKindOfClass:[UINavigationController class]]) {
        nav = (id)mainViewController;
    } else {
        nav = (id)self.navigationController.presentingViewController;
    }
    
    nav.view.alpha = 0.0;
    
    [nav dismissViewControllerAnimated:NO completion:^{
        [(id)((BRRootViewController *)nav.viewControllers.firstObject).sendViewController scanQR:nil];
        [UIView animateWithDuration:0.1 delay:1.5 options:0 animations:^{ nav.view.alpha = 1.0; } completion:nil];
    }];
}

@end
