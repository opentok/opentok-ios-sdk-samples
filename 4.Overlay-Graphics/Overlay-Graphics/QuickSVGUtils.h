//
//  QuickSVGUtils.h
//  QuickSVG
//
//  Created by Matthew Newberry on 12/18/12.
//  Copyright (c) 2012 Matthew Newberry. All rights reserved.
//

#import <Foundation/Foundation.h>

CGAffineTransform makeTransform(CGFloat xScale, CGFloat yScale, CGFloat theta, CGFloat tx, CGFloat ty);
CGAffineTransform makeTransformFromSVGScale(NSString *scale);
CGAffineTransform makeTransformFromSVGMatrix(NSString *matrix);
CGAffineTransform makeTransformFromSVGTransform(NSString *svgTransform);

CGFloat getXScale(CGAffineTransform t);
CGFloat getYScale(CGAffineTransform t);
CGFloat getRotation(CGAffineTransform t);

CGFloat aspectScale(CGSize sourceSize, CGSize destSize);

CGAffineTransform CGAffineTransformFromRectToRect(CGRect fromRect, CGRect toRect);
CGAffineTransform CGAffineTransformFromRectToRectKeepAspectRatio(CGRect fromRect, CGRect toRect);

void CGPathForTextWithFont(CGMutablePathRef *path, NSString *text, UIFont *font);