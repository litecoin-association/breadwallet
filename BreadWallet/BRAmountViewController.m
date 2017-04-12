//
//  BRAmountViewController.m
//  BreadWallet
//
//  Created by Aaron Voisine on 6/4/13.
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

#import "BRAmountViewController.h"
#import "BRPaymentRequest.h"
#import "BRWalletManager.h"
#import "BRPeerManager.h"
#import "BRTransaction.h"
#import "BREventManager.h"

@interface BRAmountViewController ()

@property (nonatomic, strong) IBOutlet UITextField *amountField, *memoField;
@property (nonatomic, strong) IBOutlet UILabel *localCurrencyLabel;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *payButton, *lock;
@property (nonatomic, strong) IBOutlet UIButton *delButton, *decimalButton;
@property (nonatomic, strong) IBOutlet UIImageView *wallpaper;
@property (nonatomic, strong) IBOutlet UIView *logo;

@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, strong) NSCharacterSet *charset;
@property (nonatomic, strong) UILabel *swapLeftLabel, *swapRightLabel;
@property (nonatomic, assign) BOOL swapped;
@property (nonatomic, strong) id balanceObserver, backgroundObserver;

@end

@implementation BRAmountViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSMutableCharacterSet *charset = [NSMutableCharacterSet decimalDigitCharacterSet];

    [charset addCharactersInString:manager.format.currencyDecimalSeparator];
    self.charset = charset;

    self.payButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"pay", nil)
                      style:UIBarButtonItemStylePlain target:self action:@selector(pay:)];
    self.amountField.placeholder = [manager stringForAmount:0];
    [self.decimalButton setTitle:manager.format.currencyDecimalSeparator forState:UIControlStateNormal];

    [self updateLocalCurrencyLabel];
    
    self.balanceObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:BRWalletBalanceChangedNotification object:nil queue:nil
        usingBlock:^(NSNotification *note) {
            if ([BRPeerManager sharedInstance].syncProgress < 1.0) return; // wait for sync before updating balance

            self.navigationItem.title = [NSString stringWithFormat:@"%@  LTC",
                                         [manager stringForAmount:manager.wallet.balance]];
        }];
    
    self.backgroundObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            self.navigationItem.titleView = self.logo;
        }];
}

- (void)dealloc
{
    if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
    if (self.backgroundObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.memoField.text = (self.to.length > 0) ?
                          [NSString stringWithFormat:NSLocalizedString(@"to: %@", nil), self.to] : nil;
    self.wallpaper.hidden = NO;

    if (self.navigationController.viewControllers.firstObject != self) {
        self.navigationItem.leftBarButtonItem = nil;
        if ([BRWalletManager sharedInstance].didAuthenticate) [self unlock:nil];
    }
    else {
//        self.memoField.userInteractionEnabled = YES;
//        self.memoField.placeholder = NSLocalizedString(@"memo:", nil);
        self.payButton.title = NSLocalizedString(@"request", nil);
        self.navigationItem.rightBarButtonItem = self.payButton;
    }

    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.amount = 0;
    if (self.navigationController.viewControllers.firstObject != self) self.wallpaper.hidden = animated;

    [super viewWillDisappear:animated];
}

- (void)updateLocalCurrencyLabel
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    uint64_t amount = (self.swapped) ? [manager amountForLocalCurrencyString:self.amountField.text] :
                      [manager amountForString:self.amountField.text];

    self.swapLeftLabel.hidden = YES;
    self.localCurrencyLabel.hidden = NO;
    self.localCurrencyLabel.text = [NSString stringWithFormat:@"(%@)",
                                    (self.swapped) ? [manager stringForAmount:amount] :
                                    [manager localCurrencyStringForAmount:amount]];
    self.localCurrencyLabel.textColor = (amount > 0) ? [UIColor grayColor] : [UIColor colorWithWhite:0.75 alpha:1.0];
}

// MARK: - IBAction

- (IBAction)unlock:(id)sender
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    [BREventManager saveEvent:@"amount:unlock"];
    
    if (sender && ! manager.didAuthenticate && ! [manager authenticateWithPrompt:nil andTouchId:YES]) return;
    [BREventManager saveEvent:@"amount:successful_unlock"];
    
    self.navigationItem.titleView = nil;
    [self.navigationItem setRightBarButtonItem:self.payButton animated:(sender) ? YES : NO];
}

- (IBAction)number:(id)sender
{
    NSUInteger l = [self.amountField.text rangeOfCharacterFromSet:self.charset options:NSBackwardsSearch].location;

    l = (l < self.amountField.text.length) ? l + 1 : self.amountField.text.length;
    [self textField:self.amountField shouldChangeCharactersInRange:NSMakeRange(l, 0)
     replacementString:((UIButton *)sender).titleLabel.text];
}

- (IBAction)del:(id)sender
{
    NSUInteger l = [self.amountField.text rangeOfCharacterFromSet:self.charset options:NSBackwardsSearch].location;

    if (l < self.amountField.text.length) {
        [self textField:self.amountField shouldChangeCharactersInRange:NSMakeRange(l, 1) replacementString:@""];
    }
}

- (IBAction)pay:(id)sender
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];

    self.amount = (self.swapped) ? [manager amountForLocalCurrencyString:self.amountField.text] :
                  [manager amountForString:self.amountField.text];

    if (self.amount == 0){
        [BREventManager saveEvent:@"amount:pay_zero"];
        return;
    }
    
    [BREventManager saveEvent:@"amount:pay"];
    
    [self.delegate amountViewController:self selectedAmount:self.amount];
}

- (IBAction)done:(id)sender
{
    [BREventManager saveEvent:@"amount:dismiss"];
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)swapCurrency:(id)sender
{
    self.swapped = ! self.swapped;
    [BREventManager saveEvent:@"amount:swap_currency"];

    if (self.swapLeftLabel.hidden) {
        self.swapLeftLabel.text = self.localCurrencyLabel.text;
        self.swapLeftLabel.textColor = (self.amountField.text.length > 0) ? self.amountField.textColor :
                                       [UIColor colorWithWhite:0.75 alpha:1.0];
        self.swapLeftLabel.frame = self.localCurrencyLabel.frame;
        [self.localCurrencyLabel.superview addSubview:self.swapLeftLabel];
        self.swapLeftLabel.hidden = NO;
        self.localCurrencyLabel.hidden = YES;
    }

    if (self.swapRightLabel.hidden) {
        self.swapRightLabel.text = (self.amountField.text.length > 0) ? self.amountField.text :
                                   self.amountField.placeholder;
        self.swapRightLabel.textColor = (self.amountField.text.length > 0) ? self.amountField.textColor :
                                        [UIColor colorWithWhite:0.75 alpha:1.0];
        self.swapRightLabel.frame = self.amountField.frame;
        [self.amountField.superview addSubview:self.swapRightLabel];
        self.swapRightLabel.hidden = NO;
        self.amountField.hidden = YES;
    }

    CGFloat scale = self.swapRightLabel.font.pointSize/self.swapLeftLabel.font.pointSize;
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSString *s = (self.swapped) ? self.localCurrencyLabel.text : self.amountField.text;
    uint64_t amount =
        [manager amountForLocalCurrencyString:(self.swapped) ? [s substringWithRange:NSMakeRange(1, s.length - 2)] : s];

    self.localCurrencyLabel.text = [NSString stringWithFormat:@"(%@)",
                                    (self.swapped) ? [manager stringForAmount:amount] :
                                    [manager localCurrencyStringForAmount:amount]];
    self.amountField.text = (self.swapped) ? [manager localCurrencyStringForAmount:amount] :
                            [manager stringForAmount:amount];

    if (amount == 0) {
        self.amountField.placeholder = self.amountField.text;
        self.amountField.text = nil;
    }
    else self.amountField.placeholder = nil;

    [self.view layoutIfNeeded];
    
    CGPoint p = CGPointMake(self.localCurrencyLabel.frame.origin.x + self.localCurrencyLabel.bounds.size.width/2.0 +
                            self.amountField.bounds.size.width/2.0,
                            self.localCurrencyLabel.center.y/2.0 + self.amountField.center.y/2.0);

    [UIView animateWithDuration:0.1 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.swapLeftLabel.transform = CGAffineTransformMakeScale(scale/0.85, scale/0.85);
        self.swapRightLabel.transform = CGAffineTransformMakeScale(0.85/scale, 0.85/scale);
    } completion:nil];

    [UIView animateWithDuration:0.1 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.swapLeftLabel.center = self.swapRightLabel.center = p;
    } completion:^(BOOL finished) {
        self.swapLeftLabel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.swapRightLabel.transform = CGAffineTransformMakeScale(1.0/0.85, 1.0/0.85);
        self.swapLeftLabel.text = self.localCurrencyLabel.text;
        self.swapRightLabel.text = (self.amountField.text.length > 0) ? self.amountField.text :
                                   self.amountField.placeholder;
        self.swapLeftLabel.textColor = self.localCurrencyLabel.textColor;
        self.swapRightLabel.textColor = (self.amountField.text.length > 0) ? self.amountField.textColor :
                                        [UIColor colorWithWhite:0.75 alpha:1.0];
        [self.swapLeftLabel sizeToFit];
        [self.swapRightLabel sizeToFit];
        self.swapLeftLabel.center = self.swapRightLabel.center = p;

        [UIView animateWithDuration:0.7 delay:0.0 usingSpringWithDamping:0.5 initialSpringVelocity:0.0
        options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.swapLeftLabel.transform = CGAffineTransformIdentity;
            self.swapRightLabel.transform = CGAffineTransformIdentity;
        } completion:nil];

        [UIView animateWithDuration:0.7 delay:0.0 usingSpringWithDamping:0.5 initialSpringVelocity:1.0
        options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.swapLeftLabel.frame = self.localCurrencyLabel.frame;
            self.swapRightLabel.frame = self.amountField.frame;
        } completion:nil];
    }];
}

- (IBAction)pressSwapButton:(id)sender
{
    [BREventManager saveEvent:@"amount:press_swap"];
    if (self.swapLeftLabel.hidden) {
        self.swapLeftLabel.text = self.localCurrencyLabel.text;
        self.swapLeftLabel.frame = self.localCurrencyLabel.frame;
        [self.localCurrencyLabel.superview addSubview:self.swapLeftLabel];
        self.swapLeftLabel.hidden = NO;
        self.localCurrencyLabel.hidden = YES;
    }

    self.swapLeftLabel.textColor = self.localCurrencyLabel.textColor;

    if (self.swapRightLabel.hidden) {
        self.swapRightLabel.text = (self.amountField.text.length > 0) ? self.amountField.text :
                                   self.amountField.placeholder;
        self.swapRightLabel.frame = self.amountField.frame;
        [self.amountField.superview addSubview:self.swapRightLabel];
        self.swapRightLabel.hidden = NO;
        self.amountField.hidden = YES;
    }

    self.swapRightLabel.textColor = (self.amountField.text.length > 0) ? self.amountField.textColor :
                                    [UIColor colorWithWhite:0.75 alpha:1.0];

    [UIView animateWithDuration:0.1 animations:^{
        //self.swapLeftLabel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.swapLeftLabel.textColor = self.swapRightLabel.textColor;
        self.swapRightLabel.textColor = self.localCurrencyLabel.textColor;
        self.swapLeftLabel.text = [[self.swapLeftLabel.text stringByReplacingOccurrencesOfString:@"(" withString:@""]
                                   stringByReplacingOccurrencesOfString:@")" withString:@""];
    }];
}

- (IBAction)releaseSwapButton:(id)sender
{
    [BREventManager saveEvent:@"amount:release_swap"];
    [UIView animateWithDuration:0.1 animations:^{
        //self.swapLeftLabel.transform = CGAffineTransformIdentity;
        self.swapLeftLabel.textColor = self.localCurrencyLabel.textColor;
    } completion:^(BOOL finished) {
        self.swapLeftLabel.hidden = self.swapRightLabel.hidden = YES;
        self.localCurrencyLabel.hidden = self.amountField.hidden = NO;
    }];
}

// MARK: - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSNumberFormatter *numberFormatter = (self.swapped) ? manager.localFormat : manager.format;
    NSUInteger decimalLoc = [textField.text rangeOfString:numberFormatter.currencyDecimalSeparator].location;
    NSUInteger minimumFractionDigits = numberFormatter.minimumFractionDigits;
    NSString *textVal = textField.text, *zeroStr = nil;
    NSDecimalNumber *num;

    if (! textVal) textVal = @"";
    numberFormatter.minimumFractionDigits = 0;
    zeroStr = [numberFormatter stringFromNumber:@0];

    // if amount is prefixed with currency symbol, then equivalent to [zeroStr stringByAppendingString:numberFormatter.currencyDecimalSeparator]
    // otherwise, numberFormatter.currencyDecimalSeparator must be inserted exactly after 0
    NSString *(^zeroStrByInsertingCurrencyDecimalSeparator)() = ^NSString * {
        NSRange zeroCharacterRange = [zeroStr rangeOfCharacterFromSet:self.charset];
        return [zeroStr stringByReplacingCharactersInRange:NSMakeRange(NSMaxRange(zeroCharacterRange), 0)
                                                withString:numberFormatter.currencyDecimalSeparator];
    };
    
    if (string.length == 0) { // delete button
        textVal = [textVal stringByReplacingCharactersInRange:range withString:string];

        if (range.location <= decimalLoc) { // deleting before the decimal requires reformatting
            textVal = [numberFormatter stringFromNumber:[numberFormatter numberFromString:textVal]];
        }

        if (! textVal || [textVal isEqual:zeroStr]) textVal = @""; // check if we are left with a zero amount
    }
    else if ([string isEqual:numberFormatter.currencyDecimalSeparator]) { // decimal point button
        if (decimalLoc == NSNotFound && numberFormatter.maximumFractionDigits > 0) {
            textVal = (textVal.length == 0) ? zeroStrByInsertingCurrencyDecimalSeparator() :
                      [textVal stringByReplacingCharactersInRange:range withString:string];
        }
    }
    else { // digit button
        // check for too many digits after the decimal point
        if (range.location > decimalLoc && range.location - decimalLoc > numberFormatter.maximumFractionDigits) {
            numberFormatter.minimumFractionDigits = numberFormatter.maximumFractionDigits;
            num = [NSDecimalNumber decimalNumberWithDecimal:[numberFormatter numberFromString:textVal].decimalValue];
            num = [num decimalNumberByMultiplyingByPowerOf10:1];
            num = [num decimalNumberByAdding:[[NSDecimalNumber decimalNumberWithString:string]
                   decimalNumberByMultiplyingByPowerOf10:-numberFormatter.maximumFractionDigits]];
            textVal = [numberFormatter stringFromNumber:num];
            if (! [numberFormatter numberFromString:textVal]) textVal = nil;
        }
        else if (textVal.length == 0 && [string isEqual:@"0"]) { // if first digit is zero, append decimal point
            textVal = zeroStrByInsertingCurrencyDecimalSeparator();
        }
        else if (range.location > decimalLoc && [string isEqual:@"0"]) { // handle multiple zeros after decimal point
            textVal = [textVal stringByReplacingCharactersInRange:range withString:string];
        }
        else {
            textVal = [numberFormatter stringFromNumber:[numberFormatter numberFromString:[textVal
                       stringByReplacingCharactersInRange:range withString:string]]];
        }
    }
    
    if (textVal) textField.text = textVal;
    numberFormatter.minimumFractionDigits = minimumFractionDigits;
    if (textVal.length > 0 && textField.placeholder.length > 0) textField.placeholder = nil;

    if (textVal.length == 0 && textField.placeholder.length == 0) {
        textField.placeholder = (self.swapped) ? [manager localCurrencyStringForAmount:0] : [manager stringForAmount:0];
    }
    
    if (self.navigationController.viewControllers.firstObject != self) {
        if (! manager.didAuthenticate && textVal.length == 0 && self.navigationItem.rightBarButtonItem != self.lock) {
            [self.navigationItem setRightBarButtonItem:self.lock animated:YES];
        }
        else if (textVal.length > 0 && self.navigationItem.rightBarButtonItem != self.payButton) {
            [self.navigationItem setRightBarButtonItem:self.payButton animated:YES];
        }
    }

    self.swapRightLabel.hidden = YES;
    textField.hidden = NO;
    [self updateLocalCurrencyLabel];

    return NO;
}

@end
