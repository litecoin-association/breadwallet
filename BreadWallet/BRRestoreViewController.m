//
//  BRRestoreViewController.m
//  BreadWallet
//
//  Created by Aaron Voisine on 6/13/13.
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

#import "BRRestoreViewController.h"
#import "BRWalletManager.h"
#import "BRMnemonic.h"
#import "BRAddressEntity.h"
#import "NSMutableData+Bitcoin.h"
#import "NSString+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "BREventManager.h"

#define PHRASE_LENGTH 12


@interface BRRestoreViewController ()

@property (nonatomic, strong) IBOutlet UITextView *textView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *textViewYBottom;
@property (nonatomic, strong) id keyboardObserver, resignActiveObserver;

@end

@implementation BRRestoreViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // TODO: create secure versions of keyboard and UILabel and use in place of UITextView
    // TODO: autocomplete based on 4 letter prefixes of mnemonic words
    
    self.textView.layer.cornerRadius = 5.0;
    
    self.keyboardObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification object:nil queue:nil
        usingBlock:^(NSNotification *note) {
            [UIView animateWithDuration:[note.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue] delay:0.0
             options:[note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] animations:^{
                 self.textViewYBottom.constant =
                     [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height + 12.0;
                 [self.view layoutIfNeeded];
             } completion:nil];
        }];
    
    self.resignActiveObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            self.textView.text = nil;
        }];

    if (self.navigationController.viewControllers.firstObject != self) return;
    
    self.textView.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.25].CGColor;
    self.textView.layer.borderWidth = 0.5;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.textView becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.textView.text = nil;
    
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.keyboardObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.keyboardObserver];
    if (self.resignActiveObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.resignActiveObserver];
}

- (void)wipeWithPhrase:(NSString *)phrase
{
    [BREventManager saveEvent:@"restore:wipe"];
    
    @autoreleasepool {
        BRWalletManager *manager = [BRWalletManager sharedInstance];
        
        if ([phrase isEqual:@"wipe"]) phrase = manager.seedPhrase; // this triggers authentication request
        
        if ([[manager.sequence masterPublicKeyFromSeed:[manager.mnemonic deriveKeyFromPhrase:phrase withPassphrase:nil]]
             isEqual:manager.masterPublicKey] || [phrase isEqual:@"wipe"]) {
            [BREventManager saveEvent:@"restore:wipe_good_recovery_phrase"];
            [[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil)
              destructiveButtonTitle:NSLocalizedString(@"wipe", nil) otherButtonTitles:nil]
             showInView:[UIApplication sharedApplication].keyWindow];
        }
        else if (phrase) {
            [BREventManager saveEvent:@"restore:wipe_bad_recovery_phrase"];
            [[[UIAlertView alloc] initWithTitle:@"" message:NSLocalizedString(@"recovery phrase doesn't match", nil)
              delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        }
        else [self.textView becomeFirstResponder];
    }
}

#pragma mark - IBAction

- (IBAction)cancel:(id)sender
{
    [BREventManager saveEvent:@"restore:cancel"];
    
    if (self.navigationController.presentingViewController) {
        [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
    else [self.navigationController popViewControllerAnimated:NO];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    static NSCharacterSet *invalid = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet letterCharacterSet];

        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        invalid = set.invertedSet;
    });

    if (! [text isEqual:@"\n"]) return YES; // not done entering phrase
    
    @autoreleasepool {  // @autoreleasepool ensures sensitive data will be deallocated immediately
        BRWalletManager *manager = [BRWalletManager sharedInstance];
        NSString *phrase = [manager.mnemonic cleanupPhrase:textView.text], *incorrect = nil;
        BOOL isLocal = YES, noWallet = manager.noWallet;
        
        if (! [textView.text hasPrefix:@"watch"] && ! [phrase isEqual:textView.text]) textView.text = phrase;
        phrase = [manager.mnemonic normalizePhrase:phrase];
        
        NSArray *a = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(), (CFStringRef)phrase,
                                                                              CFSTR(" ")));

        for (NSString *word in a) {
            if (! [manager.mnemonic wordIsLocal:word]) isLocal = NO;
            if ([manager.mnemonic wordIsValid:word]) continue;
            incorrect = word;
            break;
        }

        if ([phrase isEqual:@"wipe"]) { // shortcut word to force the wipe option to appear
            [self.textView resignFirstResponder];
            [self performSelector:@selector(wipeWithPhrase:) withObject:phrase afterDelay:0.0];
        }
        else if (incorrect && noWallet && [textView.text hasPrefix:@"watch"]) { // address list watch only wallet
            manager.seedPhrase = @"wipe";

            [[NSManagedObject context] performBlockAndWait:^{
                int32_t n = 0;
                
                for (NSString *s in [textView.text componentsSeparatedByCharactersInSet:[NSCharacterSet
                                     alphanumericCharacterSet].invertedSet]) {
                    if (! [s isValidBitcoinAddress]) continue;
                    
                    BRAddressEntity *e = [BRAddressEntity managedObject];
                    
                    e.address = s;
                    e.index = n++;
                    e.internal = NO;
                }
            }];
            
            [NSManagedObject saveContext];
            textView.text = nil;
            [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        }
        else if (incorrect) {
            [BREventManager saveEvent:@"restore:invalid_word"];
            textView.selectedRange = [textView.text.lowercaseString rangeOfString:incorrect];
        
            [[[UIAlertView alloc] initWithTitle:@""
              message:[NSString stringWithFormat:NSLocalizedString(@"\"%@\" is not a recovery phrase word", nil),
                       incorrect] delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil]
             show];
        }
        else if (a.count != PHRASE_LENGTH) {
            [BREventManager saveEvent:@"restore:invalid_num_words"];
            [[[UIAlertView alloc] initWithTitle:@""
              message:[NSString stringWithFormat:NSLocalizedString(@"recovery phrase must have %d words", nil),
                       PHRASE_LENGTH] delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil)
              otherButtonTitles:nil] show];
        }
        else if (isLocal && ! [manager.mnemonic phraseIsValid:phrase]) {
            [BREventManager saveEvent:@"restore:bad_phrase"];
            [[[UIAlertView alloc] initWithTitle:@"" message:NSLocalizedString(@"bad recovery phrase", nil) delegate:nil
              cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        }
        else if (! noWallet) {
            [self.textView resignFirstResponder];
            [self performSelector:@selector(wipeWithPhrase:) withObject:phrase afterDelay:0.0];
        }
        else {
            //TODO: offer the user an option to move funds to a new seed if their wallet device was lost or stolen
            manager.seedPhrase = phrase;
            textView.text = nil;
            [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
    
    return NO;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) return;
    
    if ([[alertView buttonTitleAtIndex:buttonIndex] isEqual:NSLocalizedString(@"close app", nil)]) exit(0);
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.destructiveButtonIndex) {
        [self.textView becomeFirstResponder];
        return;
    }
    
    [[BRWalletManager sharedInstance] setSeedPhrase:nil];
    self.textView.text = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:WALLET_NEEDS_BACKUP_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];

    UIViewController *p = self.navigationController.presentingViewController.presentingViewController;
    
    if (! p) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"the app will now close", nil) message:nil delegate:self
          cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"close app", nil), nil] show];
        return;
    }
    
    [p dismissViewControllerAnimated:NO completion:^{
        [p presentViewController:[self.storyboard instantiateViewControllerWithIdentifier:@"NewWalletNav"] animated:NO
         completion:nil];
    }];
}

@end
