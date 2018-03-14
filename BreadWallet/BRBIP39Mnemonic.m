//
//  BRBIP39Mnemonic.m
//  BreadWallet
//
//  Created by Aaron Voisine on 3/21/14.
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

#import "BRBIP39Mnemonic.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"

#define WORDS @"BIP39Words"

#define IDEO_SP @"\xE3\x80\x80" // ideographic space (utf-8)

// BIP39 is method for generating a deterministic wallet seed from a mnemonic phrase
// https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki

@interface BRBIP39Mnemonic ()

@property (nonatomic, strong) NSArray *words;
@property (nonatomic, strong) NSSet *allWords;

@end

@implementation BRBIP39Mnemonic

- (NSArray *)words
{
    if (! _words) {
        _words = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:WORDS ofType:@"plist"]];
    }
    
    return _words;
}

- (NSSet *)allWords
{
    if (! _allWords) {
        NSMutableSet *allWords = [NSMutableSet set];
        
        for (NSString *lang in [NSBundle mainBundle].localizations) {
            [allWords addObjectsFromArray:[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle]
             pathForResource:WORDS ofType:@"plist" inDirectory:nil forLocalization:lang]]];
        }

        _allWords = allWords;
    }
    
    return _allWords;
}

- (NSString *)encodePhrase:(NSData *)data
{
    if (! data || (data.length % 4) != 0) return nil; // data length must be a multiple of 32 bits

    uint32_t n = (uint32_t)self.words.count, x;
    NSMutableArray *a =
        CFBridgingRelease(CFArrayCreateMutable(SecureAllocator(), data.length*3/4, &kCFTypeArrayCallBacks));
    NSMutableData *d = [NSMutableData secureDataWithData:data];
    UInt256 sha256 = data.SHA256;

    [d appendBytes:&sha256 length:sizeof(sha256)]; // append SHA256 checksum

    for (int i = 0; i < data.length*3/4; i++) {
        x = CFSwapInt32BigToHost(*(const uint32_t *)((const uint8_t *)d.bytes + i*11/8));
        [a addObject:self.words[(x >> (sizeof(x)*8 - (11 + ((i*11) % 8)))) % n]];
    }

    memset(&x, 0, sizeof(x));
    return CFBridgingRelease(CFStringCreateByCombiningStrings(SecureAllocator(), (CFArrayRef)a, CFSTR(" ")));
}

// phrase must be normalized
- (NSData *)decodePhrase:(NSString *)phrase
{
    NSArray *a = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(),
                                   (CFStringRef)[self normalizePhrase:phrase], CFSTR(" ")));
    NSMutableData *d = [NSMutableData secureDataWithCapacity:(a.count*11 + 7)/8];
    uint32_t n = (uint32_t)self.words.count, x, y;
    uint8_t b;

    if ((a.count % 3) != 0 || a.count > 24) {
        NSLog(@"phrase has wrong number of words");
        return nil;
    }

    for (int i = 0; i < (a.count*11 + 7)/8; i++) {
        x = (uint32_t)[self.words indexOfObject:a[i*8/11]];
        y = (i*8/11 + 1 < a.count) ? (uint32_t)[self.words indexOfObject:a[i*8/11 + 1]] : 0;

        if (x == (uint32_t)NSNotFound || y == (uint32_t)NSNotFound) {
            NSLog(@"phrase contained unknown word: %@", a[i*8/11 + (x == (uint32_t)NSNotFound ? 0 : 1)]);
            return nil;
        }

        b = ((x*n + y) >> ((i*8/11 + 2)*11 - (i + 1)*8)) & 0xff;
        [d appendBytes:&b length:1];
    }

    b = *((const uint8_t *)d.bytes + a.count*4/3) >> (8 - a.count/3);
    d.length = a.count*4/3;

    if (b != (d.SHA256.u8[0] >> (8 - a.count/3))) {
        NSLog(@"incorrect phrase, bad checksum");
        return nil;
    }

    memset(&x, 0, sizeof(x));
    memset(&y, 0, sizeof(y));
    memset(&b, 0, sizeof(b));
    return d;
}

// true if word is a member of any known word list
- (BOOL)wordIsValid:(NSString *)word
{
    return [self.allWords containsObject:word];
}

// true if word is a member of the word list for the current locale
- (BOOL)wordIsLocal:(NSString *)word
{
    return [self.words containsObject:word];
}

// true if all words and checksum are valid, phrase must be normalized
- (BOOL)phraseIsValid:(NSString *)phrase
{
    return ([self decodePhrase:phrase] == nil) ? NO : YES;
}

// minimally cleans up user input phrase, suitable for display/editing
- (NSString *)cleanupPhrase:(NSString *)phrase
{
    static NSCharacterSet *invalid = nil, *ws = nil;
    static dispatch_once_t onceToken = 0;
    NSMutableString *s = CFBridgingRelease(CFStringCreateMutableCopy(SecureAllocator(), 0,
                                                                     (CFStringRef)phrase));
    
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet letterCharacterSet];
        
        ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        [set formUnionWithCharacterSet:ws];
        invalid = set.invertedSet;
    });
    
    while ([s rangeOfCharacterFromSet:invalid].location != NSNotFound) {
        [s deleteCharactersInRange:[s rangeOfCharacterFromSet:invalid]]; // remove invalid chars
    }
    
    [s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, s.length)];
    while ([s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, s.length)] > 0);
    while ([s rangeOfCharacterFromSet:ws].location == 0) [s deleteCharactersInRange:NSMakeRange(0, 1)]; // trim lead ws
    phrase = [self normalizePhrase:s];
    
    if (! [self phraseIsValid:phrase]) {
        NSArray *a = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(),
                                                                              (CFStringRef)phrase, CFSTR(" ")));
        
        for (NSString *word in a) { // add spaces between words for ideographic langauges
            if (word.length < 1 || [word characterAtIndex:0] < 0x3000 || [self wordIsValid:word]) continue;
            
            for (NSUInteger i = 0; i < word.length; i++) {
                for (NSUInteger j = (word.length - i > 8) ? 8 : word.length - i; j; j--) {
                    NSString *w  = [word substringWithRange:NSMakeRange(i, j)];
                    
                    if (! [self wordIsValid:w]) continue;
                    [s replaceOccurrencesOfString:w withString:[NSString stringWithFormat:IDEO_SP @"%@" IDEO_SP, w]
                                          options:0 range:NSMakeRange(0, s.length)];
                    while ([s replaceOccurrencesOfString:IDEO_SP IDEO_SP withString:IDEO_SP options:0
                                                   range:NSMakeRange(0, s.length)] > 0);
                    CFStringTrimWhitespace((CFMutableStringRef)s);
                    i += j - 1;
                    break;
                }
            }
        }
    }
    
    return s;
}

// normalizes phrase, suitable for decode/derivation
- (NSString *)normalizePhrase:(NSString *)phrase
{
    if (! phrase) return nil;

    NSMutableString *s = CFBridgingRelease(CFStringCreateMutableCopy(SecureAllocator(), 0, (CFStringRef)phrase));
    NSMutableCharacterSet *ws = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    CFRange r;

    CFStringNormalize((CFMutableStringRef)s, kCFStringNormalizationFormKD);
    CFStringLowercase((CFMutableStringRef)s, CFLocaleGetSystem());
    CFStringTrimWhitespace((CFMutableStringRef)s);
    [ws removeCharactersInString:@" "];
    
    while (CFStringFindCharacterFromSet((CFStringRef)s, (CFCharacterSetRef)ws, CFRangeMake(0, s.length), 0, &r)) {
        [s replaceCharactersInRange:NSMakeRange(r.location, r.length) withString:@" "];
    }
    
    while ([s rangeOfString:@"  "].location != NSNotFound) {
        [s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, s.length)];
    }
        
    return s;
}

// phrase must be normalized
- (NSData *)deriveKeyFromPhrase:(NSString *)phrase withPassphrase:(NSString *)passphrase
{
    if (! phrase) return nil;
    
    NSMutableData *key = [NSMutableData secureDataWithLength:sizeof(UInt512)];
    NSData *password, *salt;
    CFMutableStringRef pw = CFStringCreateMutableCopy(SecureAllocator(), 0, (CFStringRef)phrase);
    CFMutableStringRef s = CFStringCreateMutableCopy(SecureAllocator(), 0, CFSTR("mnemonic"));

    if (passphrase) CFStringAppend(s, (CFStringRef)passphrase);
    CFStringNormalize(pw, kCFStringNormalizationFormKD);
    CFStringNormalize(s, kCFStringNormalizationFormKD);
    password = CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), pw, kCFStringEncodingUTF8, 0));
    salt = CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), s, kCFStringEncodingUTF8, 0));
    CFRelease(pw);
    CFRelease(s);

    PBKDF2(key.mutableBytes, key.length, SHA512, 64, password.bytes, password.length, salt.bytes, salt.length, 2048);
    return key;
}

@end
