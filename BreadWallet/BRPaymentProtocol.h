//
//  BRPaymentProtocol.h
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

#import <Foundation/Foundation.h>

// BIP70 payment protocol: https://github.com/bitcoin/bips/blob/master/bip-0070.mediawiki

@interface BRPaymentProtocolDetails : NSObject

@property (nonatomic, readonly) NSString *network; // "main" or "test", default is "main"
@property (nonatomic, readonly) NSArray *outputAmounts; // payment amounts in satoshis, default is 0
@property (nonatomic, readonly) NSArray *outputScripts; // where to send payments, one of the standard script forms
@property (nonatomic, readonly) NSTimeInterval time; // request creation time, seconds since 00:00:00 01/01/01, optional
@property (nonatomic, readonly) NSTimeInterval expires; // when this request should be considered invalid, optional
@property (nonatomic, readonly) NSString *memo; // human-readable description of request for the customer, optional
@property (nonatomic, readonly) NSString *paymentURL; // url to send payment and get payment ack, optional
@property (nonatomic, readonly) NSData *merchantData; // arbitrary data to include in the payment message, optional

@property (nonatomic, readonly, getter = toData) NSData *data;

+ (instancetype)detailsWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithNetwork:(NSString *)network outputAmounts:(NSArray *)amounts outputScripts:(NSArray *)scripts
time:(NSTimeInterval)time expires:(NSTimeInterval)expires memo:(NSString *)memo paymentURL:(NSString *)url
merchantData:(NSData *)data;

@end

@interface BRPaymentProtocolRequest : NSObject

@property (nonatomic, readonly) uint32_t version; // default is 1
@property (nonatomic, readonly) NSString *pkiType; // none / x509+sha256 / x509+sha1, default is "none"
@property (nonatomic, readonly) NSData *pkiData; // depends on pkiType, optional
@property (nonatomic, readonly) BRPaymentProtocolDetails *details; // required
@property (nonatomic, readonly) NSData *signature; // pki-dependent signature, optional

@property (nonatomic, readonly, getter = toData) NSData *data;
@property (nonatomic, readonly) NSArray *certs; // array of DER encoded certificates, from pkiData
@property (nonatomic, readonly) BOOL isValid; // true if certificate chain, signature and details.expires are all valid
@property (nonatomic, readonly) NSString *commonName; // common name of signer (set when isValid is called)
@property (nonatomic, readonly) NSString *errorMessage; // error message if there was an error validating the request

+ (instancetype)requestWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithVersion:(uint32_t)version pkiType:(NSString *)type certs:(NSArray *)certs
details:(BRPaymentProtocolDetails *)details signature:(NSData *)sig;

@end

@interface BRPaymentProtocolPayment : NSObject

@property (nonatomic, readonly) NSData *merchantData; // from request.details.merchantData, optional
@property (nonatomic, readonly) NSArray *transactions; // array of signed BRTransaction objs to satisfy details.outputs
@property (nonatomic, readonly) NSArray *refundToAmounts; // refund amounts, if a refund is necessary, default is 0
@property (nonatomic, readonly) NSArray *refundToScripts; // where to send refunds, if a refund is necessary
@property (nonatomic, readonly) NSString *memo; // human-readable message for the merchant, optional

@property (nonatomic, readonly, getter = toData) NSData *data;

+ (instancetype)paymentWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithMerchantData:(NSData *)data transactions:(NSArray *)transactions
refundToAmounts:(NSArray *)amounts refundToScripts:(NSArray *)scripts memo:(NSString *)memo;

@end

@interface BRPaymentProtocolACK : NSObject

@property (nonatomic, readonly) BRPaymentProtocolPayment *payment; // payment message that triggered this ack, required
@property (nonatomic, readonly) NSString *memo; // human-readable message for customer, optional

@property (nonatomic, readonly, getter = toData) NSData *data;

+ (instancetype)ackWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithPayment:(BRPaymentProtocolPayment *)payment andMemo:(NSString *)memo;

@end

