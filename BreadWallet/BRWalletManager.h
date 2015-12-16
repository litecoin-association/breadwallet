//
//  BRWalletManager.h
//  BreadWallet
//
//  Created by Aaron Voisine on 3/2/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "BRWallet.h"

#define SATOSHIS     1
#define MAX_MONEY    (84000000LL*SATOSHIS)
#define BTC          @"\xC5\x81"     // upper-case Ł with stroke (utf-8)
#define BITS         @"\xC5\x81"     // upper-case Ł with stroke (utf-8)
#define NARROW_NBSP  @"\xE2\x80\xAF" // narrow no-break space (utf-8)
#define LDQUOTE      @"\xE2\x80\x9C" // left double quote (utf-8)
#define RDQUOTE      @"\xE2\x80\x9D" // right double quote (utf-8)
#define DISPLAY_NAME [NSString stringWithFormat:LDQUOTE @"%@" RDQUOTE,\
                      NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"]]

#define WALLET_NEEDS_BACKUP_KEY                @"WALLET_NEEDS_BACKUP"
#define BRWalletManagerSeedChangedNotification @"BRWalletManagerSeedChangedNotification"

@protocol BRMnemonic;

@interface BRWalletManager : NSObject<UIAlertViewDelegate, UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, readonly) BRWallet *wallet;
@property (nonatomic, readonly) BOOL noWallet; // true if keychain is available and we know that no wallet exists on it
@property (nonatomic, readonly) BOOL watchOnly; // true if this is a "watch only" wallet with no signing ability
@property (nonatomic, strong) id<BRKeySequence> sequence;
@property (nonatomic, strong) id<BRMnemonic> mnemonic;
@property (nonatomic, readonly) NSData *masterPublicKey; // master public key used to generate wallet addresses
@property (nonatomic, copy) NSString *seedPhrase; // requesting seedPhrase will trigger authentication
@property (nonatomic, readonly) NSTimeInterval seedCreationTime; // interval since refrence date, 00:00:00 01/01/01 GMT
@property (nonatomic, readonly) NSTimeInterval secureTime; // last known time from an ssl server connection
@property (nonatomic, assign) uint64_t spendingLimit; // amount that can be spent using touch id without pin entry
@property (nonatomic, readonly) NSString *authPrivateKey; // private key for signing authenticated api calls
@property (nonatomic, readonly, getter=isTouchIdEnabled) BOOL touchIdEnabled; // true if touch id is enabled
@property (nonatomic, readonly, getter=isPasscodeEnabled) BOOL passcodeEnabled; // true if device passcode is enabled
@property (nonatomic, assign) BOOL didAuthenticate; // true if the user authenticated after this was last set to false
@property (nonatomic, readonly) NSNumberFormatter *format; // bitcoin currency formatter
@property (nonatomic, readonly) NSNumberFormatter *localFormat; // local currency formatter
@property (nonatomic, copy) NSString *localCurrencyCode; // local currency ISO code
@property (nonatomic, readonly) double localCurrencyPrice; // exchange rate in local currency units per bitcoin
@property (nonatomic, readonly) NSArray *currencyCodes; // list of supported local currency codes
@property (nonatomic, readonly) NSArray *currencyNames; // names for local currency codes

+ (instancetype)sharedInstance;

- (NSString *)generateRandomSeed; // generates a random seed, saves to keychain and returns the associated seedPhrase
- (NSData *)seedWithPrompt:(NSString *)authprompt forAmount:(uint64_t)amount; // authenticates user and returns seed
- (NSString *)seedPhraseWithPrompt:(NSString *)authprompt; // authenticates user and returns seedPhrase
- (BOOL)authenticateWithPrompt:(NSString *)authprompt andTouchId:(BOOL)touchId; // prompts user to authenticate
- (BOOL)setPin; // prompts the user to set or change wallet pin and returns true if the pin was successfully set

// queries chain.com and calls the completion block with unspent outputs for the given address
- (void)utxosForAddress:(NSString *)address
completion:(void (^)(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error))completion;

// given a private key, queries chain.com for unspent outputs and calls the completion block with a signed transaction
// that will sweep the balance into wallet (doesn't publish the tx)
- (void)sweepPrivateKey:(NSString *)privKey withFee:(BOOL)fee
completion:(void (^)(BRTransaction *tx, uint64_t fee, NSError *error))completion;

- (int64_t)amountForString:(NSString *)string;
- (NSString *)stringForAmount:(int64_t)amount;
- (int64_t)amountForLocalCurrencyString:(NSString *)string;
- (NSString *)localCurrencyStringForAmount:(int64_t)amount;

@end
