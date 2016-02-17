Project 9: Play a Ringtone
==========================

This project extends on the work done in Project 7 (External Audio Device) by
extending the sample audio driver with an AVAudioPlayer controller, which will
play a short ringtone while waiting for the subscriber to connect to the client
device.

The main controller is mostly the same as the previous, with an immediate call
to set the audio device driver. In this sample, we add an additional call to our
new audio device driver to begin playing back an audio file that will act as 
a ringtone:

```
    NSString* path = [[NSBundle mainBundle] pathForResource:@"bananaphone"
                                                     ofType:@"mp3"];
    NSURL* url = [NSURL URLWithString:path];
    [_myAudioDevice playRingtoneFromURL:url];
```

Additionally, once the device has connected to a subscriber stream, a call is
issued to stop playback of the ringtone:

```
- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    
    // Stop ringtone from playing, as the subscriber will connect shortly
    [_myAudioDevice stopRingtone];
    ...

```

Application Notes
-----------------

* There is no timeout or repeat for the audio player. Once the asset is played
  to completion, all calls from OTAudioBus will be passed to the audio driver, 
  and playback/capture will proceed as normal.
