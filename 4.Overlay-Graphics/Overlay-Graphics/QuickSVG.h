//
//  QuickSVG.h
//  QuickSVG
//
//  Created by Matthew Newberry on 9/26/12.
//  Copyright (c) 2012 Matthew Newberry. All rights reserved.
//

@class QuickSVGElement, QuickSVG, QuickSVGParser;
@protocol QuickSVGParserDelegate;

@protocol QuickSVGDelegate <NSObject>

@optional
- (BOOL) quickSVG:(QuickSVG *)quickSVG shouldSelectInstance:(QuickSVGElement *)instance;
- (void) quickSVG:(QuickSVG *)quickSVG didSelectInstance:(QuickSVGElement *)instance;
@end

@interface QuickSVG : NSObject <NSXMLParserDelegate>

@property (nonatomic, weak) id <QuickSVGDelegate> delegate;
@property (nonatomic) id <QuickSVGParserDelegate> parserDelegate;
@property (nonatomic, strong) QuickSVGParser *parser;

@property (nonatomic, strong) UIView *view;

// This allows you to have visible layers within the SVG that are ignored by the renderer
// Useful for creating templates with elements that you do not want to be displayed in the final
// product
//
// Default - XXX
@property (nonatomic, strong) NSString *ignorePattern;

// Instead of rendering text as a CATextLayer, optionally render text as a path
// inside a CAShapeLayer for better scaling
//
// Default - YES
@property (nonatomic, assign) BOOL shouldTreatTextAsPaths;

// The parsed frame that encapsulates the entire SVG document
@property (nonatomic, assign) CGRect canvasFrame;


// Syncronous shortcut
+ (QuickSVG *)svgFromURL:(NSURL *) url;

// A shortcut to the parser
- (BOOL)parseSVGFileWithURL:(NSURL *) url;

- (BOOL)parseSVGString:(NSString *)string;


- (id)initWithDelegate:(id<QuickSVGDelegate>)delegate;
@end
