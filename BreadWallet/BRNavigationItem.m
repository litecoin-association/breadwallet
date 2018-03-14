//
//  BRNavigationItem.m
//  LoafWallet
//
//  Created by Sergey Shvedov on 14.06.16.
//  Copyright (c) 2016 Aaron Voisine <voisine@gmail.com>
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

#import "BRNavigationItem.h"

static void *kTitleStateObservingContext = &kTitleStateObservingContext;
static void *kTitleViewStateObservingContext = &kTitleViewStateObservingContext;

@implementation BRNavigationItem

- (instancetype)initWithCoder:(NSCoder *)coder {
	if((self = [super initWithCoder:coder])){
		[self activateObservers];
	}
	return self;
}

- (void)dealloc {
	[self deactivateObservers];
}

- (void)activateObservers {
	[self addObserver: self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context: kTitleStateObservingContext];
	[self addObserver: self forKeyPath:@"titleView" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: kTitleViewStateObservingContext];
}

- (void)deactivateObservers {
	[self removeObserver: self forKeyPath:@"title"];
	[self removeObserver: self forKeyPath:@"titleView"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ( context == kTitleStateObservingContext ) {
		if ((nil == self.title) || ([self.title rangeOfString:@"  TOS"].location == NSNotFound)) {
			self.titleView = nil;
		} else {
			[self updateLabel];
		}
		
	} else if ( context == kTitleViewStateObservingContext ) {
		
		id oldValue = [change objectForKey:@"old"];
		id newValue = [change objectForKey:@"new"];
		
		if ( [NSNull null] != oldValue && [NSNull null] == newValue ) {
			self.title = self.title;
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)updateLabel {
	
	if ( NO == [self.titleView isKindOfClass:[UILabel class]] ) {
		UILabel *newLabel = [[UILabel alloc] init];
		self.titleView = newLabel;
	}
	
	if ( YES == [self.titleView isKindOfClass:[UILabel class]] ) {
		UILabel *label = (UILabel *)self.titleView;
		UIFont *titleFont = [UIFont fontWithName:@"HelveticaNeue-Medium" size:23.0];
		UIFont *smallFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:12.0];
		NSString *simpleString = self.title;
		NSRange range = [simpleString rangeOfString:@"  TOS"];
		range.length = (simpleString.length - range.location);
		
		NSMutableAttributedString *stylizedString = [[NSMutableAttributedString alloc] initWithString:simpleString];
		NSNumber *offsetAmount = @(titleFont.capHeight - smallFont.capHeight);
		[stylizedString addAttribute:NSFontAttributeName value:smallFont range:range];
		[stylizedString addAttribute:NSBaselineOffsetAttributeName value:offsetAmount range:range];
		label.font = titleFont;
		label.attributedText = stylizedString;
		[label sizeToFit];
	}
}

@end
