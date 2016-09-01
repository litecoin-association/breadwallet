//
//  BRSettingsViewController.m
//  BreadWallet
//
//  Created by Aaron Voisine on 12/3/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
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

#import "BRSettingsViewController.h"
#import "BRSeedViewController.h"
#import "BRWalletManager.h"
#import "BRBubbleView.h"
#import "BRPeerManager.h"
#import "BREventManager.h"
#import "BRUserDefaultsSwitchCell.h"
#import "breadwallet-Swift.h"
#include <WebKit/WebKit.h>
#include <asl.h>

@interface BRSettingsViewController ()

@property (nonatomic, assign) BOOL touchId;
@property (nonatomic, strong) UITableViewController *selectorController;
@property (nonatomic, strong) NSArray *selectorOptions;
@property (nonatomic, strong) NSString *selectedOption, *noOptionsText;
@property (nonatomic, assign) NSUInteger selectorType;
@property (nonatomic, strong) UISwipeGestureRecognizer *navBarSwipe;
@property (nonatomic, strong) id balanceObserver, txStatusObserver;
@property (nonatomic, strong) BRWebViewController *eaController;

@end


@implementation BRSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.touchId = [BRWalletManager sharedInstance].touchIdEnabled;
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    BRWalletManager *manager = [BRWalletManager sharedInstance];

    if (self.navBarSwipe) [self.navigationController.navigationBar removeGestureRecognizer:self.navBarSwipe];
    self.navBarSwipe = nil;

    // observe the balance change notification to update the balance display
    if (! self.balanceObserver) {
        self.balanceObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:BRWalletBalanceChangedNotification object:nil
            queue:nil usingBlock:^(NSNotification *note) {
                if (self.selectorType == 0) {
                    self.selectorController.title =
                        [NSString stringWithFormat:@"%@ = %@",
                         [manager localCurrencyStringForAmount:SATOSHIS/manager.localCurrencyPrice],
                         [manager stringForAmount:SATOSHIS/manager.localCurrencyPrice]];
                }
            }];
    }

    if (! self.txStatusObserver) {
        self.txStatusObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerTxStatusNotification object:nil
            queue:nil usingBlock:^(NSNotification *note) {
                [(id)[self.navigationController.topViewController.view viewWithTag:412] setText:self.stats];
            }];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.eaController preload];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController || self.navigationController.isBeingDismissed) {
        if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
        self.balanceObserver = nil;
        if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
        self.txStatusObserver = nil;
        
        self.eaController = nil;
    }

    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
}

- (BRWebViewController *)eaController {
    if (_eaController) {
        return _eaController;
    }
    // only available on iOS 8 and above
    if ([WKWebView class] && [[BRAPIClient sharedClient] featureEnabled:BRFeatureFlagsEarlyAccess]) {
#if DEBUG
        _eaController = [[BRWebViewController alloc] initWithBundleName:@"bread-buy-staging" mountPoint:@"/ea"];
        //        self.eaController.debugEndpoint = @"http://localhost:8080";
#else
        _eaController = [[BRWebViewController alloc] initWithBundleName:@"bread-buy" mountPoint:@"/ea"];
#endif
        [_eaController startServer];
    }
    return _eaController;
}

- (UITableViewController *)selectorController
{
    if (_selectorController) return _selectorController;
    _selectorController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    _selectorController.transitioningDelegate = self.navigationController.viewControllers.firstObject;
    _selectorController.tableView.dataSource = self;
    _selectorController.tableView.delegate = self;
    _selectorController.tableView.backgroundColor = [UIColor clearColor];
    return _selectorController;
}

- (void)setBackgroundForCell:(UITableViewCell *)cell tableView:(UITableView *)tableView indexPath:(NSIndexPath *)path
{
    [cell viewWithTag:100].hidden = (path.row > 0);
    [cell viewWithTag:101].hidden = (path.row + 1 < [self tableView:tableView numberOfRowsInSection:path.section]);
}

- (NSString *)stats
{
    static NSDateFormatter *fmt = nil;
    BRWalletManager *manager = [BRWalletManager sharedInstance];

    if (! fmt) {
        fmt = [NSDateFormatter new];
        fmt.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"Mdjma" options:0 locale:[NSLocale currentLocale]];
    }

   return [NSString stringWithFormat:NSLocalizedString(@"rate: %@ = %@\nupdated: %@\nblock #%d of %d\n"
                                                       "connected peers: %d\ndl peer: %@", NULL),
           [manager localCurrencyStringForAmount:SATOSHIS/manager.localCurrencyPrice],
           [manager stringForAmount:SATOSHIS/manager.localCurrencyPrice],
           [fmt stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:manager.secureTime]].lowercaseString,
           [BRPeerManager sharedInstance].lastBlockHeight,
           [BRPeerManager sharedInstance].estimatedBlockHeight,
           [BRPeerManager sharedInstance].peerCount,
           [BRPeerManager sharedInstance].downloadPeerName];
}

#pragma mark - IBAction

- (IBAction)done:(id)sender
{
    [BREventManager saveEvent:@"settings:dismiss"];
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)about:(id)sender
{
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *composeController = [MFMailComposeViewController new];
        NSString *msg;
        struct utsname systemInfo;

        uname(&systemInfo);
        msg = [NSString stringWithFormat:@"%s / iOS %@ / LoafWallet %@ - %@%@\n\n",
               systemInfo.machine, UIDevice.currentDevice.systemVersion,
               NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],
               NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],
               ([BRWalletManager sharedInstance].watchOnly) ? @" (watch only)" : @""];

        composeController.toRecipients = @[@"contact@loafwallet.xyz"];
        composeController.subject = @"support request";
        [composeController setMessageBody:msg isHTML:NO];
        composeController.mailComposeDelegate = self;
        [self.navigationController presentViewController:composeController animated:YES completion:nil];
        composeController.view.backgroundColor =
            [UIColor colorWithPatternImage:[UIImage imageNamed:@"wallpaper-default"]];
        [BREventManager saveEvent:@"about:send_email"];
    }
    else {
        [BREventManager saveEvent:@"about:email_not_configured"];
        [[[UIAlertView alloc] initWithTitle:@"" message:NSLocalizedString(@"email not configured", nil) delegate:nil
          cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
    }
}

#if DEBUG
- (IBAction)copyLogs:(id)sender
{
    [BREventManager saveEvent:@"settings:copy_logs"];
    aslmsg q = asl_new(ASL_TYPE_QUERY), m;
    aslresponse r = asl_search(NULL, q);
    NSMutableString *s = [NSMutableString string];
    time_t t;
    struct tm tm;

    while ((m = asl_next(r))) {
        t = strtol(asl_get(m, ASL_KEY_TIME), NULL, 10);
        localtime_r(&t, &tm);
        [s appendFormat:@"%d-%02d-%02d %02d:%02d:%02d %s: %s\n", tm.tm_year + 1900, tm.tm_mon, tm.tm_mday, tm.tm_hour,
         tm.tm_min, tm.tm_sec, asl_get(m, ASL_KEY_SENDER), asl_get(m, ASL_KEY_MSG)];
    }

    asl_free(r);
    [UIPasteboard generalPasteboard].string = (s.length < 8000000) ? s : [s substringFromIndex:s.length - 8000000];

    [self.navigationController.topViewController.view
     addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"copied", nil)
     center:CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0)] popIn]
     popOutAfterDelay:2.0]];
}
#endif

- (IBAction)touchIdLimit:(id)sender
{
    [BREventManager saveEvent:@"settings:touch_id_limit"];
    BRWalletManager *manager = [BRWalletManager sharedInstance];

    if ([manager authenticateWithPrompt:nil andTouchId:NO]) {
        self.selectorType = 1;
        self.selectorOptions =
            @[NSLocalizedString(@"always require passcode", nil),
              [NSString stringWithFormat:@"%@", [manager stringForAmount:SATOSHIS/10]],
              [NSString stringWithFormat:@"%@", [manager stringForAmount:SATOSHIS]],
              [NSString stringWithFormat:@"%@", [manager stringForAmount:SATOSHIS*10]]];
        if (manager.spendingLimit > SATOSHIS*10) manager.spendingLimit = SATOSHIS*10;
        self.selectedOption = self.selectorOptions[(log10(manager.spendingLimit) < 6) ? 0 :
                                                   (NSUInteger)log10(manager.spendingLimit) - 6];
        self.noOptionsText = nil;
        self.selectorController.title = NSLocalizedString(@"touch id spending limit", nil);
        [self.navigationController pushViewController:self.selectorController animated:YES];
        [self.selectorController.tableView reloadData];
    }
    else [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

- (IBAction)navBarSwipe:(id)sender
{
    [BREventManager saveEvent:@"settings:nav_bar_swipe"];
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSUInteger digits = (((manager.format.maximumFractionDigits - 2)/3 + 1) % 3)*3 + 2;

    manager.format.currencySymbol = [NSString stringWithFormat:@"%@%@" NARROW_NBSP, (digits == 5) ? @"m" : @"",
                                     (digits == 2) ? BITS : BTC];
    manager.format.maximumFractionDigits = digits;
    manager.format.maximum = @(MAX_MONEY/(int64_t)pow(10.0, manager.format.maximumFractionDigits));
    [[NSUserDefaults standardUserDefaults] setInteger:digits forKey:SETTINGS_MAX_DIGITS_KEY];
    manager.localCurrencyCode = manager.localCurrencyCode; // force balance notification
    self.selectorController.title = [NSString stringWithFormat:@"%@ = %@",
                                     [manager localCurrencyStringForAmount:SATOSHIS/manager.localCurrencyPrice],
                                     [manager stringForAmount:SATOSHIS/manager.localCurrencyPrice]];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == self.selectorController.tableView) return 1;
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.selectorController.tableView) return self.selectorOptions.count;

    switch (section) {
        case 0: return 2;
        case 1: return (self.touchId) ? 3 : 2;
        case 2: return 3;
        case 3: return 1;
    }

    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *disclosureIdent = @"DisclosureCell", *restoreIdent = @"RestoreCell", *actionIdent = @"ActionCell",
                    *selectorIdent = @"SelectorCell", *selectorOptionCell = @"SelectorOptionCell";
    UITableViewCell *cell = nil;
    BRWalletManager *manager = [BRWalletManager sharedInstance];

    if (tableView == self.selectorController.tableView) {
        cell = [self.tableView dequeueReusableCellWithIdentifier:selectorOptionCell];
        [self setBackgroundForCell:cell tableView:tableView indexPath:indexPath];
        cell.textLabel.text = self.selectorOptions[indexPath.row];

        if ([self.selectedOption isEqual:self.selectorOptions[indexPath.row]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else cell.accessoryType = UITableViewCellAccessoryNone;

        return cell;
    }

    switch (indexPath.section) {
        case 0:
            cell = [tableView dequeueReusableCellWithIdentifier:disclosureIdent];

            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = NSLocalizedString(@"about", nil);
                    break;

                case 1:
                    cell.textLabel.text = NSLocalizedString(@"recovery phrase", nil);
                    break;
            }

            break;

        case 1:
            switch (indexPath.row) {
                case 0:
                    cell = [tableView dequeueReusableCellWithIdentifier:selectorIdent];
                    cell.detailTextLabel.text = manager.localCurrencyCode;
                    break;

                case 1:
                    if (self.touchId) {
                        cell = [tableView dequeueReusableCellWithIdentifier:selectorIdent];
                        cell.textLabel.text = NSLocalizedString(@"touch id limit", nil);
                        cell.detailTextLabel.text = [manager stringForAmount:manager.spendingLimit];
                    } else {
                        goto _switch_cell;
                    }
                    break;
                case 2:
                {
_switch_cell:
                    cell = [tableView dequeueReusableCellWithIdentifier:@"SwitchCell" forIndexPath:indexPath];
                    BRUserDefaultsSwitchCell *switchCell = (BRUserDefaultsSwitchCell *)cell;
                    switchCell.titleLabel.text = NSLocalizedString(@"enable receive notifications", nil);
                    [switchCell setUserDefaultsKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_KEY];
                    break;
                }

            }

            break;

        case 2:
            switch (indexPath.row) {
                case 0:
                    cell = [tableView dequeueReusableCellWithIdentifier:actionIdent];
                    cell.textLabel.text = NSLocalizedString(@"change passcode", nil);
                    break;

                case 1:
                    cell = [tableView dequeueReusableCellWithIdentifier:restoreIdent];
                    break;

                case 2:
                    cell = [tableView dequeueReusableCellWithIdentifier:actionIdent];
                    cell.textLabel.text = NSLocalizedString(@"rescan blockchain", nil);
                    break;

            }
            break;

        case 3:
            cell = [tableView dequeueReusableCellWithIdentifier:actionIdent];
            cell.textLabel.text = @"early access";

            if (![WKWebView class] || ![[BRAPIClient sharedClient] featureEnabled:BRFeatureFlagsEarlyAccess]) {
                cell = [[UITableViewCell alloc] initWithFrame:CGRectZero];
                cell.userInteractionEnabled = NO;
                cell.hidden = YES;
            }

            break;
    }

    [self setBackgroundForCell:cell tableView:tableView indexPath:indexPath];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (tableView == self.selectorController.tableView && self.selectorOptions.count == 0) return self.noOptionsText;

    switch (section) {
        case 0:
            return nil;

        case 1:
            return nil;

        case 2:
            return nil;

        case 3:
            return NSLocalizedString(@"rescan blockchain if you think you may have missing transactions, "
                                     "or are having trouble sending (rescanning can take several minutes)", nil);
    }

    return nil;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:section];

    if (sectionTitle.length == 0) return 22.0;

    CGRect textRect = [sectionTitle boundingRectWithSize:CGSizeMake(self.view.frame.size.width - 20.0, CGFLOAT_MAX)
                options:NSStringDrawingUsesLineFragmentOrigin
                attributes:@{NSFontAttributeName:[UIFont fontWithName:@"HelveticaNeue" size:13]} context:nil];

    return textRect.size.height + 22.0 + 10.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *sectionHeader = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                         [self tableView:tableView heightForHeaderInSection:section])];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0, 0.0, sectionHeader.frame.size.width - 20.0,
                                                           sectionHeader.frame.size.height - 22.0)];

    titleLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:13];
    titleLabel.textColor = [UIColor grayColor];
    titleLabel.shadowColor = [UIColor whiteColor];
    titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    titleLabel.numberOfLines = 0;
    sectionHeader.backgroundColor = [UIColor clearColor];
    [sectionHeader addSubview:titleLabel];

    return sectionHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return (section + 1 == [self numberOfSectionsInTableView:tableView]) ? 22.0 : 0.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *sectionFooter = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                         [self tableView:tableView heightForFooterInSection:section])];
    sectionFooter.backgroundColor = [UIColor clearColor];
    return sectionFooter;
}

- (void)showAbout
{
    [BREventManager saveEvent:@"settings:show_about"];
    UIViewController *c = [self.storyboard instantiateViewControllerWithIdentifier:@"AboutViewController"];
    UILabel *l = (id)[c.view viewWithTag:411];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithAttributedString:l.attributedText];

#if BITCOIN_TESTNET
    [s replaceCharactersInRange:[s.string rangeOfString:@"%net%"] withString:@"%net% (testnet)"];
#endif
    [s replaceCharactersInRange:[s.string rangeOfString:@"%ver%"]
     withString:[NSString stringWithFormat:@"%@ - %@",
                 NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],
                 NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]]];
    [s replaceCharactersInRange:[s.string rangeOfString:@"%net%"] withString:@""];
    l.attributedText = s;
    [l.superview.gestureRecognizers.firstObject addTarget:self action:@selector(about:)];
#if DEBUG
    {
        UIButton *b = nil;

        b = (id)[c.view viewWithTag:413];
        [b addTarget:self action:@selector(copyLogs:) forControlEvents:UIControlEventTouchUpInside];
        b.hidden = NO;
    }
#endif

    [(id)[c.view viewWithTag:412] setText:self.stats];
    [self.navigationController pushViewController:c animated:YES];
}

- (void)showRecoveryPhrase
{
    [BREventManager saveEvent:@"settings:show_recovery_phrase"];
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"WARNING", nil)
      message:[NSString stringWithFormat:@"\n%@\n\n%@\n\n%@\n",
               [NSLocalizedString(@"\nDO NOT let anyone see your recovery\n"
                                  "phrase or they can spend your bitcoins.\n", nil)
                stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]],
               [NSLocalizedString(@"\nNEVER type your recovery phrase into\n"
                                  "password managers or elsewhere.\n"
                                  "Other devices may be infected.\n", nil)
                stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]],
               [NSLocalizedString(@"\nDO NOT take a screenshot.\n"
                                  "Screenshots are visible to other apps\n"
                                  "and devices.\n", nil)
                stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]]
      delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil)
      otherButtonTitles:NSLocalizedString(@"show", nil), nil] show];
}

- (void)showCurrencySelector
{
    [BREventManager saveEvent:@"settings:show_currency_selector"];
    NSUInteger currencyCodeIndex = 0;
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    double localPrice = manager.localCurrencyPrice;
    NSMutableArray *options;
    self.selectorType = 0;
    options = [NSMutableArray array];

    for (NSString *code in manager.currencyCodes) {
        [options addObject:[NSString stringWithFormat:@"%@", code]];
    }

    self.selectorOptions = options;
    currencyCodeIndex = [manager.currencyCodes indexOfObject:manager.localCurrencyCode];
    if (currencyCodeIndex < options.count) self.selectedOption = options[currencyCodeIndex];
    self.noOptionsText = NSLocalizedString(@"no exchange rate data", nil);
    self.selectorController.title =
        [NSString stringWithFormat:@"%@ = %@",
         [manager localCurrencyStringForAmount:(localPrice > DBL_EPSILON) ? SATOSHIS/localPrice : 0],
         [manager stringForAmount:(localPrice > DBL_EPSILON) ? SATOSHIS/localPrice : 0]];
    [self.navigationController pushViewController:self.selectorController animated:YES];
    [self.selectorController.tableView reloadData];

    if (currencyCodeIndex < options.count) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.selectorController.tableView
             scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:currencyCodeIndex inSection:0]
             atScrollPosition:UITableViewScrollPositionMiddle animated:NO];

            if (! self.navBarSwipe) {
                self.navBarSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                             action:@selector(navBarSwipe:)];
                self.navBarSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
                [self.navigationController.navigationBar addGestureRecognizer:self.navBarSwipe];
            }
        });
    }
}

- (void)showEarlyAccess
{
    [self presentViewController:self.eaController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //TODO: include an option to generate a new wallet and sweep old balance if backup may have been compromized
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSUInteger currencyCodeIndex = 0;

    // if we are showing the local currency selector
    if (tableView == self.selectorController.tableView) {
        currencyCodeIndex = [self.selectorOptions indexOfObject:self.selectedOption];
        if (indexPath.row < self.selectorOptions.count) self.selectedOption = self.selectorOptions[indexPath.row];

        if (self.selectorType == 0) {
            if (indexPath.row < manager.currencyCodes.count) {
                manager.localCurrencyCode = manager.currencyCodes[indexPath.row];
            }
        }
        else manager.spendingLimit = (indexPath.row > 0) ? pow(10, indexPath.row + 6) : 0;

        if (currencyCodeIndex < self.selectorOptions.count && currencyCodeIndex != indexPath.row) {
            [tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:currencyCodeIndex inSection:0], indexPath]
             withRowAnimation:UITableViewRowAnimationAutomatic];
        }

        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self.tableView reloadData];
        return;
    }

    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0: // about
                    [self showAbout];
                    break;

                case 1: // recovery phrase
                    [self showRecoveryPhrase];
                    break;
            }

            break;

        case 1:
            switch (indexPath.row) {
                case 0: // local currency
                    [self showCurrencySelector];

                    break;

                case 1: // touch id spending limit
                    if (self.touchId) {
                        [self performSelector:@selector(touchIdLimit:) withObject:nil afterDelay:0.0];
                        break;
                    } else {
                        goto _deselect_switch;
                    }
                    break;
                case 2:
_deselect_switch:
                    {
                        [tableView deselectRowAtIndexPath:indexPath animated:YES];
                    }
                    break;
            }

            break;

        case 2:
            switch (indexPath.row) {
                case 0: // change passcode
                    [BREventManager saveEvent:@"settings:change_pin"];
                    [tableView deselectRowAtIndexPath:indexPath animated:YES];
                    [manager performSelector:@selector(setPin) withObject:nil afterDelay:0.0];
                    break;

                case 1: // start/recover another wallet (handled by storyboard)
                    [BREventManager saveEvent:@"settings:recover"];
                    break;

                case 2: // rescan blockchain
                    [[BRPeerManager sharedInstance] rescan];
                    [BREventManager saveEvent:@"settings:rescan"];
                    [self done:nil];
                    break;
            }

            break;
        case 3:
            [self showEarlyAccess];
            break;
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result
error:(NSError *)error
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
        return;
    }

    BRSeedViewController *seedController
        = [self.storyboard instantiateViewControllerWithIdentifier:@"SeedViewController"];

    if (seedController.authSuccess) {
        [self.navigationController pushViewController:seedController animated:YES];
    } else {
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    }
}

@end
