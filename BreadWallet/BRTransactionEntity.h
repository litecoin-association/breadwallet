//
//  BRTransactionEntity.h
//  BreadWallet
//
//  Created by Aaron Voisine on 8/22/13.
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BRTxInputEntity;
@class BRTxOutputEntity;
@class BRTransaction;

@interface BRTransactionEntity : NSManagedObject

@property (nonatomic, retain) NSData *txHash;
@property (nonatomic) int32_t blockHeight;
@property (nonatomic) NSTimeInterval timestamp;
@property (nonatomic, retain) NSOrderedSet *inputs;
@property (nonatomic, retain) NSOrderedSet *outputs;
@property (nonatomic) int32_t lockTime;

- (instancetype)setAttributesFromTx:(BRTransaction *)tx;
- (BRTransaction *)transaction;

@end

// These generated accessors are all broken because NSOrderedSet is not a subclass of NSSet.
// This known core data bug has remained unaddressed for over three years: http://openradar.appspot.com/10114310
// Per core data release notes, use [NSObject<NSKeyValueCoding> mutableOrderedSetValueForKey:] instead.
@interface BRTransactionEntity (CoreDataGeneratedAccessors)

- (void)insertObject:(BRTxInputEntity *)value inInputsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromInputsAtIndex:(NSUInteger)idx;
- (void)insertInputs:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeInputsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInInputsAtIndex:(NSUInteger)idx withObject:(BRTxInputEntity *)value;
- (void)replaceInputsAtIndexes:(NSIndexSet *)indexes withInputs:(NSArray *)values;
- (void)addInputsObject:(BRTxInputEntity *)value;
- (void)removeInputsObject:(BRTxInputEntity *)value;
- (void)addInputs:(NSOrderedSet *)values;
- (void)removeInputs:(NSOrderedSet *)values;
- (void)insertObject:(BRTxOutputEntity *)value inOutputsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromOutputsAtIndex:(NSUInteger)idx;
- (void)insertOutputs:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeOutputsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInOutputsAtIndex:(NSUInteger)idx withObject:(BRTxOutputEntity *)value;
- (void)replaceOutputsAtIndexes:(NSIndexSet *)indexes withOutputs:(NSArray *)values;
- (void)addOutputsObject:(BRTxOutputEntity *)value;
- (void)removeOutputsObject:(BRTxOutputEntity *)value;
- (void)addOutputs:(NSOrderedSet *)values;
- (void)removeOutputs:(NSOrderedSet *)values;
@end
