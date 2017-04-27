Project 8: Audio Levels
==================================

This project shows how to use the OpenTok iOS SDK to develop audio-only calls
with  multiple subscribers and audio levels. By the end of a code review, you
should learn how to add audio only calls with the OpenTok iOS SDK.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

Application Notes
=================

* This sample shows an audio-only session with audio level meter for each
  subscriber as well as the publisher. The sample supports multiple audio-only
  subscribers.

* The app sets the `audioLevelDelegate` property of the OTPublisherKit
  instance (in the TBViewController.m). As a result, the
  `[OTPublisherKitDelegate publisher: audioLevelUpdated:]` message is sent
  periodically to report audio levels of the published stream. The level
  in the publisher's audio level meter is updated accordingly.

  Similarly, the app sets the `audioLevelDelegate` property of the
  OTSubscriberKit instance (in the TBVoiceViewCell.m file). As a result,
  the `[OTSubscriberKit subscriber audioLevelUpdated:]` is sent
  periodically to report audio levels of the subscribed stream. The level
  in the subscriber's audio level meter is updated accordingly.

* The sample includes mute and unmute buttons for the publisher and subscribers.
