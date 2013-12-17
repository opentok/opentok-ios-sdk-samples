//
//  TBExampleVideoCapture+PhotoCapture.h
//  Live-Photo-Capture
//
//  Created by Charley Robinson on 12/16/13.
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "TBExampleVideoCapture.h"

@interface TBExamplePhotoVideoCapture : TBExampleVideoCapture

@property (readonly) BOOL isTakingPhoto;
- (void)takePhotoWithCompletionHandler:(void (^)(UIImage* photo))block;


@end
