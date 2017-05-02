Project 3: Custom Audio Drvier
================================

This project implements a controller nearly identical to the hello world sample.
The entry point of new content is during the controllers `viewDidLoad:`
callback, where we set up an audio device before initializing our first OpenTok
object. It is important to note that audio device setup *must* occur before any
instance of OTSession or OTPublisher is initialized:
```
_myAudioDevice = [[OTDefaultAudioDevice alloc] init];
[OTAudioDeviceManager setAudioDevice:_myAudioDevice];
```

`OTDefaultAudioDevice` is a copy of the default device driver used in 
the OpenTok iOS SDK. If no audio device is set prior to the first instantiation
of OTSession, the default driver will be used. A common reason for a developer
to look at this sample is to debug audio issues in their application. This is
also a good entry point for managing more complicated audio routing and
customization of handling audio events on the device during the lifecycle of
your app.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

Application Notes
-----------------

* `recording_cb` and `playout_cb` are the two main operator functions in the
  audio graph once initialization has occurred and the session is active.
  Setting breakpoints on these functions can be useful to verify that the audio
  graph is indeed running and producing/consuming audio.

* The callbacks `onRouteChangeEvent:` and `onInteruptionEvent:` are hooked into
  the system events and listen for important audio events that developers may
  wish to handle properly in different contexts of their app.
  
* There are known constraints to sample rates and formats inherited from both
  the WebRTC runtime and iOS. The rates chosen in the sample audio device are
  known working configurations, but not everything will work. The simulator
  needs to run at 44.1 kHz. Devices should stick between 8-32 kHz. This example
  sticks to using unsigned 16-bit integers as the sample format. Your mileage
  may vary with adjusting any of these.
