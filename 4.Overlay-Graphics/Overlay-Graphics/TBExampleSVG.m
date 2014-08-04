//
//  OTSVG.m
//  Overlay-Graphics
//
//  Copyright (c) 2014 Tokbox, Inc. All rights reserved.
//
//

#import "TBExampleSVG.h"
#import "QuickSVG.h"
#import <UIKit/UIKit.h>

@implementation TBExampleSVGHelper

+ (UIImage*)uiimageFromView:(UIView*)view size:(CGSize)size {
    // If scale is 0, it'll follows the screen scale for creating the bounds
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    // Get the image out of the context
    UIImage *copied = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Return the result
    return copied;
}

+ (UIImage*)imageFromSVGString:(NSString*)source {
    return [TBExampleSVGHelper imageFromSVGString:source size:CGSizeZero];
}

+ (UIImage*)imageFromSVGString:(NSString *)source size:(CGSize)size {
    UIView* view = [TBExampleSVGHelper viewFromSVGString:source];
    UIImage* image = [TBExampleSVGHelper uiimageFromView:view size:size];
    return image;
}

+ (UIView*)viewFromSVGString:(NSString*)source {
    QuickSVG* svg = [[[QuickSVG alloc] initWithDelegate:nil] autorelease];
    [svg parseSVGString:source];
    return svg.view;
}

@end

@implementation TBExampleSVGIcons

+ (NSString*)swapCamera {
    return @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"unmute\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    "	 x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\" viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"Layer_5\">"
    "	<path fill=\"#FFFFFF\" d=\"M64.978,27.338c0,0-3.766-8.494-8.407-8.494H40.589c-4.644,0-8.339,8.475-8.339,8.475L8,27.338v49.098h80.5"
    "		l-0.013-49.098H64.978z M54.858,60.419l0.681-0.477l4.945,3.92l-1.067,0.874c-2.498,2.053-5.505,3.332-8.693,3.7"
    "		c-9.521,1.101-18.182-6.012-18.666-15.757l-4.417,0.511l6.093-7.685l0.745-0.94l4.465,3.542l4.158,3.296l-4.909,0.567"
    "		c-0.003,0.355,0.014,0.69,0.051,1.011c0.672,5.819,5.953,10.009,11.772,9.335C51.72,62.119,53.35,61.481,54.858,60.419z"
    "		 M46.87,35.088c9.194-1.062,17.542,5.553,18.603,14.746c0.036,0.307,0.021,0.648,0.039,0.964l4.001-0.462l-4.988,6.295l-1.847,2.33"
    "		l-3.959-3.143l-4.666-3.695l5.351-0.619c-0.001-0.338-0.016-0.656-0.051-0.962c-0.673-5.82-5.956-10.008-11.775-9.335"
    "		c-1.719,0.199-3.361,0.846-4.877,1.924l-0.681,0.483l-4.942-3.918l1.059-0.875C40.64,36.75,43.66,35.459,46.87,35.088z\"/>"
    "</g>"
    "</svg>"
    "";
}

+ (NSString*) microphone {
    return @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"unmute\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    "	 x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\" viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"Layer_6\">"
    "	<g id=\"unmute_3_\">"
    "		<path fill=\"#A2BF42\" d=\"M41.869,71.708c5.465,0,9.897-4.432,9.897-9.898V43.812c0-5.466-4.433-9.897-9.897-9.897"
    "			c-5.465,0-9.897,4.431-9.897,9.897V61.81C31.972,67.276,36.404,71.708,41.869,71.708z\"/>"
    "		<path fill=\"#A2BF42\" d=\"M55.361,52.811v8.999c0,7.442-6.054,13.497-13.497,13.497S28.368,69.252,28.368,61.81v-8.999h-1.8v8.999"
    "			c0,8.172,6.446,14.847,14.517,15.258H40.97v9.058h-8.103v1.799h17.996v-1.799h-8.094v-9.058h-0.124"
    "			c8.07-0.411,14.516-7.086,14.516-15.258v-8.999H55.361z\"/>"
    "	</g>"
    "	<path fill=\"#A2BF42\" d=\"M64.689,36.157l-3.465,0.721c-0.821-3.971-2.859-7.725-6.119-10.618c-3.261-2.893-7.229-4.468-11.271-4.81"
    "		l0.304-3.525c4.774,0.403,9.465,2.265,13.318,5.684S63.718,31.462,64.689,36.157z\"/>"
    "	<path fill=\"#A2BF42\" d=\"M71.616,34.716c-1.27-6.14-4.418-11.938-9.456-16.407c-5.038-4.47-11.173-6.905-17.417-7.434l0.304-3.525"
    "		c6.979,0.592,13.835,3.312,19.465,8.308c5.631,4.995,9.149,11.478,10.568,18.337L71.616,34.716z\"/>"
    "</g>"
    "</svg>"
    "";
}

+ (NSString*)audioOnlyInactive {
    return @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"unmute\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    "	 x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\" viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"Layer_7\">"
    "	<g id=\"unmute_2_\">"
    "		<path fill=\"#666666\" d=\"M40.202,71.708c5.465,0,9.897-4.432,9.897-9.898V43.812c0-5.466-4.433-9.897-9.897-9.897"
    "			c-5.465,0-9.897,4.431-9.897,9.897V61.81C30.305,67.276,34.737,71.708,40.202,71.708z\"/>"
    "		<path fill=\"#666666\" d=\"M53.694,52.812v8.998c0,7.442-6.054,13.497-13.497,13.497S26.701,69.252,26.701,61.81v-8.998h-1.8v8.998"
    "			c0,8.172,6.446,14.847,14.517,15.258h-0.115v9.058H31.2v1.799h17.996v-1.799h-8.094v-9.058h-0.123"
    "			c8.07-0.411,14.516-7.086,14.516-15.258v-8.998H53.694z\"/>"
    "	</g>"
    "	<path fill=\"#666666\" d=\"M63.021,36.157l-3.464,0.721c-0.821-3.971-2.859-7.725-6.119-10.618c-3.261-2.893-7.229-4.468-11.271-4.81"
    "		l0.303-3.525c4.775,0.403,9.465,2.265,13.319,5.684S62.051,31.462,63.021,36.157z\"/>"
    "	<path fill=\"#666666\" d=\"M69.949,34.716c-1.27-6.14-4.418-11.938-9.456-16.407c-5.038-4.47-11.173-6.905-17.417-7.434L43.38,7.35"
    "		c6.979,0.592,13.835,3.312,19.465,8.308c5.631,4.995,9.149,11.478,10.568,18.337L69.949,34.716z\"/>"
    "</g>"
    "</svg>"
    "";
}

+ (NSString*)audioOnlyActive {
    return
    @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"unmute\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    "	 x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\" viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"Layer_6\">"
    "	<g id=\"unmute_3_\">"
    "		<path fill=\"#A2BF42\" d=\"M41.869,71.708c5.465,0,9.897-4.432,9.897-9.898V43.812c0-5.466-4.433-9.897-9.897-9.897"
    "			c-5.465,0-9.897,4.431-9.897,9.897V61.81C31.972,67.276,36.404,71.708,41.869,71.708z\"/>"
    "		<path fill=\"#A2BF42\" d=\"M55.361,52.811v8.999c0,7.442-6.054,13.497-13.497,13.497S28.368,69.252,28.368,61.81v-8.999h-1.8v8.999"
    "			c0,8.172,6.446,14.847,14.517,15.258H40.97v9.058h-8.103v1.799h17.996v-1.799h-8.094v-9.058h-0.124"
    "			c8.07-0.411,14.516-7.086,14.516-15.258v-8.999H55.361z\"/>"
    "	</g>"
    "	<path fill=\"#A2BF42\" d=\"M64.689,36.157l-3.465,0.721c-0.821-3.971-2.859-7.725-6.119-10.618c-3.261-2.893-7.229-4.468-11.271-4.81"
    "		l0.304-3.525c4.774,0.403,9.465,2.265,13.318,5.684S63.718,31.462,64.689,36.157z\"/>"
    "	<path fill=\"#A2BF42\" d=\"M71.616,34.716c-1.27-6.14-4.418-11.938-9.456-16.407c-5.038-4.47-11.173-6.905-17.417-7.434l0.304-3.525"
    "		c6.979,0.592,13.835,3.312,19.465,8.308c5.631,4.995,9.149,11.478,10.568,18.337L71.616,34.716z\"/>"
    "</g>"
    "</svg>"
    "";
}

+ (NSString*)muteSubscriber {
    return @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"unmute\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    "	 x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\" viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"Layer_3\">"
    "	<g id=\"mute_3_\">"
    "		<path fill=\"#FFFFFF\" d=\"M32.992,37.029v12.576c0,8.083,6.554,14.636,14.635,14.636c3.51,0,6.73-1.236,9.253-3.296L32.992,37.029z\""
    "			/>"
    "		<path fill=\"#FFFFFF\" d=\"M62.263,48.771V22.994c0-8.083-6.554-14.634-14.636-14.634c-7.033,0-12.909,4.961-14.314,11.578"
    "			L62.263,48.771z\"/>"
    "		<path fill=\"#FFFFFF\" d=\"M60.754,64.62c-3.512,3.076-8.108,4.943-13.134,4.943c-11.004,0-19.957-8.954-19.957-19.958V36.3h-2.661"
    "			v13.306c0,12.082,9.529,21.953,21.464,22.559h-0.17v13.394H34.315v2.662h26.609v-2.662H48.958V72.164h-0.183"
    "			c5.411-0.273,10.328-2.453,14.088-5.883L60.754,64.62z\"/>"
    "		<path fill=\"#FFFFFF\" d=\"M67.38,52.421c0.13-0.92,0.197-1.86,0.197-2.815V36.3h2.661v13.306c0.001,1.623,0.092,4.852-0.718,5.661"
    "			l-1.974-2.623L67.38,52.421z\"/>"
    "		<polygon fill=\"#FFFFFF\" points=\"14,13.116 78.754,77.871 82.678,73.412 18.166,8.746 		\"/>"
    "	</g>"
    "</g>"
    "</svg>"
    "";
}

+ (NSString*)mutePublisher {
    return @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"unmute\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    "	 x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\" viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"mute\">"
    "	<g id=\"mute_2_\">"
    "		<polygon fill=\"#FFFFFF\" points=\"59.673,69.687 59.673,84.355 40.293,64.979 16.923,64.979 16.923,36.478 27.234,36.478 		\"/>"
    "		<polygon fill=\"#FFFFFF\" points=\"42.933,33.838 59.673,17.098 59.673,50.271 		\"/>"
    "	</g>"
    "	<polygon fill=\"#FFFFFF\" points=\"7.557,12.411 83.642,88.497 87.91,83.646 12.088,7.658 	\"/>"
    "</g>"
    "</svg>"
    "";
}

+ (NSString*)unmuteSubscriber {
    return @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"unmute\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    "	 x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\" viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"Layer_4\">"
    "	<g id=\"unmute_7_\">"
    "		<path fill=\"#FFFFFF\" d=\"M47.064,63.73c8.133,0,14.728-6.594,14.728-14.727V22.226c0-8.134-6.595-14.726-14.728-14.726"
    "			s-14.727,6.592-14.727,14.726v26.778C32.338,57.137,38.932,63.73,47.064,63.73z\"/>"
    "		<path fill=\"#FFFFFF\" d=\"M67.141,35.615v13.389c0,11.072-9.01,20.081-20.082,20.081c-11.074,0-20.083-9.009-20.083-20.081V35.615"
    "			h-2.677v13.389c0,12.157,9.59,22.09,21.598,22.701h-0.171v13.478H33.669v2.676h26.777v-2.676H48.404V71.705h-0.186"
    "			c12.01-0.611,21.599-10.544,21.599-22.701V35.615H67.141z\"/>"
    "	</g>"
    "</g>"
    "</svg>"
    "";
}

+ (NSString*)unmutePublisher {
    return @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    "<!-- Generator: Adobe Illustrator 16.2.1, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->"
    "<svg version=\"1.2\" baseProfile=\"tiny\" id=\"_x31_0_device_access_switch_camera\""
    "	 xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" x=\"0px\" y=\"0px\" width=\"96px\" height=\"96px\""
    "	 viewBox=\"0 0 96 96\" xml:space=\"preserve\">"
    "<g id=\"unmute_4_\">"
    "	<polygon fill=\"#FFFFFF\" points=\"43.372,75.313 27.393,59.337 8.122,59.337 8.122,35.836 27.393,35.836 43.372,19.857 	\"/>"
    "	<path fill=\"#FFFFFF\" d=\"M53.738,65.804l-3.764-2.801c3.217-4.311,5.148-9.636,5.148-15.417c0-5.781-1.932-11.104-5.148-15.414"
    "		l3.764-2.803c3.804,5.092,6.084,11.385,6.084,18.217S57.542,60.709,53.738,65.804z\"/>"
    "	<path fill=\"#FFFFFF\" d=\"M61.267,71.408c4.973-6.663,7.953-14.89,7.953-23.822c0-8.931-2.982-17.161-7.953-23.821l3.763-2.802"
    "		c5.557,7.444,8.891,16.64,8.891,26.623s-3.334,19.179-8.891,26.624L61.267,71.408z\"/>"
    "	<path fill=\"#FFFFFF\" d=\"M72.606,79.851c6.729-9.009,10.716-20.18,10.716-32.264c0-12.085-3.987-23.254-10.716-32.266l3.79-2.82"
    "		c7.301,9.79,11.626,21.935,11.626,35.086c0,13.153-4.325,25.294-11.626,35.085L72.606,79.851z\"/>"
    "</g>"
    "</svg>"
    "";
}


@end