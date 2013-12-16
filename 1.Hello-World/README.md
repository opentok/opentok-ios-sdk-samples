Project 1: Hello World
======================

The Hello World app is a very simple application meant to get a new developer
started with using the OpenTok iOS SDK.

Application Notes
=================

1.  Follow the code from the UIViewController's viewDidLoad method all the way
    through the OpenTok callbacks to see how streams are created and handled in
    the OpenTok iOS SDK.
    
2.  By default, all delegate methods from classes in the OpenTok iOS SDK are 
    invoked on the main queue. This means that we can directly modify the view
    hierarchy from inside the callback, without any asynchronous callouts.


Configuration Notes
===================

1.  In the Project Navigator in XCode, notice the additional system frameworks
    needed for this project. If a framework is missing, you will see linker 
    errors while attempting to build the SDK. Frameworks can be added in the
    "Link binary with libraries" phase, in the "Build Phases" tab of the
    application target. For example, removing OpenTok.framework from the linker 
    phase results with the following error when we attempt to build the
    application:
    ```
Undefined symbols for architecture armv7:
  "_OBJC_CLASS_$_OTSubscriber", referenced from:
      objc-class-ref in ViewController.o
  "_OBJC_CLASS_$_OTPublisher", referenced from:
      objc-class-ref in ViewController.o
  "_OBJC_CLASS_$_OTSession", referenced from:
      objc-class-ref in ViewController.o
    ```
    
2.  The OTPublisher and OTSubscriber classes use a [third party library]
    (https://github.com/SVGKit/SVGKit) to draw icons to a UI control bar. This
    library uses Objective-C categories, so we must add the `-ObjC` flag to our
    "Other Linker Flags" build setting for this application, in order to use
    those classes without any problems. Skipping this flag will result in 
    runtime errors that look like this:
    ```
2013-12-16 13:18:59.494 Hello-World[3227:60b] +[NSCharacterSet SVGWhitespaceCharacterSet]: unrecognized selector sent to class 0x3a2b5da0
2013-12-16 13:18:59.496 Hello-World[3227:60b] *** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '+[NSCharacterSet SVGWhitespaceCharacterSet]: unrecognized selector sent to class 0x3a2b5da0'
```

3.  OpenTok uses GNU's libstdc++, which differs from the default C++ standard
    library for new projects in XCode (LLVM's libc++). You'll notice that
    `libstdc++.6.0.9.dylib` is in the binary linker phase, rather than the more-
    forgiving symlink `libstdc++.dylib`. In our tests, the symlinks did not work
    as the direct reference to the dylib, so long as the application deployment
    target is 7.0. Using an earlier deployment target might work for you, if the
    direct library reference is not suitable for your application.
    
4.  The OpenTok library is currently compiling for only the armv7 architecture.
    Remove the other architectures from your build settings. This does not
    affect the availability to any iOS devices, however you will not be able to
    run your application on Simulator.

