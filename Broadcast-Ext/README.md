Broadcast Extension sample app
===========================

The Broadcast Extension app shows how to implement the iOS Broadcast Upload Extension
using the OpenTok iOS SDK. The publisher's audio track is turned off by default. 
You can enable the audio track by setting the `audioTrack` parameter in the `doPublish` method
in OTBroadcastExtHelper.m. When you enable the publisher's audio track, be sure to turn on
the microphone in the Broadcast UI dialog box. Otherwise the publisher will fail because
it is not sending audio data.

Before running the App, You need to set the session ID and token in
the `- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo` method.

This app won't work in Simulator. You need to use a real device.

The project includes three targets:

* Broadcast-Ext -- This is an actual application target and uses `RPSystemBroadcastPickerView`
to launch the iOS broadcast extension UI dialog with "OpenTok Live" as the only available extension.  

• OpenTok LiveSetupUI -- The UI part of the Broadcast extension. This will be only shown when you use
`RPBroadcastActivityViewController` and not the `RPSystemBroadcastPickerView`.

* OpenTok Live -- This target has all OpenTok functionality, which includes a custom video capturer (`SampleHandler`)
and a custom audio driver (`OTBroadcastExtAudioDevice`) for recording and playing audio. The `OTBroadcastExtHelper`
is an helper class to manage OpenTok objects. The video samples are scaled down using CIFilter `CILanczosScaleTransform`
and using CVPixelBufferPool to manage memory efficiently. The resolution and frame rate should cap to 450x800 pixels
at 10fps for VP8 and at 1068x600 pixels at 15fps for H264, which effectively consumes less than 50MB memory.
The iOS system kills extensions if they use more than 50MB. So if the stream is not publishing it might be
iOS killed the extension already, and you might need to lower resolution and frame rate (particulary on iPad devices).

For more information on the iOS Broadcast Upload Extension, see the Apple
[app extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/index.html)
and [ReplayKit](https://developer.apple.com/documentation/replaykit) documentation.
