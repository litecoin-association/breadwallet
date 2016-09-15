//
//  BRBouncyBurgerButton.m
//
//  Created by Aaron Voisine on 6/5/14.
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

#import "BRBouncyBurgerButton.h"

#define BAR_WIDTH   20.0
#define BAR_HEIGHT  2.0
#define BAR_SPACING 7.0

@interface BRBouncyBurgerButton ()

@property (nonatomic, strong) UIView *bar1, *bar2, *bar3;

@end

@implementation BRBouncyBurgerButton

- (instancetype)customInitWithSize:(CGSize)size
{
    CGFloat x = size.width/2.0, y = size.height/2.0;

    self.bar1 = [[UIView alloc] initWithFrame:CGRectMake(x - BAR_WIDTH/2.0, y - BAR_SPACING, BAR_WIDTH, BAR_HEIGHT)];
    self.bar2 = [[UIView alloc] initWithFrame:CGRectMake(x - BAR_WIDTH/2.0, y, BAR_WIDTH, BAR_HEIGHT)];
    self.bar3 = [[UIView alloc] initWithFrame:CGRectMake(x - BAR_WIDTH/2.0, y + BAR_SPACING, BAR_WIDTH, BAR_HEIGHT)];
    self.bar1.userInteractionEnabled = self.bar2.userInteractionEnabled = self.bar3.userInteractionEnabled = NO;
    self.bar1.backgroundColor = self.bar2.backgroundColor = self.bar3.backgroundColor = self.currentTitleColor;
    [self addSubview:self.bar1];
    [self addSubview:self.bar2];
    [self addSubview:self.bar3];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (! (self = [super initWithCoder:aDecoder])) return nil;
    return [self customInitWithSize:self.intrinsicContentSize];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (! (self = [super initWithFrame:frame])) return nil;
    return [self customInitWithSize:frame.size];
}

- (void)setX:(BOOL)x
{
    [self setX:x completion:nil];
}

- (void)setX:(BOOL)x completion:(void (^)(BOOL finished))completion;
{
    _x = x;

    [UIView animateWithDuration:0.1 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.bar1.transform = CGAffineTransformMakeRotation(M_PI_4*(x ? 1.5 : -0.35));
        self.bar1.center = CGPointMake(self.bar1.center.x, self.bar2.center.y - (x ? 0.0 : BAR_SPACING));
        self.bar2.alpha = (x) ? 0.0 : 1.0;
        self.bar3.transform = CGAffineTransformMakeRotation(M_PI_4*(x ? -1.5 : 0.35));
        self.bar3.center = CGPointMake(self.bar3.center.x, self.bar2.center.y + (x ? 0.0 : BAR_SPACING));
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.8 delay:0.0 usingSpringWithDamping:0.3 initialSpringVelocity:0.0
         options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.bar1.transform = CGAffineTransformMakeRotation(x ? M_PI_4 : 0.0);
            self.bar3.transform = CGAffineTransformMakeRotation(x ? -M_PI_4 : 0.0);
        } completion:completion];
    }];
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
    [super setTitleColor:color forState:state];
    self.bar1.backgroundColor = self.bar2.backgroundColor = self.bar3.backgroundColor = self.currentTitleColor;
}

- (void)setHighlighted:(BOOL)highlighted
{
    super.highlighted = highlighted;
    self.bar1.backgroundColor = self.bar2.backgroundColor = self.bar3.backgroundColor = self.currentTitleColor;
}

- (void)setEnabled:(BOOL)enabled
{
    super.enabled = enabled;
    self.bar1.backgroundColor = self.bar2.backgroundColor = self.bar3.backgroundColor = self.currentTitleColor;
}

- (void)setSelected:(BOOL)selected
{
    super.selected = selected;
    self.bar1.backgroundColor = self.bar2.backgroundColor = self.bar3.backgroundColor = self.currentTitleColor;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(BAR_WIDTH, BAR_SPACING*2 + BAR_HEIGHT);
}

@end
