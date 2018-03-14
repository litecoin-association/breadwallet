//
//  NSString+Bitcoin.m
//  BreadWallet
//
//  Created by Aaron Voisine on 5/13/13.
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

#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"

static const UniChar base58chars[] = {
    '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
};

@implementation NSString (Bitcoin)

+ (NSString *)base58WithData:(NSData *)d
{
    if (! d) return nil;
    
    size_t i, z = 0;
    
    while (z < d.length && ((const uint8_t *)d.bytes)[z] == 0) z++; // count leading zeroes
    
    uint8_t buf[(d.length - z)*138/100 + 1]; // log(256)/log(58), rounded up

    memset(buf, 0, sizeof(buf));

    for (i = z; i < d.length; i++) {
        uint32_t carry = ((const uint8_t *)d.bytes)[i];

        for (size_t j = sizeof(buf); j > 0; j--) {
            carry += (uint32_t)buf[j - 1] << 8;
            buf[j - 1] = carry % 58;
            carry /= 58;
        }
        
        memset(&carry, 0, sizeof(carry));
    }

    i = 0;
    while (i < sizeof(buf) && buf[i] == 0) i++; // skip leading zeroes

    CFMutableStringRef s = CFStringCreateMutable(SecureAllocator(), z + sizeof(buf) - i);
    
    while (z-- > 0) CFStringAppendCharacters(s, &base58chars[0], 1);
    while (i < sizeof(buf)) CFStringAppendCharacters(s, &base58chars[buf[i++]], 1);
    memset(buf, 0, sizeof(buf));
    return CFBridgingRelease(s);
}

+ (NSString *)base58checkWithData:(NSData *)d
{
    if (! d) return nil;
    
    NSMutableData *data = [NSMutableData secureDataWithData:d];

    [data appendBytes:d.SHA256_2.u32 length:4];
    return [self base58WithData:data];
}

+ (NSString *)hexWithData:(NSData *)d
{
    if (! d) return nil;
    
    const uint8_t *bytes = d.bytes;
    NSMutableString *hex = CFBridgingRelease(CFStringCreateMutable(SecureAllocator(), d.length*2));
    
    for (NSUInteger i = 0; i < d.length; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    
    return hex;
}

// NOTE: It's important here to be permissive with scriptSig (spends) and strict with scriptPubKey (receives). If we
// miss a receive transaction, only that transaction's funds are missed, however if we accept a receive transaction that
// we are unable to correctly sign later, then the entire wallet balance after that point would become stuck with the
// current coin selection code
+ (NSString *)addressWithScriptPubKey:(NSData *)script
{
    if (script == (id)[NSNull null]) return nil;

    NSArray *elem = [script scriptElements];
    NSUInteger l = elem.count;
    NSMutableData *d = [NSMutableData data];
    uint8_t v = BITCOIN_PUBKEY_ADDRESS;

#if BITCOIN_TESTNET
    v = BITCOIN_PUBKEY_ADDRESS_TEST;
#endif

    if (l == 5 && [elem[0] intValue] == OP_DUP && [elem[1] intValue] == OP_HASH160 && [elem[2] intValue] == 20 &&
        [elem[3] intValue] == OP_EQUALVERIFY && [elem[4] intValue] == OP_CHECKSIG) {
        // pay-to-pubkey-hash scriptPubKey
        [d appendBytes:&v length:1];
        [d appendData:elem[2]];
    }
    else if (l == 3 && [elem[0] intValue] == OP_HASH160 && [elem[1] intValue] == 20 && [elem[2] intValue] == OP_EQUAL) {
        // pay-to-script-hash scriptPubKey
        v = BITCOIN_SCRIPT_ADDRESS;
#if BITCOIN_TESTNET
        v = BITCOIN_SCRIPT_ADDRESS_TEST;
#endif
        [d appendBytes:&v length:1];
        [d appendData:elem[1]];
    }
    else if (l == 2 && ([elem[0] intValue] == 65 || [elem[0] intValue] == 33) && [elem[1] intValue] == OP_CHECKSIG) {
        // pay-to-pubkey scriptPubKey
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[0] hash160].u8 length:sizeof(UInt160)];
    }
    else return nil; // unknown script type

    return [self base58checkWithData:d];
}

+ (NSString *)addressWithScriptSig:(NSData *)script
{
    if (script == (id)[NSNull null]) return nil;

    NSArray *elem = [script scriptElements];
    NSUInteger l = elem.count;
    NSMutableData *d = [NSMutableData data];
    uint8_t v = BITCOIN_PUBKEY_ADDRESS;

#if BITCOIN_TESTNET
    v = BITCOIN_PUBKEY_ADDRESS_TEST;
#endif

    if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 && [elem[l - 2] intValue] > 0 &&
        ([elem[l - 1] intValue] == 65 || [elem[l - 1] intValue] == 33)) { // pay-to-pubkey-hash scriptSig
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[l - 1] hash160].u8 length:sizeof(UInt160)];
    }
    else if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 && [elem[l - 2] intValue] > 0 &&
             [elem[l - 1] intValue] <= OP_PUSHDATA4 && [elem[l - 1] intValue] > 0) { // pay-to-script-hash scriptSig
        v = BITCOIN_SCRIPT_ADDRESS;
#if BITCOIN_TESTNET
        v = BITCOIN_SCRIPT_ADDRESS_TEST;
#endif
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[l - 1] hash160].u8 length:sizeof(UInt160)];
    }
    else if (l >= 1 && [elem[l - 1] intValue] <= OP_PUSHDATA4 && [elem[l - 1] intValue] > 0) {// pay-to-pubkey scriptSig
        //TODO: implement Peter Wullie's pubKey recovery from signature
        return nil;
    }
    else return nil; // unknown script type
    
    return [self base58checkWithData:d];
}

- (NSData *)base58ToData
{
    size_t i, z = 0;
    
    while (z < self.length && [self characterAtIndex:z] == base58chars[0]) z++; // count leading zeroes
    
    uint8_t buf[(self.length - z)*733/1000 + 1]; // log(58)/log(256), rounded up
    
    memset(buf, 0, sizeof(buf));
    
    for (i = z; i < self.length; i++) {
        uint32_t carry = [self characterAtIndex:i];

        switch (carry) {
            case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9':
                carry -= '1';
                break;

            case 'A': case 'B': case 'C': case 'D': case 'E': case 'F': case 'G': case 'H':
                carry += 9 - 'A';
                break;

            case 'J': case 'K': case 'L': case 'M': case 'N':
                carry += 17 - 'J';
                break;

            case 'P': case 'Q': case 'R': case 'S': case 'T': case 'U': case 'V': case 'W': case 'X': case 'Y':
            case 'Z':
                carry += 22 - 'P';
                break;

            case 'a': case 'b': case 'c': case 'd': case 'e': case 'f': case 'g': case 'h': case 'i': case 'j':
            case 'k':
                carry += 33 - 'a';
                break;

            case 'm': case 'n': case 'o': case 'p': case 'q': case 'r': case 's': case 't': case 'u': case 'v':
            case 'w': case 'x': case 'y': case 'z':
                carry += 44 - 'm';
                break;

            default:
                carry = UINT32_MAX;
        }
        
        if (carry >= 58) break; // invalid base58 digit
        
        for (size_t j = sizeof(buf); j > 0; j--) {
            carry += (uint32_t)buf[j - 1]*58;
            buf[j - 1] = carry & 0xff;
            carry >>= 8;
        }
        
        memset(&carry, 0, sizeof(carry));
    }
    
    i = 0;
    while (i < sizeof(buf) && buf[i] == 0) i++; // skip leading zeroes

    NSMutableData *d = [NSMutableData secureDataWithCapacity:z + sizeof(buf) - i];

    d.length = z;
    [d appendBytes:&buf[i] length:sizeof(buf) - i];
    memset(buf, 0, sizeof(buf));
    return d;
}

- (NSData *)base58checkToData
{
    NSData *d = self.base58ToData;
    
    if (d.length < 4) return nil;

    NSData *data = CFBridgingRelease(CFDataCreate(SecureAllocator(), d.bytes, d.length - 4));

    // verify checksum
    if (*(uint32_t *)((const uint8_t *)d.bytes + d.length - 4) != data.SHA256_2.u32[0]) return nil;
    return data;
}

- (NSData *)hexToData
{
    if (self.length % 2) return nil;
    
    NSMutableData *d = [NSMutableData secureDataWithCapacity:self.length/2];
    uint8_t b = 0;
    
    for (NSUInteger i = 0; i < self.length; i++) {
        unichar c = [self characterAtIndex:i];
        
        switch (c) {
            case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9':
                b += c - '0';
                break;

            case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
                b += c + 10 - 'A';
                break;

            case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
                b += c + 10 - 'a';
                break;

            default:
                return d;
        }
        
        memset(&c, 0, sizeof(c));
        
        if (i % 2) {
            [d appendBytes:&b length:1];
            memset(&b, 0, sizeof(b));
        }
        else b *= 16;
    }
    
    return d;
}

- (NSData *)addressToHash160
{
    NSData *d = self.base58checkToData;

    return (d.length == 160/8 + 1) ? [d subdataWithRange:NSMakeRange(1, d.length - 1)] : nil;
}

- (BOOL)isValidBitcoinAddress
{
    NSData *d = self.base58checkToData;
    
    if (d.length != 21) return NO;
    
    uint8_t version = *(const uint8_t *)d.bytes;
        
#if BITCOIN_TESTNET
    return (version == BITCOIN_PUBKEY_ADDRESS_TEST || version == BITCOIN_SCRIPT_ADDRESS_TEST) ? YES : NO;
#endif

    return (version == BITCOIN_PUBKEY_ADDRESS || version == BITCOIN_SCRIPT_ADDRESS) ? YES : NO;
}

- (BOOL)isValidBitcoinPrivateKey
{
    NSData *d = self.base58checkToData;
    
    if (d.length == 33 || d.length == 34) { // wallet import format: https://en.bitcoin.it/wiki/Wallet_import_format
#if BITCOIN_TESTNET
        return (*(const uint8_t *)d.bytes == BITCOIN_PRIVKEY_TEST) ? YES : NO;
#else
        return (*(const uint8_t *)d.bytes == BITCOIN_PRIVKEY) ? YES : NO;
#endif
    }
    else if ((self.length == 30 || self.length == 22) && [self characterAtIndex:0] == 'S') { // mini private key format
        NSMutableData *d = [NSMutableData secureDataWithCapacity:self.length + 1];

        d.length = self.length;
        [self getBytes:d.mutableBytes maxLength:d.length usedLength:NULL encoding:NSUTF8StringEncoding options:0
         range:NSMakeRange(0, self.length) remainingRange:NULL];
        [d appendBytes:"?" length:1];
        return (d.SHA256.u8[0] == 0) ? YES : NO;
    }
    else return (self.hexToData.length == 32) ? YES : NO; // hex encoded key
}

// BIP38 encrypted keys: https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki
- (BOOL)isValidBitcoinBIP38Key
{
    NSData *d = self.base58checkToData;

    if (d.length != 39) return NO; // invalid length

    uint16_t prefix = CFSwapInt16BigToHost(*(const uint16_t *)d.bytes);
    uint8_t flag = ((const uint8_t *)d.bytes)[2];

    if (prefix == BIP38_NOEC_PREFIX) { // non EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == BIP38_NOEC_FLAG && (flag & BIP38_LOTSEQUENCE_FLAG) == 0 &&
                (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else if (prefix == BIP38_EC_PREFIX) { // EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == 0 && (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else return NO; // invalid prefix
}

@end
