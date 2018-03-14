//
//  BRPaymentProtocol.m
//  BreadWallet
//
//  Created by Aaron Voisine on 4/21/14.
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

#import "BRPaymentProtocol.h"
#import "BRTransaction.h"
#import "NSData+Bitcoin.h"

// BIP70 payment protocol: https://github.com/bitcoin/bips/blob/master/bip-0070.mediawiki

#define PROTOBUF_VARINT   0 // int32, int64, uint32, uint64, sint32, sint64, bool, enum
#define PROTOBUF_64BIT    1 // fixed64, sfixed64, double
#define PROTOBUF_LENDELIM 2 // string, bytes, embedded messages, packed repeated fields
#define PROTOBUF_32BIT    5 // fixed32, sfixed32, float

#define protoBufString(d) [[NSString alloc] initWithData:(d) encoding:NSUTF8StringEncoding]

@interface NSData (ProtoBuf)

- (uint64_t)protoBufVarIntAtOffset:(NSUInteger *)off;
- (NSData *)protoBufLenDelimAtOffset:(NSUInteger *)off;
- (NSUInteger)protoBufFieldAtOffset:(NSUInteger *)off int:(uint64_t *)i data:(NSData **)d;

@end

@implementation NSData (ProtoBuf)

- (uint64_t)protoBufVarIntAtOffset:(NSUInteger *)off
{
    uint64_t varInt = 0;
    uint8_t b = 0x80;
    NSUInteger i = 0;

    while ((b & 0x80) && *off < self.length) {
        b = ((const uint8_t *)self.bytes)[(*off)++];
        varInt += (uint64_t)(b & 0x7f) << 7*i++;
    }

    return (b & 0x80) ? 0 : varInt;
}

- (NSData *)protoBufLenDelimAtOffset:(NSUInteger *)off
{
    NSData *lenDelim = nil;
    NSUInteger len = (NSUInteger)[self protoBufVarIntAtOffset:off];

    if (*off + len <= self.length) lenDelim = [self subdataWithRange:NSMakeRange(*off, len)];
    *off += len;
    return lenDelim;
}

// sets either int or data depending on field type, and returns field key
- (NSUInteger)protoBufFieldAtOffset:(NSUInteger *)off int:(uint64_t *)i data:(NSData **)d
{
    NSUInteger key = (NSUInteger)[self protoBufVarIntAtOffset:off];
    uint64_t varInt = 0;
    NSData *lenDelim = nil;

    switch (key & 0x07) {
        case PROTOBUF_VARINT: varInt = [self protoBufVarIntAtOffset:off]; if (i) *i = varInt; break;
        case PROTOBUF_64BIT: *off += sizeof(uint64_t); break; // not used by payment protocol
        case PROTOBUF_LENDELIM: lenDelim = [self protoBufLenDelimAtOffset:off]; if (d) *d = lenDelim; break;
        case PROTOBUF_32BIT: *off += sizeof(uint32_t); break; // not used by payment protocol
        default: break;
    }

    return key >> 3;
}

@end

@interface NSMutableData (ProtoBuf)

- (void)appendProtoBufVarInt:(uint64_t)i;
- (void)appendProtoBufLenDelim:(NSData *)d;
- (void)appendProtoBufString:(NSString *)s withKey:(NSUInteger)key;
- (void)appendProtoBufData:(NSData *)d withKey:(NSUInteger)key;
- (void)appendProtoBufInt:(uint64_t)i withKey:(NSUInteger)key;

@end

@implementation NSMutableData (ProtoBuf)

- (void)appendProtoBufVarInt:(uint64_t)i
{
    do {
        uint8_t b = i & 0x7f;

        i >>= 7;
        if (i > 0) b |= 0x80;
        [self appendBytes:&b length:1];
    } while (i > 0);
}

- (void)appendProtoBufLenDelim:(NSData *)d
{
    [self appendProtoBufVarInt:d.length];
    [self appendData:d];
}

- (void)appendProtoBufString:(NSString *)s withKey:(NSUInteger)key
{
    [self appendProtoBufVarInt:(key << 3) | PROTOBUF_LENDELIM];
    [self appendProtoBufLenDelim:[s dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)appendProtoBufData:(NSData *)d withKey:(NSUInteger)key
{
    [self appendProtoBufVarInt:(key << 3) | PROTOBUF_LENDELIM];
    [self appendProtoBufLenDelim:d];
}

- (void)appendProtoBufInt:(uint64_t)i withKey:(NSUInteger)key
{
    [self appendProtoBufVarInt:(key << 3) | PROTOBUF_VARINT];
    [self appendProtoBufVarInt:i];
}

@end

typedef enum : NSUInteger {
    output_amount = 1,
    output_script = 2
} output_key;

typedef enum : NSUInteger {
    details_network = 1,
    details_outputs = 2,
    details_time = 3,
    details_expires = 4,
    details_memo = 5,
    details_payment_url = 6,
    details_merchant_data = 7
} details_key;

typedef enum : NSUInteger {
    request_version = 1,
    request_pki_type = 2,
    request_pki_data = 3,
    request_details = 4,
    request_signature = 5
} request_key;

typedef enum : NSUInteger {
    certificates_cert = 1
} certificates_key;

typedef enum : NSUInteger {
    payment_merchant_data = 1,
    payment_transactions = 2,
    payment_refund_to = 3,
    payment_memo = 4
} payment_key;

typedef enum : NSUInteger {
    ack_payment = 1,
    ack_memo = 2
} ack_key;

@interface BRPaymentProtocolDetails ()

@property (nonatomic, strong) NSString *network;
@property (nonatomic, strong) NSArray *outputAmounts;

@end

@implementation BRPaymentProtocolDetails

+ (instancetype)detailsWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithNetwork:(NSString *)network outputAmounts:(NSArray *)amounts outputScripts:(NSArray *)scripts
time:(NSTimeInterval)time expires:(NSTimeInterval)expires memo:(NSString *)memo paymentURL:(NSString *)url
merchantData:(NSData *)data
{
    if (scripts.count == 0 || amounts.count != scripts.count) return nil;
    if (! (self = [self init])) return nil;

    if (network) _network = network;
    _outputAmounts = amounts;
    _outputScripts = scripts;
    _time = time;
    _expires = expires;
    _memo = memo;
    _paymentURL = url;
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    if (! (self = [self init])) return nil;

    NSUInteger off = 0;
    NSMutableArray *amounts = [NSMutableArray array], *scripts = [NSMutableArray array];

    while (off < data.length) {
        uint64_t i = 0, amount = UINT64_MAX;
        NSData *d = nil, *script = nil;
        NSUInteger o = 0;

        switch ([data protoBufFieldAtOffset:&off int:&i data:&d]) {
            case details_network: if (d) _network = protoBufString(d); break;
            case details_outputs: while (o < d.length) [d protoBufFieldAtOffset:&o int:&amount data:&script]; break;
            case details_time: if (i) _time = i - NSTimeIntervalSince1970; break;
            case details_expires: if (i) _expires = i - NSTimeIntervalSince1970; break;
            case details_memo: if (d) _memo = protoBufString(d); break;
            case details_payment_url: if (d) _paymentURL = protoBufString(d); break;
            case details_merchant_data: if (d) _merchantData = d; break;
            default: break;
        }

        if (script) [amounts addObject:@(amount)], [scripts addObject:script];
    }

    if (scripts.count == 0) return nil; // one or more outputs required
    _outputAmounts = amounts;
    _outputScripts = scripts;
    return self;
}

- (NSString *)network
{
    return (_network) ? _network : @"main";
}

- (NSArray *)outputAmounts
{
    if (! [_outputAmounts containsObject:@(UINT64_MAX)]) return _outputAmounts;

    NSMutableArray *amounts = [NSMutableArray arrayWithArray:_outputAmounts];
    
    while ([amounts containsObject:@(UINT64_MAX)]) {
        amounts[[amounts indexOfObject:@(UINT64_MAX)]] = @(0);
    }
    
    return amounts;
}

- (NSData *)toData
{
    NSMutableData *d = [NSMutableData data];
    NSUInteger i = 0;

    if (_network) [d appendProtoBufString:_network withKey:details_network];

    for (NSData *script in _outputScripts) {
        NSMutableData *output = [NSMutableData data];
        uint64_t amount = [_outputAmounts[i++] unsignedLongLongValue];

        if (amount != UINT64_MAX) [output appendProtoBufInt:amount withKey:output_amount];
        [output appendProtoBufData:script withKey:output_script];
        [d appendProtoBufData:output withKey:details_outputs];
    }

    if (_time >= 1) [d appendProtoBufInt:_time + NSTimeIntervalSince1970 withKey:details_time];
    if (_expires >= 1) [d appendProtoBufInt:_expires + NSTimeIntervalSince1970 withKey:details_expires];
    if (_memo) [d appendProtoBufString:_memo withKey:details_memo];
    if (_paymentURL) [d appendProtoBufString:_paymentURL withKey:details_payment_url];
    if (_merchantData) [d appendProtoBufData:_merchantData withKey:details_merchant_data];
    return d;
}

@end

@interface BRPaymentProtocolRequest ()

@property (nonatomic, assign) uint32_t version;
@property (nonatomic, strong) NSString *pkiType;

@end

@implementation BRPaymentProtocolRequest

+ (instancetype)requestWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSData *)data
{
    if (! (self = [self init])) return nil;

    NSUInteger off = 0;

    while (off < data.length) {
        uint64_t i = 0;
        NSData *d = nil;

        switch ([data protoBufFieldAtOffset:&off int:&i data:&d]) {
            case request_version: if (i) _version = (uint32_t)i; break;
            case request_pki_type: if (d) _pkiType = protoBufString(d); break;
            case request_pki_data: if (d) _pkiData = d; break;
            case request_details: if (d) _details = [BRPaymentProtocolDetails detailsWithData:d]; break;
            case request_signature: if (d) _signature = d; break;
            default: break;
        }
    }

    if (! _details) return nil; // required
    return self;
}

- (instancetype)initWithVersion:(uint32_t)version pkiType:(NSString *)type certs:(NSArray *)certs
details:(BRPaymentProtocolDetails *)details signature:(NSData *)sig
{
    if (! details) return nil; // required
    if (! (self = [self init])) return nil;

    if (version) _version = version;
    if (type) _pkiType = type;

    NSMutableData *d = [NSMutableData data];

    for (NSData *cert in certs) {
        [d appendProtoBufData:cert withKey:certificates_cert];
    }

    if (d.length > 0) _pkiData = d;
    _details = details;
    _signature = sig;
    return self;
}

- (uint32_t)version
{
    return (_version) ? _version : 1;
}

- (NSString *)pkiType
{
    return (_pkiType) ? _pkiType : @"none";
}

- (NSData *)toData
{
    NSMutableData *d = [NSMutableData data];

    if (_version) [d appendProtoBufInt:_version withKey:request_version];
    if (_pkiType) [d appendProtoBufString:_pkiType withKey:request_pki_type];
    if (_pkiData) [d appendProtoBufData:_pkiData withKey:request_pki_data];
    [d appendProtoBufData:_details.data withKey:request_details];
    if (_signature) [d appendProtoBufData:_signature withKey:request_signature];
    return d;
}

- (NSArray *)certs
{
    NSMutableArray *certs = [NSMutableArray array];
    NSUInteger off = 0;

    while (off < self.pkiData.length) {
        NSData *d = nil;

        if ([self.pkiData protoBufFieldAtOffset:&off int:nil data:&d] == certificates_cert && d) [certs addObject:d];
    }

    return certs;
}

- (BOOL)isValid
{
    BOOL r = YES;
    
    if (! [self.pkiType isEqual:@"none"]) {
        NSMutableArray *certs = [NSMutableArray array];
        NSArray *policies = @[CFBridgingRelease(SecPolicyCreateBasicX509())];
        SecTrustRef trust = NULL;
        SecTrustResultType trustResult = kSecTrustResultInvalid;

        for (NSData *d in self.certs) {
            SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)d);
            
            if (cert) [certs addObject:CFBridgingRelease(cert)];
        }

        if (certs.count > 0) {
            _commonName = CFBridgingRelease(SecCertificateCopySubjectSummary((__bridge SecCertificateRef)certs[0]));
        }

        SecTrustCreateWithCertificates((__bridge CFArrayRef)certs, (__bridge CFArrayRef)policies, &trust);
        if (trust) SecTrustEvaluate(trust, &trustResult); // verify certificate chain

        // kSecTrustResultUnspecified indicates a positive result that wasn't decided by the user
        if (trustResult != kSecTrustResultUnspecified && trustResult != kSecTrustResultProceed) {
            _errorMessage = (certs.count > 0) ? NSLocalizedString(@"untrusted certificate", nil) :
                            NSLocalizedString(@"missing certificate", nil);

            for (NSDictionary *property in CFBridgingRelease(SecTrustCopyProperties(trust))) {
                if (! [property[@"type"] isEqual:(__bridge id)kSecPropertyTypeError]) continue;
                _errorMessage = [_errorMessage stringByAppendingFormat:@" - %@", property[@"value"]];
                break;
            }
            
            r = NO;
        }

        SecKeyRef pubKey = (trust) ? SecTrustCopyPublicKey(trust) : NULL;
        OSStatus status = errSecUnimplemented;
        NSData *sig = _signature;

        _signature = [NSData data]; // set signature to 0 bytes, a signature can't sign itself

        if (pubKey && [self.pkiType isEqual:@"x509+sha256"]) {
            status = SecKeyRawVerify(pubKey, kSecPaddingPKCS1SHA256, self.data.SHA256.u8, sizeof(UInt256), sig.bytes,
                                     sig.length);
        }
        else if (pubKey && [self.pkiType isEqual:@"x509+sha1"]) {
            status = SecKeyRawVerify(pubKey, kSecPaddingPKCS1SHA1, self.data.SHA1.u8, sizeof(UInt160), sig.bytes,
                                     sig.length);
        }
        
        _signature = sig;
        if (pubKey) CFRelease(pubKey);
        if (trust) CFRelease(trust);

        if (status != errSecSuccess) {
            if (status == errSecUnimplemented) {
                _errorMessage = NSLocalizedString(@"unsupported signature type", nil);
                NSLog(@"%@", _errorMessage);
            }
            else {
                _errorMessage = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
                                 userInfo:nil].localizedDescription;
                NSLog(@"SecKeyRawVerify error: %@", _errorMessage);
            }
            
            r = NO;
        }
    }
    else if (self.certs.firstObject) { // non-standard extention to include an un-certified request name
        _commonName = [[NSString alloc] initWithData:self.certs.firstObject encoding:NSUTF8StringEncoding];
    }

    if (r && self.details.expires >= 1 && [NSDate timeIntervalSinceReferenceDate] > self.details.expires) {
        _errorMessage = NSLocalizedString(@"request expired", nil);
        r = NO;
    }

    return r;
}

@end

@interface BRPaymentProtocolPayment ()

@property (nonatomic, strong) NSArray *refundToAmounts;

@end

@implementation BRPaymentProtocolPayment

+ (instancetype)paymentWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSData *)data
{
    if (! (self = [self init])) return nil;

    NSUInteger off = 0;
    NSMutableArray *txs = [NSMutableArray array], *amounts = [NSMutableArray array], *scripts = [NSMutableArray array];

    while (off < data.length) {
        uint64_t i = 0, amount = UINT64_MAX;
        NSData *d = nil, *script = nil;
        BRTransaction *tx = nil;
        NSUInteger o = 0;

        switch ([data protoBufFieldAtOffset:&off int:&i data:&d]) {
            case payment_merchant_data: if (d) _merchantData = d; break;
            case payment_transactions: if (d) tx = [BRTransaction transactionWithMessage:d]; break;
            case payment_refund_to: while (o < d.length) [d protoBufFieldAtOffset:&o int:&amount data:&script]; break;
            case payment_memo: if (d) _memo = protoBufString(d); break;
            default: break;
        }

        if (tx) [txs addObject:tx];
        if (script) [amounts addObject:@(amount)], [scripts addObject:script];
    }

    _transactions = txs;
    _refundToAmounts = amounts;
    _refundToScripts = scripts;
    return self;
}

- (instancetype)initWithMerchantData:(NSData *)data transactions:(NSArray *)transactions
refundToAmounts:(NSArray *)amounts refundToScripts:(NSArray *)scripts memo:(NSString *)memo
{
    if (amounts.count != scripts.count) return nil;
    if (! (self = [self init])) return nil;

    _merchantData = data;
    _transactions = transactions;
    _refundToAmounts = amounts;
    _refundToScripts = scripts;
    _memo = memo;
    return self;
}

- (NSArray *)refundToAmounts
{
    if (! [_refundToAmounts containsObject:@(UINT64_MAX)]) return _refundToAmounts;
    
    NSMutableArray *amounts = [NSMutableArray arrayWithArray:_refundToAmounts];
    
    while ([amounts containsObject:@(UINT64_MAX)]) {
        amounts[[amounts indexOfObject:@(UINT64_MAX)]] = @(0);
    }
    
    return amounts;
}

- (NSData *)toData
{
    NSMutableData *d = [NSMutableData data];
    NSUInteger i = 0;

    if (_merchantData) [d appendProtoBufData:_merchantData withKey:payment_merchant_data];

    for (BRTransaction *tx in _transactions) {
        [d appendProtoBufData:tx.data withKey:payment_transactions];
    }

    for (NSData *script in _refundToScripts) {
        NSMutableData *output = [NSMutableData data];
        uint64_t amount = [_refundToAmounts[i++] unsignedLongLongValue];
        
        if (amount != UINT64_MAX) [output appendProtoBufInt:amount withKey:output_amount];
        [output appendProtoBufData:script withKey:output_script];
        [d appendProtoBufData:output withKey:payment_refund_to];
    }

    if (_memo) [d appendProtoBufString:_memo withKey:payment_memo];
    return d;
}

@end

@implementation BRPaymentProtocolACK

+ (instancetype)ackWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSData *)data
{
    if (! (self = [self init])) return nil;

    NSUInteger off = 0;

    while (off < data.length) {
        uint64_t i = 0;
        NSData *d = nil;

        switch ([data protoBufFieldAtOffset:&off int:&i data:&d]) {
            case ack_payment: if (d) _payment = [BRPaymentProtocolPayment paymentWithData:d]; break;
            case ack_memo: if (d) _memo = protoBufString(d); break;
            default: break;
        }
    }

    if (! _payment) return nil; // required
    return self;
}

- (instancetype)initWithPayment:(BRPaymentProtocolPayment *)payment andMemo:(NSString *)memo
{
    if (! payment) return nil; // required
    if (! (self = [self init])) return nil;

    _payment = payment;
    _memo = memo;
    return self;
}

- (NSData *)toData
{
    NSMutableData *d = [NSMutableData data];

    [d appendProtoBufData:_payment.data withKey:ack_payment];
    if (_memo) [d appendProtoBufString:_memo withKey:ack_memo];
    return d;
}

@end
