/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 6.x Edition
 BSD License, Use at your own risk
 */

#import <UIKit/UIKit.h>

#define POINT(_INDEX_) \
[(NSValue *)[points objectAtIndex:_INDEX_] CGPointValue]
#define VALUE(_INDEX_) \
[NSValue valueWithCGPoint:points[_INDEX_]]

@interface UIBezierPath (Additions)

- (UIBezierPath *) fitInRect: (CGRect) destRect;
- (NSArray *) points;
+ (UIBezierPath *) pathWithPoints: (NSArray *) points;

@end
