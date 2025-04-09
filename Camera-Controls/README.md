Camera Controls sample app
===========================

This application, built on top of Basic Video Chat, showcases how to set the preferred torch/flashlight mode and zoom factor for the camera. 
Note that this is a preference and may not take effect if the active camera does not support the functionality (for example, the front camera typically does not support torch). 

The default value for torch is false. Passing true or false indicates whether the publisher should enable 
or disable the camera's torch when available.

The zoom factor values range from 0.5 to the maximum zoom factor. Values between 0.5 and 1.0 will represent 
ultra-wide-angle (zoom out) and values between 1.0 and the maximum zoom factor will represent 
zooming in. The actual zoom factor applied will be automatically clamped to the range supported by the active 
camera's configuration, meaning if the camera does not support ultra-wide-angle, zoom factors set below 1.0 
will not take effect and no zoom will be applied. For values over the maximum zoom factor supported by the 
camera, the zoom factor will be set with the max value. The value of 1.0 represents no zoom (the default view).

## Code sample - How to Enable Torch

  ```objc
  publisher.cameraTorch = YES;
  setCameraZoomFactor = 5.0;
  ```

Adding the OpenTok library
==========================
In this example the OpenTok iOS SDK was not included as a dependency,
you can do it through Swift Package Manager or Cocoapods.


Swift Package Manager
---------------------
To add a package dependency to your Xcode project, you should select 
*File* > *Swift Packages* > *Add Package Dependency* and enter the repository URL:
`https://github.com/opentok/vonage-client-sdk-video.git`.


Cocoapods
---------
To use CocoaPods to add the OpenTok library and its dependencies into this sample app
simply open Terminal, navigate to the root directory of the project and run: `pod install`.
