Broadcast Extension sample app
===========================

** The sample app will only work with H264 video codec. Make sure that your API key is enabled for it.** Please contact
support if you want it to be enabled.

The Broadcast Extension app shows how to implement the iOS Broadcast Upload extension
using the OpenTok iOS SDK. 

Before running the app, set the OpenTok session ID and token in the `setupInfo` object
passed into the `broadcastStartedWithSetupInfo:` method (in SampleHandler.m).

This app will not work in Simulator. You need to use a real device.

The project includes three targets:

* Broadcast-Ext -- This is an actual application target and uses `RPSystemBroadcastPickerView`
to launch the iOS broadcast extension UI dialog with "OpenTok Live" as the only available extension.  

* OpenTok LiveSetupUI -- The UI part of the Broadcast extension. This will be only shown when you use
`RPBroadcastActivityViewController` and not the `RPSystemBroadcastPickerView`.

* OpenTok Live -- This target has the OpenTok functionality, which includes a custom video capturer (`SampleHandler`)
and a custom audio driver (`OTBroadcastExtAudioDevice`) for recording and playing audio. The `OTBroadcastExtHelper`
is a helper class to manage OpenTok objects. The video samples are scaled down using a `CILanczosScaleTransform` CIFilter
and using CVPixelBufferPool to manage memory efficiently. The resolution and frame rate should cap to 450x800 pixels
at 10fps for VP8 and at 1068x600 pixels at 15fps for H264, which effectively consumes less than 50MB memory.
The iOS system kills extensions if they use more than 50MB. So if the stream is not publishing, iOS may have 
killed the extension, and you might need to lower the resolution and frame rate (particulary on iPad devices).

For more information on the iOS Broadcast Upload Extension, see the Apple
[app extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/index.html)
and [ReplayKit](https://developer.apple.com/documentation/replaykit) documentation.
