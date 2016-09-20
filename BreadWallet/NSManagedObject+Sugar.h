//
//  NSManagedObject+Sugar.h
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

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface NSManagedObject (Sugar)

// create objects
+ (instancetype)managedObject;
+ (NSArray *)managedObjectArrayWithLength:(NSUInteger)length;

// fetch existing objects
+ (NSArray *)allObjects;
+ (NSArray *)objectsMatching:(NSString *)predicateFormat, ...;
+ (NSArray *)objectsMatching:(NSString *)predicateFormat arguments:(va_list)args;
+ (NSArray *)objectsSortedBy:(NSString *)key ascending:(BOOL)ascending;
+ (NSArray *)objectsSortedBy:(NSString *)key ascending:(BOOL)ascending offset:(NSUInteger)offset limit:(NSUInteger)lim;
+ (NSArray *)fetchObjects:(NSFetchRequest *)request;

// count existing objects
+ (NSUInteger)countAllObjects;
+ (NSUInteger)countObjectsMatching:(NSString *)predicateFormat, ...;
+ (NSUInteger)countObjectsMatching:(NSString *)predicateFormat arguments:(va_list)args;
+ (NSUInteger)countObjects:(NSFetchRequest *)request;

// delete objects
+ (NSUInteger)deleteObjects:(NSArray *)objects;

// call this before any NSManagedObject+Sugar methods to use a concurrency type other than NSMainQueueConcurrencyType
+ (void)setConcurrencyType:(NSManagedObjectContextConcurrencyType)type;

// set the fetchBatchSize to use when fetching objects, default is 100
+ (void)setFetchBatchSize:(NSUInteger)fetchBatchSize;

// returns the managed object context for the application, or if the context doesn't already exist, creates it and binds
// it to the persistent store coordinator for the application
+ (NSManagedObjectContext *)context;

// sets a different context for NSManagedObject+Sugar methods to use for this type of entity
+ (void)setContext:(NSManagedObjectContext *)context;

+ (void)saveContext; // persists changes (this is called automatically for the main context when the app terminates)

+ (NSString *)entityName; // override this if entity name differs from class name
+ (NSFetchRequest *)fetchReq;
+ (NSFetchedResultsController *)fetchedResultsController:(NSFetchRequest *)request;

- (id)objectForKeyedSubscript:(id<NSCopying>)key; // id value = entity[@"key"]; thread safe valueForKey:
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key; // entity[@"key"] = value; thread safe setValue:forKey:
- (void)deleteObject;

@end
