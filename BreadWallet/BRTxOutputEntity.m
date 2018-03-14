//
//  BRTxOutputEntity.m
//  BreadWallet
//
//  Created by Aaron Voisine on 8/26/13.
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

#import "BRTxOutputEntity.h"
#import "BRTransactionEntity.h"
#import "BRTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"

@implementation BRTxOutputEntity

@dynamic txHash;
@dynamic n;
@dynamic address;
@dynamic script;
@dynamic value;
@dynamic spent;
@dynamic transaction;

- (instancetype)setAttributesFromTx:(BRTransaction *)tx outputIndex:(NSUInteger)index
{
    [self.managedObjectContext performBlockAndWait:^{
        UInt256 txHash = tx.txHash;
    
        self.txHash = [NSData dataWithBytes:&txHash length:sizeof(txHash)];
        self.n = (int32_t)index;
        self.address = (tx.outputAddresses[index] == [NSNull null]) ? nil : tx.outputAddresses[index];
        self.script = tx.outputScripts[index];
        self.value = [tx.outputAmounts[index] longLongValue];
    }];
    
    return self;
}

@end
