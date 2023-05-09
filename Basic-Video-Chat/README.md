Basic Video Chat sample app
===========================

The Basic Video Chat app is a very simple application meant to get a new developer
started using the OpenTok iOS SDK. For a full description, see the [Basic tutorial at the
OpenTok developer center](https://tokbox.com/developer/tutorials/ios/basic-video-chat/).


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
To use CocoaPods to add the OpenTok library and its dependencies to your app
- In the Terminal, navigate to the root directory of your project and enter the following: `pod init`.
  This creates a Podfile at the root of your project directory.
- Open your Podfile and add the following line to specify the dependency: `pod 'OpenTok'`.
- Save changes to the Podfile.
- Finaly from Termianl run: `pod install`.
