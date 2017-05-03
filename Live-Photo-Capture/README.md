Project 5: Live Photo Capture
=============================

This project extends some of the material we presented in [Project 2][1], by 
demonstrating how a simple capture implementation can be extended to provide
interesting features. By the end of a code review of this project, you should
understand how to use the AVFoundation API to temporarily halt your video 
capture module, adjust capture settings to use photo-quality resolution,
capture a picture, then resume video capture.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

Configuration Notes
-------------------

Since we are importing a number of classes implemented in project 2, the
header search paths in the project build settings must be extended to look
in the project 2 directory. Additionally, we must recompile the
implementation files in order to continue using our TBExamplePublisher,
created in project 2. You will notice an extra group in this project's
navigator space with references to the files we need.

Application Notes
-----------------

*   The only new implementation in this project is the
    TBExamplePhotoVideoCapture class. By subclassing the video capture module
    implemented in project 2, we save some time setting up standard video 
    capture and focus only on manipulating AVFoundation to give us a picture
    in the middle of a (video) capture session.
    
*   In testing, we noticed that the image sensor takes a moment to adjust white
    balance and exposure after switching to the capture session preset for photo
    quality (see `pauseVideoCaptureForPhoto` in TBExamplePhotoVideoCapture).
    The example implementation stalls the photo capture with a busy loop, but 
    a more sophisticated approach might be considered to ensure the best 
    experience for the end user.
    
*   This implementation briefly pauses the video feed during image capture. Note
    that a prolonged delay to the video capture consumer might result in other
    subscribers timing out the stream. If you wait for too long to send 
    consecutive video frames, you might lose the publisher altogether! Consider
    sending a freeze frame or even a blank image buffer to the video capture 
    endpoint if you need to pause video for a long (>2 second) period.

*   An alternative approach to this problem might be to continuously pipe photo-
    quality video into the video capture consumer. This might not work on some
    devices, based on processing capability and the fidelity of the image 
    sensor. Feel free to experiment and let us know how it goes for you!

*   Note that this sample application is not supported in the XCode iOS
    Simulator because the custom video capturer needs to acquire video from an
    iOS device camera.

[1]: ../2.Custom-Video-Driver
