//
//  QuickSVGElement.h
//  QuickSVG
//
//  Created by Matthew Newberry on 9/28/12.
//  Copyright (c) 2012 Matthew Newberry. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>

@class QuickSVG;

typedef enum QuickSVGElementType
{
	QuickSVGElementTypeBasicShape = 0,
	QuickSVGElementTypePath,
	QuickSVGElementTypeLink,
	QuickSVGElementTypeText,
	QuickSVGElementTypeUnknown
} QuickSVGElementType;

@interface QuickSVGElement : UIView

@property (nonatomic, weak) QuickSVG *quickSVG;
@property (nonatomic, strong) id object;
@property (nonatomic, strong) NSMutableDictionary *attributes;
@property (nonatomic, strong) UIBezierPath *shapePath;
@property (nonatomic, strong) NSArray *elements;
@property (nonatomic, readonly) CGAffineTransform svgTransform;
@property (nonatomic, strong) NSMutableArray *shapeLayers;

@end