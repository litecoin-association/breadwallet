//
//  BRSendViewController.m
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

#import "BRSendViewController.h"
#import "BRRootViewController.h"
#import "BRScanViewController.h"
#import "BRAmountViewController.h"
#import "BRSettingsViewController.h"
#import "BRBubbleView.h"
#import "BRWalletManager.h"
#import "BRPeerManager.h"
#import "BRPaymentRequest.h"
#import "BRPaymentProtocol.h"
#import "BRKey.h"
#import "BRTransaction.h"
#import "NSString+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "BREventManager.h"
#import "breadwallet-Swift.h"

#define SCAN_TIP      NSLocalizedString(@"Scan someone else's QR code to get their bitcoin address. "\
                                         "You can send a payment to anyone with an address.", nil)
#define CLIPBOARD_TIP NSLocalizedString(@"Bitcoin addresses can also be copied to the clipboard. "\
                                         "A bitcoin address always starts with '1' or '3'.", nil)

#define LOCK @"\xF0\x9F\x94\x92" // unicode lock symbol U+1F512 (utf-8)
#define REDX @"\xE2\x9D\x8C"     // unicode cross mark U+274C, red x emoji (utf-8)
#define NBSP @"\xC2\xA0"         // no-break space (utf-8)

static NSString *sanitizeString(NSString *s)
{
    NSMutableString *sane = [NSMutableString stringWithString:(s) ? s : @""];
    
    CFStringTransform((CFMutableStringRef)sane, NULL, kCFStringTransformToUnicodeName, NO);
    return sane;
}

@interface BRSendViewController ()

@property (nonatomic, assign) BOOL clearClipboard, useClipboard, showTips, showBalance, canChangeAmount;
@property (nonatomic, strong) BRTransaction *sweepTx;
@property (nonatomic, strong) BRPaymentProtocolRequest *request;
@property (nonatomic, strong) NSURL *url, *callback;
@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, strong) NSString *okAddress, *okIdentity;
@property (nonatomic, strong) BRBubbleView *tipView;
@property (nonatomic, strong) BRScanViewController *scanController;
@property (nonatomic, strong) id clipboardObserver;

@property (nonatomic, strong) IBOutlet UILabel *sendLabel;
@property (nonatomic, strong) IBOutlet UIButton *scanButton, *clipboardButton;
@property (nonatomic, strong) IBOutlet UITextView *clipboardText;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *clipboardXLeft;
@property (strong, nonatomic) IBOutlet UIView *addressView;
@property (strong, nonatomic) IBOutlet UITextField *amountField;
@property (strong, nonatomic) IBOutlet UILabel *localCurrencyLabel;
@property (strong, nonatomic) IBOutlet UIView *amountView;
@property (strong, nonatomic) IBOutlet UIView *localCurrencyView;
@property (strong, nonatomic) IBOutlet UILabel *localCurrencyNameLabel;
@property (strong, nonatomic) IBOutlet UIButton *sendButton;

@end

@implementation BRSendViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.addressView.layer.cornerRadius = 3;
    self.addressView.layer.borderWidth = 3;
    self.addressView.layer.borderColor = (__bridge CGColorRef _Nullable)([UIColor colorWithRed:242.0 green:249.0 blue:253.0 alpha:1.0]);
    self.addressView.clipsToBounds = YES;
    self.amountView.layer.cornerRadius = 3;
    self.amountView.layer.borderWidth = 3;
    self.amountView.layer.borderColor = (__bridge CGColorRef _Nullable)([UIColor colorWithRed:242.0 green:249.0 blue:253.0 alpha:1.0]);
    self.amountView.clipsToBounds = YES;
    self.localCurrencyView.layer.cornerRadius = 3;
    self.localCurrencyView.layer.borderWidth = 3;
    self.localCurrencyView.layer.borderColor = (__bridge CGColorRef _Nullable)([UIColor colorWithRed:242.0 green:249.0 blue:253.0 alpha:1.0]);
    self.localCurrencyView.clipsToBounds = YES;
    self.sendButton.layer.cornerRadius = 3;
    self.sendButton.layer.borderWidth = 3;
    self.sendButton.layer.borderColor = (__bridge CGColorRef _Nullable)([UIColor colorWithRed:40.0 green:40.0 blue:40.0 alpha:0.90]);
    self.sendButton.clipsToBounds = YES;
    
    // TODO: XXX redesign page with round buttons like the iOS power down screen... apple watch also has round buttons
    self.scanButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.clipboardButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.scanButton.titleLabel.adjustsLetterSpacingToFitWidth = YES;
    self.clipboardButton.titleLabel.adjustsLetterSpacingToFitWidth = YES;
#pragma clang diagnostic pop
    
    self.clipboardText.textContainerInset = UIEdgeInsetsMake(8.0, 0.0, 0.0, 0.0);
    
    self.clipboardObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIPasteboardChangedNotification object:nil queue:nil
        usingBlock:^(NSNotification *note) {
            if (self.clipboardText.isFirstResponder) {
                self.useClipboard = YES;
            }
            else [self updateClipboardText];
        }];
    
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
    self.amountField.placeholder = [manager stringForAmount:0];
    [self updateLocalCurrencyLabel];
    
    // Done and cancel button for decimal pad
    
    UIToolbar* decimalPad = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 50)];
    decimalPad.barStyle = UIBarStyleDefault;
    decimalPad.items = @[[[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad)],
                            [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc]initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneNumberPad)]];
    [decimalPad sizeToFit];
    self.amountField.inputAccessoryView = decimalPad;
    
    // Change default Currency Code (USD) to Local Currency Code
    
    self.localCurrencyNameLabel.text = manager.localCurrencyCode;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self cancel:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (! self.scanController) {
        self.scanController = [self.storyboard instantiateViewControllerWithIdentifier:@"ScanViewController"];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.amount = 0;
    [self hideTips];
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.clipboardObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.clipboardObserver];
}

-(void)cancelNumberPad{
    [self.amountField resignFirstResponder];
    self.amountField.text = @"";
    [self updateLocalCurrencyLabel];
}

-(void)doneNumberPad{
    [self updateLocalCurrencyLabel];
    [self.amountField resignFirstResponder];
}

- (void)updateLocalCurrencyLabel
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    uint64_t amount = [manager amountForString:self.amountField.text];
    
    self.localCurrencyLabel.hidden = NO;
    self.localCurrencyLabel.text = [NSString stringWithFormat:@"%@",
                                    [manager localCurrencyStringForAmount:amount]];
    self.localCurrencyLabel.textColor = (amount > 0) ? [UIColor blackColor] : [UIColor grayColor];
}

- (void)handleURL:(NSURL *)url
{
    [BREventManager saveEvent:@"send:handle_url"
               withAttributes:@{@"scheme": (url.scheme ? url.scheme : @"(null)"),
                                @"host": (url.host ? url.host : @"(null)"),
                                @"path": (url.path ? url.path : @"(null)")}];
    
    //TODO: XXX custom url splash image per: "Providing Launch Images for Custom URL Schemes."
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    if ([url.scheme isEqual:@"loaf"]) { // x-callback-url handling: http://x-callback-url.com/specifications/
        NSString *xsource = nil, *xsuccess = nil, *xerror = nil, *uri = nil;
        NSURL *callback = nil;

        for (NSString *arg in [url.query componentsSeparatedByString:@"&"]) {
            NSArray *pair = [arg componentsSeparatedByString:@"="]; // if more than one '=', then pair[1] != value

            if (pair.count < 2) continue;

            NSString *value = [[[arg substringFromIndex:[pair[0] length] + 1]
                                stringByReplacingOccurrencesOfString:@"+" withString:@" "]
                               stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

            if ([pair[0] isEqual:@"x-source"]) xsource = value;
            else if ([pair[0] isEqual:@"x-success"]) xsuccess = value;
            else if ([pair[0] isEqual:@"x-error"]) xerror = value;
            else if ([pair[0] isEqual:@"uri"]) uri = value;
        }
    
        if ([url.host isEqual:@"scanqr"] || [url.path isEqual:@"/scanqr"]) { // scan qr
            [self scanQR:self.scanButton];
        }
        else if ([url.host isEqual:@"addresslist"] || [url.path isEqual:@"/addresslist"]) { // copy wallet addresses
            if ((manager.didAuthenticate || [manager authenticateWithPrompt:nil andTouchId:YES])
                && ! self.clearClipboard) {
                
                if (! [self.url isEqual:url]) {
                    self.url = url;
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"copy wallet addresses to clipboard?", nil)
                      message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                      otherButtonTitles:NSLocalizedString(@"copy", nil), nil] show];
                }
                else {
                    [UIPasteboard generalPasteboard].string =
                        [[[manager.wallet.allReceiveAddresses
                           setByAddingObjectsFromSet:manager.wallet.allChangeAddresses]
                        objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                            return [manager.wallet addressIsUsed:obj];
                        }].allObjects componentsJoinedByString:@"\n"];

                    if (xsuccess) callback = [NSURL URLWithString:xsuccess];
                    self.url = nil;
                }
            }
            else if (xerror || xsuccess) {
                callback = [NSURL URLWithString:(xerror) ? xerror : xsuccess];
                [UIPasteboard generalPasteboard].string = @"";
                [self cancel:nil];
            }
        }
        else if ([url.path isEqual:@"/address"] && xsuccess) { // get receive address
            callback = [NSURL URLWithString:[xsuccess stringByAppendingFormat:@"%@address=%@",
                                             ([NSURL URLWithString:xsuccess].query.length > 0) ? @"&" : @"?",
                                             manager.wallet.receiveAddress]];
        }
        else if (([url.host isEqual:@"litecoin-uri"] || [url.path isEqual:@"/litecoin-uri"]) && uri &&
                 [[NSURL URLWithString:uri].scheme isEqual:@"litecoin"]) {
            if (xsuccess) self.callback = [NSURL URLWithString:xsuccess];
            [self handleURL:[NSURL URLWithString:uri]];
        }
        
        if (callback) [[UIApplication sharedApplication] openURL:callback];
    }
    else if ([url.scheme isEqual:@"litecoin"]) {
        [self confirmRequest:[BRPaymentRequest requestWithURL:url]];
    } else if ([BRBitID isBitIDURL:url]) {
        [self handleBitIDURL:url];
    }
    else {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"unsupported url", nil) message:url.absoluteString
          delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
    }
}

- (void)handleFile:(NSData *)file
{
    BRPaymentProtocolRequest *request = [BRPaymentProtocolRequest requestWithData:file];

    if (request) {
        [self confirmProtocolRequest:request];
        return;
    }

    // TODO: reject payments that don't match requested amounts/scripts, implement refunds
    BRPaymentProtocolPayment *payment = [BRPaymentProtocolPayment paymentWithData:file];
            
    if (payment.transactions.count > 0) {
        for (BRTransaction *tx in payment.transactions) {
            [(id)self.parentViewController.parentViewController startActivityWithTimeout:30];

            [[BRPeerManager sharedInstance] publishTransaction:tx completion:^(NSError *error) {
                [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];
                
                if (error) {
                    [[[UIAlertView alloc]
                      initWithTitle:NSLocalizedString(@"couldn't transmit payment to bitcoin network", nil)
                      message:error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil)
                      otherButtonTitles:nil] show];
                }

                [self.view addSubview:[[[BRBubbleView
                 viewWithText:(payment.memo.length > 0 ? payment.memo : NSLocalizedString(@"received", nil))
                 center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                 popOutAfterDelay:(payment.memo.length > 0 ? 3.0 : 2.0)]];
            }];
        }

        return;
    }
    
    BRPaymentProtocolACK *ack = [BRPaymentProtocolACK ackWithData:file];
            
    if (ack) {
        if (ack.memo.length > 0) {
            [self.view addSubview:[[[BRBubbleView viewWithText:ack.memo
             center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
             popOutAfterDelay:3.0]];
        }

        return;
    }

    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"unsupported or corrupted document", nil) message:nil
      delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
}

- (void)handleBitIDURL:(NSURL *)url
{
    if ([UIAlertController class] == nil) {
        return;
    }
    BRBitID *bitid = [[BRBitID alloc] initWithUrl:url];
    
    void (^actionHandler)(UIAlertAction * _Nonnull) = ^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
        if (action.style == UIAlertActionStyleDefault) {
            BRActivityViewController *activityVC = [[BRActivityViewController alloc] initWithMessage:
                                                    NSLocalizedString(@"Signing...", nil)];
            void (^callbackHandler)(id, id, id) = ^(NSData *data, NSURLResponse *resp, NSError *error) {
                [self.navigationController dismissViewControllerAnimated:YES completion:nil];
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)resp;
                if (error == nil && (httpResp.statusCode >= 200 && httpResp.statusCode < 300)) {
                    // successfully sent bitid callback request. show a brief success message
                    UIAlertController *successAlert =
                    [UIAlertController alertControllerWithTitle:@"Successfully Authenticated" message:nil
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    [self.navigationController presentViewController:successAlert animated:YES completion:nil];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                                       [self dismissViewControllerAnimated:YES completion:nil];
                                   });
                } else {
                    // show the user an error alert
                    UIAlertController *errorAlert =
                    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Authentication Error", nil)
                                                        message:NSLocalizedString(@"Please check with the service. "
                                                                                  "You may need to try again.", nil)
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                                     [self dismissViewControllerAnimated:YES
                                                                                              completion:nil];
                                                                 }]];
                    [self.navigationController presentViewController:errorAlert animated:YES completion:nil];
                }
            };
            // attempt to avoid frozen pin input bug 
            CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes, ^{
                [bitid runCallback:callbackHandler];
                [self.navigationController presentViewController:activityVC animated:YES completion:nil];
            });
        }
    };
    
    NSString *message = [NSString stringWithFormat:
                         NSLocalizedString(@"%@ is requesting authentication using your bitcoin wallet.", nil),
                         bitid.siteName];
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"BitID Authentication Request", nil)
                                            message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Deny", nil)
                                                        style:UIAlertActionStyleCancel
                                                      handler:actionHandler]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Approve", nil)
                                                        style:UIAlertActionStyleDefault
                                                      handler:actionHandler]];
    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}


// generate a description of a transaction so the user can review and decide whether to confirm or cancel
- (NSString *)promptForAmount:(uint64_t)amount fee:(uint64_t)fee address:(NSString *)address name:(NSString *)name
memo:(NSString *)memo isSecure:(BOOL)isSecure
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSString *prompt = (isSecure && name.length > 0) ? LOCK @" " : @"";

    //BUG: XXX limit the length of name and memo to avoid having the amount clipped
    if (! isSecure && self.request.errorMessage.length > 0) prompt = [prompt stringByAppendingString:REDX @" "];
    if (name.length > 0) prompt = [prompt stringByAppendingString:sanitizeString(name)];
    if (! isSecure && prompt.length > 0) prompt = [prompt stringByAppendingString:@"\n"];
    if (! isSecure || prompt.length == 0) prompt = [prompt stringByAppendingString:address];
    if (memo.length > 0) prompt = [prompt stringByAppendingFormat:@"\n\n%@", sanitizeString(memo)];
    prompt = [prompt stringByAppendingFormat:NSLocalizedString(@"\n\n     amount %@", nil),
              [manager stringForAmount:amount - fee]];

    if (fee > 0) {
        prompt = [prompt stringByAppendingFormat:NSLocalizedString(@"\nnetwork fee +%@", nil),
                  [manager stringForAmount:fee]];
        prompt = [prompt stringByAppendingFormat:NSLocalizedString(@"\n         total %@", nil),
                  [manager stringForAmount:amount]];
    }

    return prompt;
}

- (void)confirmRequest:(BRPaymentRequest *)request
{
    if (! request.isValid) {
        if ([request.paymentAddress isValidBitcoinPrivateKey] || [request.paymentAddress isValidBitcoinBIP38Key]) {
            [self confirmSweep:request.paymentAddress];
        }
        else {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"not a valid bitcoin address", nil)
              message:request.paymentAddress delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil)
              otherButtonTitles:nil] show];
            [self cancel:nil];
        }
    }
    else if (request.r.length > 0) { // payment protocol over HTTP
        [(id)self.parentViewController.parentViewController startActivityWithTimeout:20.0];

        [BRPaymentRequest fetch:request.r timeout:20.0 completion:^(BRPaymentProtocolRequest *req, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];

                if (error && ! [request.paymentAddress isValidBitcoinAddress]) {
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                      message:error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil)
                      otherButtonTitles:nil] show];
                    [self cancel:nil];
                }
                else [self confirmProtocolRequest:(error) ? request.protocolRequest : req];
            });
        }];
    }
    else [self confirmProtocolRequest:request.protocolRequest];
}

- (void)confirmProtocolRequest:(BRPaymentProtocolRequest *)protoReq
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    BRTransaction *tx = nil;
    uint64_t amount = 0, fee = 0;
    NSString *address = [NSString addressWithScriptPubKey:protoReq.details.outputScripts.firstObject];
    BOOL valid = protoReq.isValid, outputTooSmall = NO;

    if (! valid && [protoReq.errorMessage isEqual:NSLocalizedString(@"request expired", nil)]) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"bad payment request", nil) message:protoReq.errorMessage
          delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        [self cancel:nil];
        return;
    }

    //TODO: check for duplicates of already paid requests

    if (self.amount == 0) {
        for (NSNumber *outputAmount in protoReq.details.outputAmounts) {
            if (outputAmount.unsignedLongLongValue > 0 && outputAmount.unsignedLongLongValue < TX_MIN_OUTPUT_AMOUNT) {
                outputTooSmall = YES;
            }
            amount += outputAmount.unsignedLongLongValue;
        }
    }
    else amount = self.amount;

    if ([manager.wallet containsAddress:address]) {
        [[[UIAlertView alloc] initWithTitle:@""
          message:NSLocalizedString(@"this payment address is already in your wallet", nil)
          delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        [self cancel:nil];
        return;
    }
    else if (! [self.okAddress isEqual:address] && [manager.wallet addressIsUsed:address] &&
             [[UIPasteboard generalPasteboard].string isEqual:address]) {
        self.request = protoReq;
        self.okAddress = address;
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"WARNING", nil)
          message:NSLocalizedString(@"\nADDRESS ALREADY USED\n\nbitcoin addresses are intended for single use only\n\n"
                                    "re-use reduces privacy for both you and the recipient and can result in loss if "
                                    "the recipient doesn't directly control the address", nil)
          delegate:self cancelButtonTitle:nil
          otherButtonTitles:NSLocalizedString(@"ignore", nil), NSLocalizedString(@"cancel", nil), nil] show];
          return;
    }
    else if (protoReq.errorMessage.length > 0 && protoReq.commonName.length > 0 &&
             ! [self.okIdentity isEqual:protoReq.commonName]) {
        self.request = protoReq;
        self.okIdentity = protoReq.commonName;
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"payee identity isn't certified", nil)
          message:protoReq.errorMessage delegate:self cancelButtonTitle:nil
          otherButtonTitles:NSLocalizedString(@"ignore", nil), NSLocalizedString(@"cancel", nil), nil] show];
        return;
    }
    else if (amount == 0 || amount == UINT64_MAX) {
        BRAmountViewController *amountController = [self.storyboard
                                                    instantiateViewControllerWithIdentifier:@"AmountViewController"];
        
        amountController.delegate = self;
        self.request = protoReq;

        if (protoReq.commonName.length > 0) {
            if (valid && ! [protoReq.pkiType isEqual:@"none"]) {
                amountController.to = [LOCK @" " stringByAppendingString:sanitizeString(protoReq.commonName)];
            }
            else if (protoReq.errorMessage.length > 0) {
                amountController.to = [REDX @" " stringByAppendingString:sanitizeString(protoReq.commonName)];
            }
            else amountController.to = sanitizeString(protoReq.commonName);
        }
        else amountController.to = address;

        amountController.navigationItem.title = [NSString stringWithFormat:@"%@  LTC",
                                                 [manager stringForAmount:manager.wallet.balance]];
        [self.navigationController pushViewController:amountController animated:YES];
        return;
    }
    else if (amount < TX_MIN_OUTPUT_AMOUNT) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't make payment", nil)
          message:[NSString stringWithFormat:NSLocalizedString(@"bitcoin payments can't be less than %@", nil),
                   [manager stringForAmount:TX_MIN_OUTPUT_AMOUNT]] delegate:nil
          cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        [self cancel:nil];
        return;
    }
    else if (outputTooSmall) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't make payment", nil)
          message:[NSString stringWithFormat:NSLocalizedString(@"bitcoin transaction outputs can't be less than %@",
                                                               nil), [manager stringForAmount:TX_MIN_OUTPUT_AMOUNT]]
          delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        [self cancel:nil];
        return;
    }
    
    self.request = protoReq;
    
    if (self.amount == 0) {
        tx = [manager.wallet transactionForAmounts:protoReq.details.outputAmounts
              toOutputScripts:protoReq.details.outputScripts withFee:YES];
    }
    else {
        tx = [manager.wallet transactionForAmounts:@[@(self.amount)]
              toOutputScripts:@[protoReq.details.outputScripts.firstObject] withFee:YES];
    }
    
    if (tx) {
        amount = [manager.wallet amountSentByTransaction:tx] - [manager.wallet amountReceivedFromTransaction:tx];
        fee = [manager.wallet feeForTransaction:tx];
    }
    else {
        fee = [manager.wallet feeForTxSize:[manager.wallet transactionFor:manager.wallet.balance
                                            to:address withFee:NO].size];
        fee += (manager.wallet.balance - amount) % 100;
        amount += fee;
    }

    for (NSData *script in protoReq.details.outputScripts) {
        NSString *addr = [NSString addressWithScriptPubKey:script];
            
        if (! addr) addr = NSLocalizedString(@"unrecognized address", nil);
        if ([address rangeOfString:addr].location != NSNotFound) continue;
        address = [address stringByAppendingFormat:@"%@%@", (address.length > 0) ? @", " : @"", addr];
    }
    
    NSString *prompt = [self promptForAmount:amount fee:fee address:address name:protoReq.commonName
                        memo:protoReq.details.memo isSecure:(valid && ! [protoReq.pkiType isEqual:@"none"])];
    
    // to avoid the frozen pincode keyboard bug, we need to make sure we're scheduled normally on the main runloop
    // rather than a dispatch_async queue
    CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes, ^{
        [self confirmTransaction:tx withPrompt:prompt forAmount:amount];
    });
}

- (void)confirmTransaction:(BRTransaction *)tx withPrompt:(NSString *)prompt forAmount:(uint64_t)amount
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    BOOL didAuth = manager.didAuthenticate;

    if (! tx) { // tx is nil if there were insufficient wallet funds
        if (! manager.didAuthenticate) [manager seedWithPrompt:prompt forAmount:amount];
        
        if (manager.didAuthenticate) {
            uint64_t fuzz = [manager amountForLocalCurrencyString:[manager localCurrencyStringForAmount:1]]*2;
            
            // if user selected an amount equal to or below wallet balance, but the fee will bring the total above the
            // balance, offer to reduce the amount to available funds minus fee
            if (self.amount <= manager.wallet.balance + fuzz && self.amount > 0) {
                int64_t amount = manager.wallet.maxOutputAmount;

                if (amount > 0 && amount < self.amount) {
                    [[[UIAlertView alloc]
                      initWithTitle:NSLocalizedString(@"insufficient funds for bitcoin network fee", nil)
                      message:[NSString stringWithFormat:NSLocalizedString(@"reduce payment amount by\n%@?", nil),
                               [manager stringForAmount:self.amount - amount]] delegate:self
                      cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                      otherButtonTitles:[NSString stringWithFormat:@"%@",
                                         [manager stringForAmount:amount - self.amount]], nil] show];
                    self.amount = amount;
                }
                else {
                    [[[UIAlertView alloc]
                      initWithTitle:NSLocalizedString(@"insufficient funds for bitcoin network fee", nil) message:nil
                      delegate:self cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
                }
            }
            else {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"insufficient funds", nil) message:nil
                  delegate:self cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
            }
        }
        else [self cancelOrChangeAmount];

        if (! didAuth) manager.didAuthenticate = NO;
        return;
    }

    if (! [manager.wallet signTransaction:tx withPrompt:prompt]) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't make payment", nil)
          message:NSLocalizedString(@"error signing bitcoin transaction", nil) delegate:nil
          cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
    }

    if (! didAuth) manager.didAuthenticate = NO;

    if (! tx.isSigned) { // user canceled authentication
        [self cancelOrChangeAmount];
        return;
    }
    
    if (self.navigationController.topViewController != self.parentViewController.parentViewController) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    
    __block BOOL waiting = YES, sent = NO;
    
    [(id)self.parentViewController.parentViewController startActivityWithTimeout:30.0];
    
    [[BRPeerManager sharedInstance] publishTransaction:tx completion:^(NSError *error) {
        if (error) {
            if (! waiting && ! sent) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                  message:error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil)
                  otherButtonTitles:nil] show];
                [(id)self.parentViewController.parentViewController stopActivityWithSuccess:NO];
                [self cancel:nil];
            }
        }
        else if (! sent) { //TODO: show full screen sent dialog with tx info, "you sent b10,000 to bob"
            sent = YES;
            tx.timestamp = [NSDate timeIntervalSinceReferenceDate];
            [manager.wallet registerTransaction:tx];
            [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
             center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
             popOutAfterDelay:2.0]];
            [(id)self.parentViewController.parentViewController stopActivityWithSuccess:YES];
            [(id)self.parentViewController.parentViewController ping];

            if (self.callback) {
                self.callback = [NSURL URLWithString:[self.callback.absoluteString stringByAppendingFormat:@"%@txid=%@",
                                                      (self.callback.query.length > 0) ? @"&" : @"?",
                                                      [NSString hexWithData:[NSData dataWithBytes:tx.txHash.u8
                                                                             length:sizeof(UInt256)].reverse]]];
                [[UIApplication sharedApplication] openURL:self.callback];
            }
            
            [self reset:nil];
        }
        
        waiting = NO;
    }];
    
    if (self.request.details.paymentURL.length > 0) {
        uint64_t refundAmount = 0;
        NSMutableData *refundScript = [NSMutableData data];
    
        [refundScript appendScriptPubKeyForAddress:manager.wallet.receiveAddress];
        
        for (NSNumber *amt in self.request.details.outputAmounts) {
            refundAmount += amt.unsignedLongLongValue;
        }

        // TODO: keep track of commonName/memo to associate them with outputScripts
        BRPaymentProtocolPayment *payment =
            [[BRPaymentProtocolPayment alloc] initWithMerchantData:self.request.details.merchantData
             transactions:@[tx] refundToAmounts:@[@(refundAmount)] refundToScripts:@[refundScript] memo:nil];
    
        NSLog(@"posting payment to: %@", self.request.details.paymentURL);
    
        [BRPaymentRequest postPayment:payment to:self.request.details.paymentURL timeout:20.0
        completion:^(BRPaymentProtocolACK *ack, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];
    
                if (error) {
                    if (! waiting && ! sent) {
                        [[[UIAlertView alloc] initWithTitle:@"" message:error.localizedDescription delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
                        [(id)self.parentViewController.parentViewController stopActivityWithSuccess:NO];
                        [self cancel:nil];
                    }
                }
                else if (! sent) {
                    sent = YES;
                    tx.timestamp = [NSDate timeIntervalSinceReferenceDate];
                    [manager.wallet registerTransaction:tx];
                    [self.view addSubview:[[[BRBubbleView
                     viewWithText:(ack.memo.length > 0 ? ack.memo : NSLocalizedString(@"sent!", nil))
                     center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                     popOutAfterDelay:(ack.memo.length > 0 ? 3.0 : 2.0)]];
                    [(id)self.parentViewController.parentViewController stopActivityWithSuccess:YES];
                    [(id)self.parentViewController.parentViewController ping];

                    if (self.callback) {
                        self.callback = [NSURL URLWithString:[self.callback.absoluteString
                                                              stringByAppendingFormat:@"%@txid=%@",
                                                              (self.callback.query.length > 0) ? @"&" : @"?",
                                                              [NSString hexWithData:[NSData dataWithBytes:tx.txHash.u8
                                                                                     length:sizeof(UInt256)].reverse]]];
                        [[UIApplication sharedApplication] openURL:self.callback];
                    }
                    
                    [self reset:nil];
                }

                waiting = NO;
            });
        }];
    }
    else waiting = NO;
}

- (void)confirmSweep:(NSString *)privKey
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
    if (! [privKey isValidBitcoinPrivateKey] && ! [privKey isValidBitcoinBIP38Key]) return;

    BRBubbleView *statusView = [BRBubbleView viewWithText:NSLocalizedString(@"checking private key balance...", nil)
                                center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];

    statusView.font = [UIFont fontWithName:@"HelveticaNeue" size:15.0];
    statusView.customView = [[UIActivityIndicatorView alloc]
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [(id)statusView.customView startAnimating];
    [self.view addSubview:[statusView popIn]];

    [manager sweepPrivateKey:privKey withFee:YES completion:^(BRTransaction *tx, uint64_t fee, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [statusView popOut];

            if (error) {
                [[[UIAlertView alloc] initWithTitle:@"" message:error.localizedDescription delegate:self
                  cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
                [self cancel:nil];
            }
            else if (tx) {
                uint64_t amount = fee;

                for (NSNumber *amt in tx.outputAmounts) amount += amt.unsignedLongLongValue;
                self.sweepTx = tx;

                NSString *alertFmt = NSLocalizedString(@"Send %@ from this private key into your wallet? "
                                                       "The bitcoin network will receive a fee of %@.", nil);
                NSString *alertMsg = [NSString stringWithFormat:alertFmt, [manager stringForAmount:amount], [manager stringForAmount:fee]];
                [[[UIAlertView alloc] initWithTitle:@"" message:alertMsg delegate:self
                  cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                  otherButtonTitles:[NSString stringWithFormat:@"%@", [manager stringForAmount:amount]], nil] show];
            }
            else [self cancel:nil];
        });
    }];
}

- (void)showBalance:(NSString *)address
{
    if (! [address isValidBitcoinAddress]) return;

    BRWalletManager *manager = [BRWalletManager sharedInstance];
    BRBubbleView *statusView = [BRBubbleView viewWithText:NSLocalizedString(@"checking address balance...", nil)
                       center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
    
    statusView.font = [UIFont fontWithName:@"HelveticaNeue" size:15.0];
    statusView.customView = [[UIActivityIndicatorView alloc]
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [(id)statusView.customView startAnimating];
    [self.view addSubview:[statusView popIn]];

    [manager utxosForAddresses:@[address]
    completion:^(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [statusView popOut];
        
            if (error) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't check address balance", nil)
                  message:error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil)
                  otherButtonTitles:nil] show];
            }
            else {
                uint64_t balance = 0;
            
                for (NSNumber *amt in amounts) balance += amt.unsignedLongLongValue;
            
                NSString *alertMsg = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nbalance: %@", nil),
                                      address, [manager stringForAmount:balance]];

                [[[UIAlertView alloc] initWithTitle:@"" message:alertMsg delegate:nil
                  cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
            }
        });
    }];
}

- (void)cancelOrChangeAmount
{
    if (self.canChangeAmount && self.request && self.amount == 0) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"change payment amount?", nil)
          message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil)
          otherButtonTitles:NSLocalizedString(@"change", nil), nil] show];
        self.amount = UINT64_MAX;
    }
    else [self cancel:nil];
}

- (void)hideTips
{
    if (self.tipView.alpha > 0.5) [self.tipView popOut];
}

- (BOOL)nextTip
{
    [self.clipboardText resignFirstResponder];
    if (self.tipView.alpha < 0.5) return [(id)self.parentViewController.parentViewController nextTip];

    BRBubbleView *tipView = self.tipView;

    self.tipView = nil;
    [tipView popOut];
    
    if ([tipView.text hasPrefix:SCAN_TIP]) {
//        self.tipView = [BRBubbleView viewWithText:CLIPBOARD_TIP
//                        tipPoint:CGPointMake(self.clipboardButton.center.x, self.clipboardButton.center.y + 10.0)
//                        tipDirection:BRBubbleTipDirectionUp];
//        self.tipView.backgroundColor = tipView.backgroundColor;
//        self.tipView.font = tipView.font;
//        self.tipView.userInteractionEnabled = NO;
//        [self.view addSubview:[self.tipView popIn]];
    }
    else if (self.showTips && [tipView.text hasPrefix:CLIPBOARD_TIP]) {
        self.showTips = NO;
        [(id)self.parentViewController.parentViewController tip:self];
    }

    return YES;
}

- (void)resetQRGuide
{
    self.scanController.message.text = nil;
    self.scanController.cameraGuide.image = [UIImage imageNamed:@"cameraguide"];
}

- (void)updateClipboardText
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *str = [[UIPasteboard generalPasteboard].string
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *text = @"";
        UIImage *img = [UIPasteboard generalPasteboard].image;
        NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
        NSCharacterSet *separators = [NSCharacterSet alphanumericCharacterSet].invertedSet;
        
        if (str) {
            [set addObject:str];
            [set addObjectsFromArray:[str componentsSeparatedByCharactersInSet:separators]];
        }
        
        if (img && &CIDetectorTypeQRCode) {
            @synchronized ([CIContext class]) {
                CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@(YES)}];
                
                if (! context) context = [CIContext context];

                for (CIQRCodeFeature *qr in [[CIDetector detectorOfType:CIDetectorTypeQRCode context:context
                                              options:nil] featuresInImage:[CIImage imageWithCGImage:img.CGImage]]) {
                    [set addObject:[qr.messageString
                                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                }
            }
        }
    
        for (NSString *s in set) {
            BRPaymentRequest *req = [BRPaymentRequest requestWithString:s];
            
            if ([req.paymentAddress isValidBitcoinAddress]) {
                text = (req.label.length > 0) ? sanitizeString(req.label) : req.paymentAddress;
                break;
            }
            else if ([s hasPrefix:@"litecoin:"]) {
                text = sanitizeString(s);
                break;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat textWidth = [text sizeWithAttributes:@{NSFontAttributeName:self.clipboardText.font}].width + 12;

            self.clipboardText.text = text;
            if (textWidth < self.clipboardButton.bounds.size.width ) textWidth = self.clipboardButton.bounds.size.width;
            if (textWidth > self.view.bounds.size.width - 16.0) textWidth = self.view.bounds.size.width - 16.0;
            self.clipboardXLeft.constant = (self.view.bounds.size.width - textWidth)/2.0;
            [self.clipboardText scrollRangeToVisible:NSMakeRange(0, 0)];
        });
    });
}

- (void)payFirstFromArray:(NSArray *)array
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSUInteger i = 0;

    for (NSString *str in array) {
        BRPaymentRequest *req = [BRPaymentRequest requestWithString:str];
        NSData *data = str.hexToData.reverse;
        
        i++;
        
        // if the clipboard contains a known txHash, we know it's not a hex encoded private key
        if (data.length == sizeof(UInt256) && [manager.wallet transactionForHash:*(UInt256 *)data.bytes]) continue;
        
        if ([req.paymentAddress isValidBitcoinAddress] || [str isValidBitcoinPrivateKey] ||
            [str isValidBitcoinBIP38Key] || (req.r.length > 0 && [req.scheme isEqual:@"litecoin"])) {
            [self performSelector:@selector(confirmRequest:) withObject:req afterDelay:0.1];// delayed to show highlight
            return;
        }
        else if (req.r.length > 0) { // may be BIP73 url: https://github.com/bitcoin/bips/blob/master/bip-0073.mediawiki
            [BRPaymentRequest fetch:req.r timeout:5.0 completion:^(BRPaymentProtocolRequest *req, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) { // don't try any more BIP73 urls
                        [self payFirstFromArray:[array objectsAtIndexes:[array
                        indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                            return (idx >= i && ([obj hasPrefix:@"litecoin:"] || ! [NSURL URLWithString:obj]));
                        }]]];
                    }
                    else [self confirmProtocolRequest:req];
                });
            }];
            
            return;
        }
    }
    
    [[[UIAlertView alloc] initWithTitle:@""
      message:NSLocalizedString(@"clipboard doesn't contain a valid bitcoin address", nil) delegate:nil
      cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
    [self performSelector:@selector(cancel:) withObject:self afterDelay:0.1];
}

// MARK: - IBAction

- (IBAction)tip:(id)sender
{
    if ([self nextTip]) return;

    if (! [sender isKindOfClass:[UIGestureRecognizer class]] || ! [[sender view] isKindOfClass:[UILabel class]]) {
        if (! [sender isKindOfClass:[UIViewController class]]) return;
        self.showTips = YES;
    }

//    self.tipView = [BRBubbleView viewWithText:SCAN_TIP
//                    tipPoint:CGPointMake(self.scanButton.center.x, self.scanButton.center.y - 10.0)
//                    tipDirection:BRBubbleTipDirectionDown];
//    self.tipView.backgroundColor = [UIColor orangeColor];
//    self.tipView.font = [UIFont fontWithName:@"HelveticaNeue" size:15.0];
//    [self.view addSubview:[self.tipView popIn]];
}

- (IBAction)scanQR:(id)sender
{
    [BREventManager saveEvent:@"send:scan_qr"];
    if (! [sender isEqual:self.scanButton]) self.showBalance = YES;
    [sender setEnabled:NO];
    self.scanController.delegate = self;
    self.scanController.transitioningDelegate = self;
    [self.navigationController presentViewController:self.scanController animated:YES completion:nil];
}

- (IBAction)tapPay:(id)sender {
    // TODO:- Test that this works
    // Clear up stuff that's not needed.
    
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
    if (manager.didAuthenticate) {
        
        if ([self nextTip]) return;
        self.amount = [manager amountForString:self.amountField.text];
        
        if (self.amount == 0){
            [BREventManager saveEvent:@"amount:pay_zero"];
            return;
        }
        
        [BREventManager saveEvent:@"amount:pay"];
        [BREventManager saveEvent:@"send:pay_clipboard"];
        
        NSString *str = [[UIPasteboard generalPasteboard].string
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        UIImage *img = [UIPasteboard generalPasteboard].image;
        NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
        NSCharacterSet *separators = [NSCharacterSet alphanumericCharacterSet].invertedSet;
        
        if (str) {
            [set addObject:str];
            [set addObjectsFromArray:[str componentsSeparatedByCharactersInSet:separators]];
        }
        
        if (img && &CIDetectorTypeQRCode) {
            @synchronized ([CIContext class]) {
                CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@(YES)}];
            
                if (! context) context = [CIContext context];
            
                for (CIQRCodeFeature *qr in [[CIDetector detectorOfType:CIDetectorTypeQRCode context:context options:nil]
                                         featuresInImage:[CIImage imageWithCGImage:img.CGImage]]) {
                    [set addObject:[qr.messageString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                }
            }
        }

        self.clearClipboard = YES;
        [self payFirstFromArray:set.array];
        
    } else if (! manager.didAuthenticate){
        UIAlertView *authRequired = [[UIAlertView alloc] initWithTitle:@"Unlock Wallet" message:@"You must unlock your wallet first. Tap the padlock on the top-right of the screen to unlock." delegate:self cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil];
        [authRequired show];
    }
}

- (IBAction)reset:(id)sender
{
    if (self.navigationController.topViewController != self.parentViewController.parentViewController) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    [BREventManager saveEvent:@"send:reset"];

    if (self.clearClipboard) [UIPasteboard generalPasteboard].string = @"";
    self.request = nil;
    [self cancel:sender];
}

- (IBAction)cancel:(id)sender
{
    [BREventManager saveEvent:@"send:cancel"];
    self.url = self.callback = nil;
    self.sweepTx = nil;
    self.amount = 0;
    self.okAddress = self.okIdentity = nil;
    self.clearClipboard = self.useClipboard = NO;
    self.canChangeAmount = self.showBalance = NO;
    self.scanButton.enabled = self.clipboardButton.enabled = YES;
    [self updateClipboardText];
}

// MARK: - BRAmountViewControllerDelegate

- (void)amountViewController:(BRAmountViewController *)amountViewController selectedAmount:(uint64_t)amount
{
    self.amount = amount;
    [self confirmProtocolRequest:self.request];
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects
fromConnection:(AVCaptureConnection *)connection
{
    for (AVMetadataMachineReadableCodeObject *codeObject in metadataObjects) {
        if (! [codeObject.type isEqual:AVMetadataObjectTypeQRCode]) continue;
        
        [BREventManager saveEvent:@"send:scanned_qr"];
        
        NSString *addr = [codeObject.stringValue stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        BRPaymentRequest *request = [BRPaymentRequest requestWithString:addr];
        if (request.url && [BRBitID isBitIDURL:request.url]) {
            [self.scanController stop];
            [self.navigationController dismissViewControllerAnimated:YES completion:^{
                [self handleBitIDURL:request.url];
                [self resetQRGuide];
            }];
        } else if ((request.isValid && [request.scheme isEqual:@"litecoin"]) || [addr isValidBitcoinPrivateKey] ||
                   [addr isValidBitcoinBIP38Key]) {
            self.scanController.cameraGuide.image = [UIImage imageNamed:@"cameraguide-green"];
            [self.scanController stop];
            [BREventManager saveEvent:@"send:valid_qr_scan"];

            if (request.r.length > 0) { // start fetching payment protocol request right away
                [BRPaymentRequest fetch:request.r timeout:5.0
                completion:^(BRPaymentProtocolRequest *req, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (error) request.r = nil;
                    
                        if (error && ! request.isValid) {
                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                              message:error.localizedDescription delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
                            [self cancel:nil];
                            // continue here and handle the invalid request inside confirmRequest:
                        }

                        [self.navigationController dismissViewControllerAnimated:YES completion:^{
                            [self resetQRGuide];
                        }];
                        
                        if (error) {
                            [BREventManager saveEvent:@"send:unsuccessful_qr_payment_protocol_fetch"];
                            [self confirmRequest:request]; // payment protocol fetch failed, so use standard request
                        }
                        else {
                            [BREventManager saveEvent:@"send:successful_qr_payment_protocol_fetch"];
                            [self confirmProtocolRequest:req];
                        }
                    });
                }];
            }
            else { // standard non payment protocol request
                [self.navigationController dismissViewControllerAnimated:YES completion:^{
                    [self resetQRGuide];
                    if (request.amount > 0) self.canChangeAmount = YES;
                }];
                
                if (request.isValid && self.showBalance) {
                    [self showBalance:request.paymentAddress];
                    [self cancel:nil];
                }
                else [self confirmRequest:request];
            }
        } else {
            [BRPaymentRequest fetch:request.r timeout:5.0
            completion:^(BRPaymentProtocolRequest *req, NSError *error) { // check to see if it's a BIP73 url
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetQRGuide) object:nil];
                    
                    if (req) {
                        self.scanController.cameraGuide.image = [UIImage imageNamed:@"cameraguide-green"];
                        [self.scanController stop];
                        
                        [self.navigationController dismissViewControllerAnimated:YES completion:^{
                            [self resetQRGuide];
                        }];
                        
                        [BREventManager saveEvent:@"send:successful_bip73"];
                        [self confirmProtocolRequest:req];
                    }
                    else {
                        self.scanController.cameraGuide.image = [UIImage imageNamed:@"cameraguide-red"];
                        
                        if (([request.scheme isEqual:@"litecoin"] && request.paymentAddress.length > 1) ||
                            [request.paymentAddress hasPrefix:@"L"] || [request.paymentAddress hasPrefix:@"3"]) {
                            self.scanController.message.text = [NSString stringWithFormat:@"%@:\n%@",
                                                                NSLocalizedString(@"not a valid bitcoin address", nil),
                                                                request.paymentAddress];
                        }
                        else self.scanController.message.text = NSLocalizedString(@"not a bitcoin QR code", nil);
                        
                        [self performSelector:@selector(resetQRGuide) withObject:nil afterDelay:0.35];
                        [BREventManager saveEvent:@"send:unsuccessful_bip73"];
                    }
                });
            }];
        }

        break;
    }
}

// MARK: - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
    
    if (buttonIndex == alertView.cancelButtonIndex || [title isEqual:NSLocalizedString(@"cancel", nil)]) {
        if (self.url) {
            self.clearClipboard = YES;
            [self handleURL:self.url];
        }
        else [self cancelOrChangeAmount];
    }
    else if (self.sweepTx) {
        [(id)self.parentViewController.parentViewController startActivityWithTimeout:30];

        [[BRPeerManager sharedInstance] publishTransaction:self.sweepTx completion:^(NSError *error) {
            [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];

            if (error) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't sweep balance", nil)
                  message:error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil)
                  otherButtonTitles:nil] show];
                [self cancel:nil];
                return;
            }

            [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"swept!", nil)
                                     center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)]
                                    popIn] popOutAfterDelay:2.0]];
            [self reset:nil];
        }];
    }
    else if (self.request) {
        [self confirmProtocolRequest:self.request];
    }
    else if (self.url) [self handleURL:self.url];
}

// MARK: UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    if ([self nextTip]) return NO;
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    //BUG: XXX this needs to take keyboard size into account
    self.useClipboard = NO;
    self.clipboardText.text = [UIPasteboard generalPasteboard].string;
    [textView scrollRangeToVisible:textView.selectedRange];
    
//    [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//        self.view.center = CGPointMake(self.view.center.x, self.view.bounds.size.height/2.0 - 100.0);
//        self.sendLabel.alpha = 0.0;
//    } completion:nil];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
//    [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
//        self.view.center = CGPointMake(self.view.center.x, self.view.bounds.size.height/2.0);
//        self.sendLabel.alpha = 1.0;
//    } completion:nil];
    
    if (! self.useClipboard) [UIPasteboard generalPasteboard].string = textView.text;
    [self updateClipboardText];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text isEqual:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }
    
    if (text.length > 0 || range.length > 0) self.useClipboard = NO;
    return YES;
}

// MARK: UIViewControllerAnimatedTransitioning

// This is used for percent driven interactive transitions, as well as for container controllers that have companion
// animations that might need to synchronize with the main animation.
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.35;
}

// This method can only be a nop if the transition is interactive and not a percentDriven interactive transition.
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIView *containerView = transitionContext.containerView;
    UIViewController *to = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey],
                     *from = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIImageView *img = self.scanButton.imageView;
    UIView *guide = self.scanController.cameraGuide;

    [self.scanController.view layoutIfNeeded];

    if (to == self.scanController) {
        [containerView addSubview:to.view];
        to.view.frame = from.view.frame;
        to.view.center = CGPointMake(to.view.center.x, containerView.frame.size.height*3/2);
        guide.transform = CGAffineTransformMakeScale(img.bounds.size.width/guide.bounds.size.width,
                                                     img.bounds.size.height/guide.bounds.size.height);
        guide.alpha = 0;

        [UIView animateWithDuration:0.1 animations:^{
            img.alpha = 0.0;
            guide.alpha = 1.0;
        }];

        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 usingSpringWithDamping:0.8
        initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            to.view.center = from.view.center;
        } completion:^(BOOL finished) {
            img.alpha = 1.0;
            [transitionContext completeTransition:YES];
        }];

        [UIView animateWithDuration:0.8 delay:0.15 usingSpringWithDamping:0.5 initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut animations:^{
            guide.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [to.view addSubview:guide];
        }];
    }
    else {
        [containerView insertSubview:to.view belowSubview:from.view];
        [self cancel:nil];

        [UIView animateWithDuration:0.8 delay:0.0 usingSpringWithDamping:0.5 initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseIn animations:^{
            guide.transform = CGAffineTransformMakeScale(img.bounds.size.width/guide.bounds.size.width,
                                                         img.bounds.size.height/guide.bounds.size.height);
            guide.alpha = 0.0;
        } completion:^(BOOL finished) {
            guide.transform = CGAffineTransformIdentity;
            guide.alpha = 1.0;
        }];

        [UIView animateWithDuration:[self transitionDuration:transitionContext] - 0.15 delay:0.15
        options:UIViewAnimationOptionCurveEaseIn animations:^{
            from.view.center = CGPointMake(from.view.center.x, containerView.frame.size.height*3/2);
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
        }];
    }
}

// MARK: - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return self;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return self;
}

@end
