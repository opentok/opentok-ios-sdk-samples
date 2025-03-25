Enable Torch sample app
===========================

This application, built on top of Basic Video Chat, showcases how to set the preferred torch/flashlight mode for the camera. Note that this is a preference and may not take effect if the active camera does not support torch functionality (for example, the front camera typically does not support torch). The default value is false. Passing true or false indicates whether the publisher should enable or disable the camera's torch when available.

## Code sample - How to Enable Torch

  ```objc
  publisher.cameraTorch = YES;
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
