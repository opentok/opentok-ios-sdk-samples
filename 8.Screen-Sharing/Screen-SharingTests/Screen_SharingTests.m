//
//  Screen_SharingTests.m
//  Screen-SharingTests
//
//  Created by Steve McFarlin on 8/27/14.
//  Copyright (c) 2014 TokBox Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TBScreenCapture.h"

@interface Screen_SharingTests : XCTestCase

@end

@implementation Screen_SharingTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNoChangeNeeded
{
    CGSize inputSize =
    CGSizeMake(MAX_EDGE_SIZE_LIMIT - EDGE_DIMENSION_COMMON_FACTOR,
               MAX_EDGE_SIZE_LIMIT - EDGE_DIMENSION_COMMON_FACTOR);
    CGSize desiredContainer = inputSize;
    CGRect desiredDrawRect = CGRectMake(0, 0,
                                        desiredContainer.width,
                                        desiredContainer.height);
    CGSize outputContainerSize = CGSizeZero;
    CGRect outputDrawRect = CGRectZero;
    [TBScreenCapture dimensionsForInputSize:inputSize
                              containerSize:&outputContainerSize
                                   drawRect:&outputDrawRect];
    XCTAssert(CGSizeEqualToSize(desiredContainer, outputContainerSize));
    XCTAssert(CGRectEqualToRect(desiredDrawRect, outputDrawRect));
}

- (void)testApplyPadding
{
    CGSize inputSize = CGSizeMake(1280, 964);
    // scale will add 12px to y
    CGSize desiredContainer = CGSizeMake(1280, 976);
    // padd will offset 6px on top and bottom
    CGRect desiredDrawRect = CGRectMake(0, 6, 1280, 964);
    CGSize outputContainerSize = CGSizeZero;
    CGRect outputDrawRect = CGRectZero;
    [TBScreenCapture dimensionsForInputSize:inputSize
                              containerSize:&outputContainerSize
                                   drawRect:&outputDrawRect];
    XCTAssert(CGSizeEqualToSize(desiredContainer, outputContainerSize));
    XCTAssert(CGRectEqualToRect(desiredDrawRect, outputDrawRect));
}

- (void)testApplyPaddingTall
{
    CGSize inputSize = CGSizeMake(964, 1280);
    // scale will add 12px to y
    CGSize desiredContainer = CGSizeMake(976, 1280);
    // padd will offset 6px on left and right
    CGRect desiredDrawRect = CGRectMake(6, 0, 964, 1280);
    CGSize outputContainerSize = CGSizeZero;
    CGRect outputDrawRect = CGRectZero;
    [TBScreenCapture dimensionsForInputSize:inputSize
                              containerSize:&outputContainerSize
                                   drawRect:&outputDrawRect];
    XCTAssert(CGSizeEqualToSize(desiredContainer, outputContainerSize));
    XCTAssert(CGRectEqualToRect(desiredDrawRect, outputDrawRect));
}

- (void)testScalingAndPadding
{
    // input size will break edge limit, aspect ratio will break padding rule
    CGSize inputSize = CGSizeMake(1600, 1210);
    CGSize desiredContainer = CGSizeMake(1280, 976);
    CGRect desiredDrawRect = CGRectMake(0, 4, 1280, 968);
    CGSize outputContainerSize = CGSizeZero;
    CGRect outputDrawRect = CGRectZero;
    [TBScreenCapture dimensionsForInputSize:inputSize
                              containerSize:&outputContainerSize
                                   drawRect:&outputDrawRect];
    XCTAssert(CGSizeEqualToSize(desiredContainer, outputContainerSize));
    XCTAssert(CGRectEqualToRect(desiredDrawRect, outputDrawRect));
}

- (void)testScalingAndPaddingTall
{
    // input size will break edge limit, aspect ratio will break padding rule
    CGSize inputSize = CGSizeMake(1210, 1600);
    CGSize desiredContainer = CGSizeMake(976, 1280);
    CGRect desiredDrawRect = CGRectMake(4, 0, 968, 1280);
    CGSize outputContainerSize = CGSizeZero;
    CGRect outputDrawRect = CGRectZero;
    [TBScreenCapture dimensionsForInputSize:inputSize
                              containerSize:&outputContainerSize
                                   drawRect:&outputDrawRect];
    XCTAssert(CGSizeEqualToSize(desiredContainer, outputContainerSize));
    XCTAssert(CGRectEqualToRect(desiredDrawRect, outputDrawRect));
}

- (void)testWidthOversizeNoPadding
{
    CGSize inputSize = CGSizeMake(18000, 9000);
    CGSize desiredContainer = CGSizeMake(MAX_EDGE_SIZE_LIMIT,
                                         MAX_EDGE_SIZE_LIMIT / 2);
    CGRect desiredDrawRect = CGRectMake(0, 0,
                                        MAX_EDGE_SIZE_LIMIT,
                                        MAX_EDGE_SIZE_LIMIT / 2);
    CGSize outputContainerSize = CGSizeZero;
    CGRect outputDrawRect = CGRectZero;
    [TBScreenCapture dimensionsForInputSize:inputSize
                              containerSize:&outputContainerSize
                                   drawRect:&outputDrawRect];
    XCTAssert(CGSizeEqualToSize(desiredContainer, outputContainerSize));
    XCTAssert(CGRectEqualToRect(desiredDrawRect, outputDrawRect));
}

- (void)testWidthOversizeNoPaddingTall
{
    CGSize inputSize = CGSizeMake(9000, 18000);
    CGSize desiredContainer = CGSizeMake(MAX_EDGE_SIZE_LIMIT / 2,
                                         MAX_EDGE_SIZE_LIMIT);
    CGRect desiredDrawRect = CGRectMake(0, 0,
                                        MAX_EDGE_SIZE_LIMIT / 2,
                                        MAX_EDGE_SIZE_LIMIT);
    CGSize outputContainerSize = CGSizeZero;
    CGRect outputDrawRect = CGRectZero;
    [TBScreenCapture dimensionsForInputSize:inputSize
                              containerSize:&outputContainerSize
                                   drawRect:&outputDrawRect];
    XCTAssert(CGSizeEqualToSize(desiredContainer, outputContainerSize));
    XCTAssert(CGRectEqualToRect(desiredDrawRect, outputDrawRect));
}

@end
