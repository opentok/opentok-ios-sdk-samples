Broadcast Extension sample app
===========================

The Broadcast Extension app shows how to implement the iOS Broadcast Upload Extension
using the OpenTok iOS SDK. The publisher's audio track is turned off by default. 
You can enable the audio track by setting the `audioTrack` parameter in the "doPublish" method in OTBroadcastExtHelper.m.
When you enable the publisher's audio track, be sure to turn on the microphone in
Broadcast UI dialog box. Otherwise the publisher will fail because it is not sending audio data. Before running the App, You need to set the 
session id and token in method `- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo`.

This app won't work in Simulator. You need to use a real device.

For more information on the iOS Broadcast Upload Extension, see the Apple [app extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/index.html) and [ReplayKit](https://developer.apple.com/documentation/replaykit) documentation.
