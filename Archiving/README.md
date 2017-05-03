Learning OpenTok iOS Sample App
===============================

This sample app shows how to accomplish basic tasks using the OpenTok iOS SDK.
It connects the user with another client so that they can share an OpenTok audio-video
chat session. Additionally, the app uses the OpenTok iOS SDK to implement the following:

* Controls for muting the audio of each participant
* A control for switching the camera used (between the front and back)
* Text chat for the participants
* The ability to record the chat session, stop the recording, and view the recording
* A simple custom audio driver for audio input and output
* A custom video renderer
* A simple custom video capturer
* A custom video capturer that uses the device camera
* Publishing a screen-sharing stream

The code for this sample is found the following git branches:

* *basics.step-1* -- This branch shows you how to set up your project to use the OpenTok iOS SDK.

* *basics.step-4* -- This branch shows you how to connect to the OpenTok session.

* *basics.step-5* -- This branch shows you how publish a stream to the OpenTok session.

* *basics.step-6* -- This branch shows you how to subscribe to a stream on the OpenTok session.

* *basics.step-7* -- This branch shows you how to add user interface controls to mute the
publisher and subscriber audio and to swap the camera used by the publisher.

* *archiving* -- This branch shows you how to record the session.

* *signaling* -- This branch shows you how to implement text chat using the OpenTok
signaling API.

* *audio-driver* -- This branch shows you how to implement a custom audio driver.

* *video-renderer-basic* -- This branch shows the basics of implementing a custom video renderer
for an OpenTok publisher.

* *video-capturer-basic* -- This branch shows the basics of implementing a custom video capturer
for an OpenTok publisher.

* *video-capturer-camera* - This branch shows you how to use a custom video capturer using
the device camera as the video source.

* *screen-sharing* - This branch shows you how to use the device's screen (instead of a
camera) as the video source for a published stream.

You will also need to clone the learning-opentok-php repo and run its code on a
PHP-enabled web server. See the basics.step-2 section for more information.

## basics.step-1: Starting Point

The step-0 branch includes a basic Xcode project.  Before you can test the application,
you need to make some settings in Xcode and set up a web service to handle some
OpenTok-related API calls.

1. Download the [OpenTok iOS SDK] [1].

2. Locate the LearningOpenTok.xcodeproj file and open it in Xcode.

3. Include the OpenTok.framework in the list of frameworks used by the app.
From the OpenTok iOS SDK, you can drag the OpenTok.framework file into the list of
frameworks in the Xcode project explorer for the app.

4. Copy the SampleConfig.h file to a Config.h file.

Copy the contents of the SampleConfig.h file to the clipboard. Then select
File > New > File (Command-N). In the dialog that is displayed, select
Header File, click Next, and save the file as Config.h.

We will set values for the constants defined in this file in a later step.

## basics.step-2 (server-side): Creating a session and defining archive REST API calls

Before you can test the application, you need to set up a web service to handle some
OpenTok-related API calls. The web service securely creates an OpenTok session.

The [Learning OpenTok PHP](https://github.com/opentok/learning-opentok-php) repo includes code
for setting up a web service that handles the following API calls:

* "/service" -- The iOS client calls this endpoint to get an OpenTok session ID, token,
and API key.

* "/start" -- The iOS client calls this endpoint to start recording the OpenTok session to
an archive.

* "/stop" -- The iOS client calls this endpoint to stop recording the archive.

* "/view" -- The iOS client load this endpoint in a web browser to display the archive
recording.

The HTTP POST request to the /session endpoint returns a response that includes the OpenTok
session ID and token.

Download the repo and run its code on a PHP-enabled web server. You can also deploy and
run the code on Heroku (so you don't have to set up your own PHP server). See the readme
file in the learning-opentok-php repo for instructions.


## basics.step-3 (server-side): Generating a token (server side)

The web service also creates a token that the client uses to connect to the OpenTok session.
The HTTP GET request to the /service endpoint returns a response that includes the OpenTok
session ID and token.

You will want to authenticate each user (using your own server-side authentication techniques)
before sending an OpenTok token. Otherwise, malicious users could call your web service and
use tokens, causing streaming minutes to be charged to your OpenTok developer account. Also,
it is a best practice to use an HTTPS URL for the web service that returns an OpenTok token,
so that it cannot be intercepted and misused.


## basics.step-4: Connecting to the session

The code for this section is added in the basics.step-4 branch of the repo.

First, set the app to use the web service described in the previous two sections:

* In Xcode, open the Config.h file (see basics.step-1). Add the base URL,
(such as `@"http://example.com"`) in this line:

define SAMPLE_SERVER_BASE_URL @"https://YOUR-SERVER-URL"

In a production application, you will always want to use a web service to obtain a unique token
each time a user connects to an OpenTok session.

You will want to authenticate each user (using your own server-side authentication techniques)
before sending an OpenTok token. Otherwise, malicious users could call your web service and
use tokens, causing streaming minutes to be charged to your OpenTok developer account. Also,
it is a best practice to use an HTTPS URL for the web service that returns an OpenTok token,
so that it cannot be intercepted and misused.

You can now test the app in the debugger. On successfully connecting to the session, the
app logs "Session Connected" to the debug console.

An OpenTok session connects different clients letting them share audio-video streams and
send messages. Clients in the same session can include iOS, Android, and web browsers.

**Session ID** -- Each client that connects to the session needs the session ID, which identifies
the session. Think of a session as a room, in which clients meet. Depending on the requirements of your application, you will either reuse the same session (and session ID) repeatedly or generate
new session IDs for new groups of clients.

*Important:* This demo application assumes that only two clients -- the local iOS client and another
client -- will connect in the same OpenTok session. For test purposes, you can reuse the same
session ID each time two clients connect. However, in a production application, your server-side
code must create a unique session ID for each pair of clients. In other applications, you may want
to connect many clients in one OpenTok session (for instance, a meeting room) and connect others
in another session (another meeting room). For examples of apps that connect users in different
ways, see the OpenTok ScheduleKit, Presence Kit, and Link Kit [Starter Kit apps] [3].

Since this app uses the OpenTok archiving feature to record the session, the session must be set
to use the `routed` media mode, indicating that it will use the OpenTok Media Router. The OpenTok
Media Router provides other advanced features (see [The OpenTok Media Router and media modes] [4]).
If your application does not require the features provided by the OpenTok Media Router, you can set
the media mode to `relayed`.

**Token** -- The client also needs a token, which grants them access to the session. Each client is
issued a unique token when they connect to the session. Since the user publishes an audio-video stream to the session, the token generated must include the publish role (the default). For more
information about tokens, see the OpenTok [Token creation overview] [5].

**API key** -- The API key identifies your OpenTok developer account.

Upon starting up, the application calls the `[self getSessionCredentials:]` method (defined in the
ViewController.m file). This method calls a web service that provides an OpenTok session ID, API key, and token to be used by the client. In the Config.h file (see the previous section), set the
`SAMPLE_SERVER_BASE_URL` constant to the base URL of the web service that handles OpenTok-related
API calls:

define SAMPLE_SERVER_BASE_URL @"http://YOUR-SERVER-URL/"

The "/session" endpoint of the web service returns an HTTP response that includes the session ID,
the token, and API key formatted as JSON data:

{
"sessionId": "2_MX40NDQ0MzEyMn5-fn4",
"apiKey": "12345",
"token": "T1==cGFydG5lcl9pZD00jg="
}

Upon obtaining the session ID, token, and API, the app calls the `[self doConnect]` method to
initialize an OTSession object and connect to the OpenTok session:

- (void)doConnect
{
// Initialize a new instance of OTSession and begin the connection process.
_session = [[OTSession alloc] initWithApiKey:_apiKey
sessionId:_sessionId
delegate:self];
OTError *error = nil;
[_session connectWithToken:_token error:&error];
if (error)
{
NSLog(@"Unable to connect to session (%@)",
error.localizedDescription);
}
}

The OTSession object (`_session`), defined by the OpenTok iOS SDK, represents the OpenTok session
(which connects users).

The `[OTSession connectWithToken:error]` method connects the iOS app to the OpenTok session.
You must connect before sending or receiving audio-video streams in the session (or before
interacting with the session in any way).

This app sets `self` to implement the `[OTSessionDelegate]` interface to receive session-related
messages. These messages are sent when other clients connect to the session, when they send
audio-video streams to the session, and upon other session-related events, which we will look
at in the following sections.

## basics.step-5: Publishing an audio video stream to the session

1. In Xcode, launch the app in a connected iOS device or in the iOS simulator.

2. On first run, the app asks you for access to the camera:

LearningOpenTok would like to Access the Camera: Don't Allow / OK

iOS OS requires apps to automatically ask the user to grant camera permission to an app.

The published stream appears in the lower-lefthand corner of the video view. (The main storyboard
of the app defines many of the views and UI controls used by the app.)

3. Now close the app and find the test.html file in the root of the project. You will use the
test.html file (in located in the root directory of this project), to connect to the OpenTok
session and publish an audio-video stream from a web browser:

* Edit the test.html file and set the `sessionCredentialsUrl` variable to match the
`ksessionCredentialsUrl` property used in the iOS app. Or -- if you are using hard-coded
session ID, token, and API key settings -- set the `apiKey`,`sessionId`, and `token` variables.

* Add the test.html file to a web server. (You cannot run WebRTC videos in web pages loaded
from the desktop.)

* In a browser, load the test.html file from the web server.

4. Run the iOS app again. The app will send an audio-video stream to the web client and receive
the web client's stream.

5. Click the mute mic button (below the video views).

This mutes the microphone and prevents audio from being published. Click the button again to
resume publishing audio.

6. Click the mute mic button in the subscribed stream view.

This mutes the local playback of the subscribed stream.

7. Click the swap camera button (below the video views).

This toggles the camera used (between front and back) for the published stream.

Upon successfully connecting to the OpenTok session (see the previous section), the
`[OTSessionDelegate session:didConnect:]` message is sent. The ViewController.m code implements
this delegate method:

- (void)sessionDidConnect:(OTSession*)session
{
// We have successfully connected, now start pushing an audio-video stream
// to the OpenTok session.
[self doPublish];
}

The method calls the `[self doPublish]` method, which first initializes an OTPublisher object,
defined by the OpenTok iSO SDK:

_publisher = [[OTPublisher alloc]
initWithDelegate:self];

The code calls the `[OTSession publish:error:]` method to publish an audio-video stream
to the session:

OTError *error = nil;
[_session publish:_publisher error:&error];
if (error)
{
NSLog(@"Unable to publish (%@)",
error.localizedDescription);
}

It then adds the publisher's view, which contains its video, as a subview of the
`_publisherView` UIView element, defined in the main storyboard.

[_publisher.view setFrame:CGRectMake(0, 0, _publisherView.bounds.size.width,
_publisherView.bounds.size.height)];
[_publisherView addSubview:_publisher.view];

This app sets `self` to implement the OTPublisherDelegate interface and receive publisher-related
events.

Upon successfully publishing the stream, the implementation of the
`[OTPublisherDelegate publisher:streamCreated]`  method is called:

- (void)publisher:(OTPublisherKit *)publisher
streamCreated:(OTStream *)stream
{
NSLog(@"Now publishing.");
}

If the publisher stops sending its stream to the session, the implementation of the
`[OTPublisherDelegate publisher:streamDestroyed]` method is called:

- (void)publisher:(OTPublisherKit*)publisher
streamDestroyed:(OTStream *)stream
{
[self cleanupPublisher];
}

The `[self cleanupPublisher:]` method removes the publisher's view (its video) from its
superview:

- (void)cleanupPublisher {
[_publisher.view removeFromSuperview];
_publisher = nil;
}

## basics.step-6: Subscribing to another client's audio-video stream

The [OTSessionDelegate session:streamCreated:] message is sent when a new stream is created in
the session. The app implements this delegate method with the following:

- (void)session:(OTSession*)session
streamCreated:(OTStream *)stream
{
NSLog(@"session streamCreated (%@)", stream.streamId);

if (nil == _subscriber)
{
[self doSubscribe:stream];
}
}

The method is passed an OTStream object (defined by the OpenTok iOS SDK), representing the stream
that another client is publishing. Although this app assumes that only one other client is
connecting to the session and publishing, the method checks to see if the app is already
subscribing to a stream (if the `_subscriber` property is set). If not, the session calls `[self doSubscribe:stream]`, passing in the OTStream object (for the new stream):

- (void)doSubscribe:(OTStream*)stream
{
_subscriber = [[OTSubscriber alloc] initWithStream:stream
delegate:self];
OTError *error = nil;
[_session subscribe:_subscriber error:&error];
if (error)
{
NSLog(@"Unable to publish (%@)",
error.localizedDescription);
}
}

The method initializes an OTSubscriber object (`_subscriber`), used to subscribe to the stream,
passing in the OTStream object to the initialization method. It also sets `self` to implement the
OTSubscriberDelegate interface, which is sent messages related to the subscriber.

It then calls `[OTSession subscribe:error:]` to have the app to subscribe to the stream.

When the app starts receiving the subscribed stream, the
`[OTDSubscriberDelegate subscriberDidConnectToStream:]` message is sent. The implementation of the
delegate method adds view of the subscriber stream (defined by the `view` property of the OTSubscriber object) as a subview of the `_subscriberView` UIView object, defined in the main
storyboard:

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
NSLog(@"subscriberDidConnectToStream (%@)",
subscriber.stream.connection.connectionId);
[_subscriber.view setFrame:CGRectMake(0, 0, _subscriberView.bounds.size.width,
_subscriberView.bounds.size.height)];
[_subscriberView addSubview:_subscriber.view];
_subscriberAudioBtn.hidden = NO;

_chatTextInputView.hidden = NO;
}

It also displays the input text field for the text chat. The app hides this field until
you start viewing the other client's audio-video stream.

If the subscriber's stream is dropped from the session (perhaps the client chose to stop publishing
or to the implementation of the `[OTSession session:streamDestroyed]` method is called:

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
NSLog(@"session streamDestroyed (%@)", stream.streamId);
if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
{
[self cleanupSubscriber];
}
}

The `[self cleanupSubscriber:]` method removes the publisher's view (its video) from its
superview:

- (void)cleanupPublisher {
[_subscriber.view removeFromSuperview];
_subscriber = nil;
}

## basics.step-7: Adding user interface controls

The code for this section is in the basics.step-7 branch.

This code adds buttons to mute the publisher and subscriber audio and to toggle the
publisher camera.

### Muting the publisher and subscriber

When the user clicks the toggle publisher audio button, the `[self togglePublisherMic]`
method is called:

-(void)togglePublisherMic
{
_publisher.publishAudio = !_publisher.publishAudio;
UIImage *buttonImage;
if (_publisher.publishAudio) {
buttonImage = [UIImage imageNamed: @"mic-24.png"];
} else {
buttonImage = [UIImage imageNamed: @"mic_muted-24.png"];
}
[_publisherAudioBtn setImage:buttonImage forState:UIControlStateNormal];
}

The `publishAudio` property of the OTPublisher object is set to a Boolean value indicating whether
the publisher is publishing audio or not. The method toggles the setting when the user clicks the
button.

Similarly, the `subscribeToAudio` property of the OTSubscriber object is a Boolean value indicating
whether the local iOS device is playing back the subscribed stream's audio or not. When the user
clicks the toggle audio button for the Subscriber, the following method is called:

-(void)toggleSubscriberAudio
{
_subscriber.subscribeToAudio = !_subscriber.subscribeToAudio;
UIImage *buttonImage;
if (_subscriber.subscribeToAudio) {
buttonImage = [UIImage imageNamed: @"Subscriber-Speaker-35.png"];
} else {
buttonImage = [UIImage imageNamed: @"Subscriber-Speaker-Mute-35.png"];
}
[_subscriberAudioBtn setImage:buttonImage forState:UIControlStateNormal];
}

### Changing the camera used by the publisher

When the user clicks the toggle camera button, the `[self swapCamra]` method is called:

-(void)swapCamera
{
if (_publisher.cameraPosition == AVCaptureDevicePositionFront) {
_publisher.cameraPosition = AVCaptureDevicePositionBack;
} else {
_publisher.cameraPosition = AVCaptureDevicePositionFront;
}
}

Setting the `cameraPosition` property of the OTPublisher object sets the camera used by
the publisher. The `AVCaptureDevicePositionFront` and `AVCaptureDevicePositionBack`
constants are defined in the [AVCaptureDevice] [6] class.

## archiving.step-1: Recording the session to an archive

*Important* -- To view the code for this functionality, switch to the *archiving* branch
of this git repository.

In the archiving branch of this git repository, the following functionality is enabled:

1. Tap the *Start recording* button.

This starts recording the audio video streams on the OpenTok Media Server.

2. Click the *Stop recording* button to stop the recording.

3. Click the *View recording* button to view the recording in the web browser.

The OpenTok archiving API lets you record audio-video streams in a session to MP4 files. You use
server-side code to start and stop archive recordings. In the Config.h file, you set the following
constant to the base URL of the web service the app calls to start archive recording, stop
recording, and play back the recorded video:

#define SAMPLE_SERVER_BASE_URL

If you do not set this string, the Start Recording, Stop Recording, and View Archive
buttons will not be available in the app.

When the user clicks the Start Recording and Stop Recording buttons, the app calls the
`[self startArchive:]` and `[self startArchive:]` methods. These call web services that call
server-side code start and stop archive recordings.
(See [Setting up the test web service](#setting-up-the-test-web-service).)

When archive recording starts, the implementation of the
`[OTSessionDelegate session:archiveStartedWithId:name:]` method is called:

- (void)     session:(OTSession*)session
archiveStartedWithId:(NSString *)archiveId
name:(NSString *)name
{
NSLog(@"session archiving started with id:%@ name:%@", archiveId, name);
_archiveId = archiveId;
_archivingIndicatorImg.hidden = NO;
[_archiveControlBtn setTitle: @"Stop recording" forState:UIControlStateNormal];
_archiveControlBtn.hidden = NO;
[_archiveControlBtn addTarget:self
action:@selector(stopArchive)
forControlEvents:UIControlEventTouchUpInside];
}

This causes the `_archivingIndicatorImg` image (defined in the main storyboard) to be displayed.
The method stores the archive ID (identifying the archive) to an `archiveId` property.
The method also changes the archiving control button text to change to "Stop recording".

When the user clicks the Stop Recording button, the app passes the archive ID along to the
web service that stops the archive recording.

When archive recording stops, the implementation of the
`[OTSessionDelegate session:archiveStartedWithId:name:]` method is called:

- (void)     session:(OTSession*)session
archiveStoppedWithId:(NSString *)archiveId
{
NSLog(@"session archiving stopped with id:%@", archiveId);
_archivingIndicatorImg.hidden = YES;
[_archiveControlBtn setTitle: @"View archive" forState:UIControlStateNormal];
_archiveControlBtn.hidden = NO;
[_archiveControlBtn addTarget:self
action:@selector(loadArchivePlaybackInBrowser)
forControlEvents:UIControlEventTouchUpInside];
}

This causes the `_archivingIndicatorImg` image (defined in the main storyboard) to be
displayed. It also changes the archiving control button text to change to "View archive".
When the user clicks this button, the `[self loadArchivePlaybackInBrowser:]` method
opens a web page (in Safari) that displays the archive recording.

## signaling.step-1: Using the signaling API to implement text chat

*Important* -- To view the code for this functionality, switch to the *signaling* branch
of this git repository.

In the signaling branch of this git repository, the following functionality is enabled:

* Click in the text chat input field (labeled "Enter text chat message here"), enter a text
chat message and tap the Return button.

The text chat message is sent to the web client. You can also send a chat message from the web
client to the iOS client.

When the user enters text in the text chat input text field, the '[self sendChatMessage:]``
method is called:

- (void) sendChatMessage
{
OTError* error = nil;
[_session signalWithType:@"chat"
string:_chatInputTextField.text
connection:nil error:&error];
if (error) {
NSLog(@"Signal error: %@", error);
} else {
NSLog(@"Signal sent: %@", _chatInputTextField.text);
}
_chatTextInputView.text = @"";
}

This method calls the `[OTSession signalWithType:string:connection:]` method. This
method sends a message to clients connected to the OpenTok session. Each signal is
defined by a `type` string identifying the type of message (in this case "chat")
and a string containing the message.

When another client connected to the session (in this app, there is only one) sends
a message, the implementation of the `[OTSessionDelegate session:receivedSignalType:string:]`
method is called:

- (void)session:(OTSession*)session receivedSignalType:(NSString*)type fromConnection:(OTConnection*)connection withString:(NSString*)string {
NSLog(@"Received signal %@", string);
Boolean fromSelf = NO;
if ([connection.connectionId isEqualToString:session.connection.connectionId]) {
fromSelf = YES;
}
[self logSignalString:string fromSelf:fromSelf];
}

This method checks to see if the signal was sent by the local iOS client or by the other
client connected to the session:

Boolean fromSelf = NO;
if ([connection.connectionId isEqualToString:session.connection.connectionId]) {
fromSelf = YES;
}

The `session` argument represents your clients OTSession object. The OTSession object has
a `connection` property with a `connectionId` property. The `connection` argument represents
the connection of client sending the message. If these match, the signal was sent by the
local iOS app.

The method calls the `[self logSignalString:]` method which displays the message string in
the text view for chat messages received.

This app uses the OpenTok signaling API to implement text chat. However, you can use the
signaling API to send messages to other clients (individually or collectively) connected to
the session.

# Basic Audio Driver (audio-driver branch)

To see the code for this sample, switch to the audio-driver branch. This branch shows you
how to implement a custom audio driver.

The OpenTok iOS SDK lets you set up a custom audio driver for publishers and subscribers. You can
use a custom audio driver to customize the audio sent to a publisher's stream. You can also
customize the playback of a subscribed streams' audio.

This sample application uses the custom audio driver to publish white noise (a random audio signal)
to its audio stream. It also uses the custom audio driver to capture the audio from subscribed
streams and save it to a file.

## Setting up the audio device and the audio bus

In using a custom audio driver, you define a custom audio driver and an audio bus to be
used by the app.

The OTKBasicAudioDevice class defines a basic audio device interface to be used by the app.
It implements the OTAudioDevice protocol, defined by the OpenTok iOS SDK. To use a custom
audio driver, call the `[OTAudioDeviceManager setAudioDevice:]` method. This sample sets
the audio device to an instance of the OTKBasicAudioDevice class:

[OTAudioDeviceManager setAudioDevice:[[OTKBasicAudioDevice alloc] init]];

Use the OTAudioFormat class, defined in the OpenTok iOS SDK, to define the audio format used
by the custom audio driver. The `[OTKBasicAudioDevice init]` method creates an instance
of the OTAudioFormat class, and sets the sample rate and number of channels for the audio format:

- (id)init
{
self = [super init];
if (self) {
self = [super init];
if (self) {
_otAudioFormat = [[OTAudioFormat alloc] init];
_otAudioFormat.sampleRate = kSampleRate;
_otAudioFormat.numChannels = 1;
}

// ...
}
return self;
}

The `init` method also sets up some local properties that report whether the device is capturing,
whether capturing has been initialized, whether it is rendering and whether rendering has been
initialized:

_isDeviceCapturing = NO;
_isCaptureInitialized = NO;
_isDeviceRendering = NO;
_isRenderingInitialized = NO;

The `init` method also sets up a file to save the incoming audio to a file. This is done simply
to illustrate a use of the custom audio driver's audio renderer:

NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
NSUserDomainMask,
YES);
NSString *path = [paths[0] stringByAppendingPathComponent:kOutputFileSampleName];

[[NSFileManager defaultManager] createFileAtPath:path
contents:nil
attributes:nil];
_outFile = [NSFileHandle fileHandleForReadingAtPath:path];

The `[OTKBasicAudioDevice setAudioBus:]` method (defined by the OTAudioDevice protocol) sets
the audio bus to be used by the audio device (defined by the OTAudioBus protocol). The audio
device uses this object to send and receive audio samples to and from a session. This instance of
the object is retained for the lifetime of the implementing object. The publisher will access the
OTAudioBus object to obtain the audio samples. And subscribers will send audio samples (from
subscribed streams) to the OTAudioBus object. Here is the OTKBasicAudioDevice implementation of the
`[OTAudioDevice setAudioBus:]` method:

- (BOOL)setAudioBus:(id<OTAudioBus>)audioBus
{
self.otAudioBus = audioBus;
return YES;
}

The `[OTKBasicAudioDevice setAudioBus:]` method (defined by the OTAudioDevice protocol) method
sets the audio rendering format, the OTAudioFormat instance that was created in the the `init`
method:

- (OTAudioFormat*)renderFormat
{
return self.otAudioFormat;
}

## Rendering audio from subscribed streams

The `[OTAudioDevice startRendering:]` method is called when the audio device should start rendering
(playing back) audio from subscribed streams. The OTKBasicAudioDevice implementation of this method calls the `[self consumeSampleCapture]` method after 0.1 seconds:

- (BOOL)startRendering
{
self.isDeviceRendering = YES;
dispatch_after(
dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
dispatch_get_main_queue(),
^{
[self consumeSampleCapture];
});
return YES;
}

The `[OTKBasicAudioDevice consumeSampleCapture]` method gets 1000 samples from the audio
bus by calling the `[OTAudioBus readRenderData:buffer numberOfSamples:]` method (defined by the OpenTok iOS SDK). It then writes the audio data to the file (for sample purposes). And, if the
audio device is still being used to render audio samples, it sets a timer to call `consumeSampleCapture` method again after 0.1 seconds:

- (void)consumeSampleCapture
{
static int num_samples = 1000;
int16_t *buffer = malloc(sizeof(int16_t) * num_samples);

uint32_t samples_get = [self.otAudioBus readRenderData:buffer numberOfSamples:num_samples];

NSData *data = [NSData dataWithBytes:buffer
length:(sizeof(int16_t) * samples_get)];
[self.outFile seekToEndOfFile];
[self.outFile writeData:data];

free(buffer);

if (self.isDeviceRendering) {
dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
(int64_t)(0.1 * NSEC_PER_SEC)),
dispatch_get_main_queue(),
^{
[self consumeSampleCapture];
});
}
}

This example is intentionally simple for instructional purposes -- it simply writes the audio data
to a file. In a more practical use of a custom audio driver, you could use the custom audio driver
to play back audio to a Bluetooth device or to process audio before playing it back.

## Capturing audio to be used by a publisher

The `[OTAudioDevice startCapture:]` method is called when the audio device should start capturing
audio to be published. The OTKBasicAudioDevice implementation of this method calls the `[self produceSampleCapture]` method after 0.1 seconds:

- (BOOL)startCapture
{
self.isDeviceCapturing = YES;
dispatch_after(
dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
dispatch_get_main_queue(),
^{
[self produceSampleCapture];
});

return YES;
}

The `[OTKBasicAudioDevice produceSampleCapture]` method produces a buffer containing samples of random data (white noise). It then calls the `[OTAudioBus writeCaptureData: numberOfSamples:]` method of the OTAudioBus object, which sends the samples to the audio bus. The publisher in the
application uses the samples sent to the audio bus to transmit as audio in the published stream.
Then if a capture is still in progress (if the app is publishing), the method calls itself again after 0.1 seconds.

- (void)produceSampleCapture
{
static int num_frames = 1000;
int16_t *buffer = malloc(sizeof(int16_t) * num_frames);

for (int frame = 0; frame < num_frames; ++frame) {
Float32 sample = ((double)arc4random() / 0x100000000);
buffer[frame] = (sample * 32767.0f);
}

[self.otAudioBus writeCaptureData:buffer numberOfSamples:num_frames];

free(buffer);

if (self.isDeviceCapturing) {
dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
(int64_t)(0.1 * NSEC_PER_SEC)),
dispatch_get_main_queue(),
^{
[self produceSampleCapture];
});
}
}

## Other notes on the app

The OTAudioDevice protocol includes other required methods, which are implemented by
the OTKBasicAudioDevice class. However, this sample does not do anything interesting in
these methods, so they are not included in this discussion.


# Basic Video Renderer (video-renderer-basic branch)

To see the code for this sample, switch to the video-renderer-basic branch. This branch shows you
how to make minor modifications to the video renderer used by an OTPublisher object. You can also
use the same techniques to modify the video renderer used by an OTSubscriber object (though this
example only illustrates a custom renderer for a publisher).

In this example, the app uses a custom video renderer to display a black-and-white version of the
OTPublisher object's video.

In the main ViewController, after initializing the OTPublisher object, the `videoRender` property
of the OTPublisher object is set to an instance of OTKBasicVideoRender:

_publisher = [[OTPublisher alloc]
initWithDelegate:self];
_renderer = [[OTKBasicVideoRender alloc] init];

_publisher.videoRender = _renderer;

OTKBasicVideoRender is a custom class that implements the OTVideoRender protocol (defined
in the OpenTok iOS SDK). This protocol lets you define a custom video renderer to be used
by an OpenTok publisher or subscriber.

The `[OTKBasicVideoRender init:]` method sets a `_renderView` property to a UIView object. This is
the UIView object that will contain the view to be rendered (by the publisher or subscriber).
In this sample, the UIView object is defined by the custom OTKCustomRenderView class, which
extends UIView:

- (id)init
{
self = [super init];
if (self) {
_renderView = [[OTKCustomRenderView alloc] initWithFrame:CGRectZero];
}
return self;
}

The OTKCustomRenderView class includes methods (discussed later) that convert a video frame to
a black-and-white representation.

The [OTVideoRender renderVideoFrame:] method is called when the publisher (or subscriber) renders
a video frame to the video renderer. The frame an OTVideoFrame object (defined by the OpenTok iOS
SDK).  In the OTKCustomRenderView implementation of this method, it simply takes the frame and
passes it along to the `[renderVideoFrame]` method of the OTKCustomRenderView object:

- (void)renderVideoFrame:(OTVideoFrame*) frame
{
[(OTKCustomRenderView*)self.renderView renderVideoFrame:frame];
}

The `[OTKCustomRenderView renderVideoFrame]` method iterates through the pixels in the plane,
adjusts each pixel to a black-and-white value,  adds the value to a buffer. I then writes
the buffer to a CGImageRef representing the view's image, and calls `[self setNeedsDisplay]` to
render the image view:

- (void)renderVideoFrame:(OTVideoFrame *)frame
{
__block OTVideoFrame *frameToRender = frame;
dispatch_sync(self.renderQueue, ^{
if (_img != NULL) {
CGImageRelease(_img);
_img = NULL;
}

size_t bufferSize = frameToRender.format.imageHeight
* frameToRender.format.imageWidth * 3;
uint8_t *buffer = malloc(bufferSize);

uint8_t *yplane = [frameToRender.planes pointerAtIndex:0];

for (int i = 0; i < frameToRender.format.imageHeight; i++) {
for (int j = 0; j < frameToRender.format.imageWidth; j++) {
int starting = (i * frameToRender.format.imageWidth * 3) + (j * 3);
uint8_t yvalue = yplane[(i * frameToRender.format.imageWidth) + j];
// If in a RGB image we copy the same Y value for R, G and B
// we will obtain a Black & White image
buffer[starting] = yvalue;
buffer[starting+1] = yvalue;
buffer[starting+2] = yvalue;
}
}

CGDataProviderRef imgProvider = CGDataProviderCreateWithData(NULL,
buffer,
bufferSize,
release_frame);

_img = CGImageCreate(frameToRender.format.imageWidth,
frameToRender.format.imageHeight,
8,
24,
3 * frameToRender.format.imageWidth,
CGColorSpaceCreateDeviceRGB(),
kCGBitmapByteOrder32Big | kCGImageAlphaNone,
imgProvider,
NULL,
false,
kCGRenderingIntentDefault);


CGDataProviderRelease(imgProvider);
dispatch_async(dispatch_get_main_queue(), ^{
[self setNeedsDisplay];
});
});
}

# Basic Video Capturer (video-capturer-basic branch)

To see the code for this sample, switch to the video-capturer-basic branch. This branch shows you
how to make minor modifications to the video capturer used by the OTPublisher class.

In this example, the app uses a custom video capturer to publish random pixels (white noise).
This is done simply to illustrate the basic principals of setting up a custom video capturer.
(For a more practical example, see the Camera Video Capturer and Screen Video Capturer examples,
described in the sections that follow.)

In the main ViewController, after calling `[_session publish:_publisher error:&error]` to
initiate publishing of an audio-video stream, the `videoCapture` property of the OTPublisher
object is set to an instance of OTKBasicVideoCapturer:

_publisher.videoCapture = [[OTKBasicVideoCapturer alloc] init];

OTKBasicVideoCapturer is a custom class that implements the OTVideoCapture protocol (defined
in the OpenTok iOS SDK). This protocol lets you define a custom video capturer to be used
by an OpenTok publisher.

The `[OTVideoCapture initCapture:]` method initializes capture settings to be used by the custom
video capturer. In this sample's custom implementation of OTVideoCapture (OTKBasicVideoCapturer)
the `initCapture` method sets properties of the `format` property of the OTVideoCapture instance:

- (void)initCapture
{
self.format = [[OTVideoFormat alloc] init];
self.format.pixelFormat = OTPixelFormatARGB;
self.format.bytesPerRow = [@[@(kImageWidth * 4)] mutableCopy];
self.format.imageHeight = kImageHeight;
self.format.imageWidth = kImageWidth;
}

The OTVideoFormat class (which defines this `format` property) is defined by the OpenTok iOS SDK.
In this sample code, the format of the video capturer is set to use ARGB as the pixel format,
with a specific number of bytes per row, a specific height, and a specific width.

The `[OTVideoCapture setVideoCaptureConsumer]` sets an OTVideoCaptureConsumer object (defined
by the OpenTok iOS SDK) the the video consumer uses to transmit video frames to the publisher's
stream. In the OTKBasicVideoCapturer, this method sets a local OTVideoCaptureConsumer instance
as the consumer:

- (void)setVideoCaptureConsumer:(id<OTVideoCaptureConsumer>)videoCaptureConsumer
{
// Save consumer instance in order to use it to send frames to the session
self.consumer = videoCaptureConsumer;
}

The `[OTVideoCapture startCapture:]` method is called when a publisher starts capturing video
to send as a stream to the OpenTok session. This will occur after the `[Session publish: error:]`
method is called. In the OTKBasicVideoCapturer of this method, the `[self produceFrame]` method
is called on a background queue after a set interval:

- (int32_t)startCapture
{
self.captureStarted = YES;
dispatch_after(kTimerInterval,
dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
^{
[self produceFrame];
});

return 0;
}

The `[self produceFrame]` method generates an OTVideoFrame object (defined by the OpenTok
iOS SDK) that represents a frame of video. In this case, the frame contains random pixels filling
the defined height and width for the sample video format:

- (void)produceFrame
{
OTVideoFrame *frame = [[OTVideoFrame alloc] initWithFormat:self.format];

// Generate a image with random pixels
u_int8_t *imageData[1];
imageData[0] = malloc(sizeof(uint8_t) * kImageHeight * kImageWidth * 4);
for (int i = 0; i < kImageWidth * kImageHeight * 4; i+=4) {
imageData[0][i] = rand() % 255;   // A
imageData[0][i+1] = rand() % 255; // R
imageData[0][i+2] = rand() % 255; // G
imageData[0][i+3] = rand() % 255; // B
}

[frame setPlanesWithPointers:imageData numPlanes:1];
[self.consumer consumeFrame:frame];

free(imageData[0]);

if (self.captureStarted) {
dispatch_after(kTimerInterval,
dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
^{
[self produceFrame];
});
}
}

The method passes the frame to the `[consumeFrame]` method of the instance of the
OTVideoCaptureConsumer used by this video capturer (described above). This causes the publisher
to send the frame of data to the video stream in the session.


# Camera video capturer (video-capturer-camera branch)

To see the code for this sample, switch to the video-capturer-camera branch. This branch shows you
how to use a custom video capturer using the device camera as the video source.

Before studying this sample, see the video-capturer-basic sample.

This sample code uses the Apple AVFoundation framework to capture video from a camera and publish it
to a connected session. The ViewController class creates a session, instantiates subscribers, and
sets up the publisher. The `captureOutput` method creates a frame, captures a screenshot, tags the
frame with a timestamp and saves it in an instance of consumer. The publisher accesses the consumer
to obtain the video frame.

Note that because this sample needs to access the device's camera, you must test it on an iOS
device. You cannot test it in the iOS simulator.

## Initializing and configuring the video capturer

The `[OTKBasicVideoCapturer initWithPreset: andDesiredFrameRate:]` method is an initializer for
the OTKBasicVideoCapturer class. It calls the `sizeFromAVCapturePreset` method to set the resolution of the image. The image size and frame rate are also set here. A separate queue is created for capturing images, so as not to affect the UI queue.

- (id)initWithPreset:(NSString *)preset andDesiredFrameRate:(NSUInteger)frameRate
{
self = [super init];
if (self) {
self.sessionPreset = preset;
CGSize imageSize = [self sizeFromAVCapturePreset:self.sessionPreset];
_imageHeight = imageSize.height;
_imageWidth = imageSize.width;
_desiredFrameRate = frameRate;

_captureQueue = dispatch_queue_create("com.tokbox.OTKBasicVideoCapturer",
DISPATCH_QUEUE_SERIAL);
}
return self;
}

The `sizeFromAVCapturePreset` method identifies the string value of the image resolution in
the iOS AVFoundation framework and returns a CGSize representation.

The implementation of the `[OTVideoCapture initCapture]` method uses the AVFoundation framework
to set the camera to capture images. In the first part of the method an instance of the
AVCaptureVideoDataOutput is used to produce image frames:

- (void)initCapture
{
NSError *error;
self.captureSession = [[AVCaptureSession alloc] init];

[self.captureSession beginConfiguration];

// Set device capture
self.captureSession.sessionPreset = self.sessionPreset;
AVCaptureDevice *videoDevice =
[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
self.inputDevice =
[AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
[self.captureSession addInput:self.inputDevice];

AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
outputDevice.alwaysDiscardsLateVideoFrames = YES;
outputDevice.videoSettings =
@{(NSString *)kCVPixelBufferPixelFormatTypeKey:
@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
)};

[outputDevice setSampleBufferDelegate:self queue:self.captureQueue];

[self.captureSession addOutput:outputDevice];

// See the next section ...
}

The frames captured with this method are accessed with the
`[AVCaptureVideoDataOutputSampleBufferDelegate captureOutput:didOutputSampleBuffer:fromConnection:]`
delegate method. The AVCaptureDevice object represents the camera and its properties. It provides captured images to an AVCaptureSession object.

The second part of the `initCapture` method calls the `bestFrameRateForDevice` method to obtain
the best frame rate for image capture:

- (void)initCapture
{
// See previous section ...

// Set framerate
double bestFrameRate = [self bestFrameRateForDevice];

CMTime desiredMinFrameDuration = CMTimeMake(1, bestFrameRate);
CMTime desiredMaxFrameDuration = CMTimeMake(1, bestFrameRate);

[self.inputDevice.device lockForConfiguration:&error];
self.inputDevice.device.activeVideoMaxFrameDuration = desiredMaxFrameDuration;
self.inputDevice.device.activeVideoMinFrameDuration = desiredMinFrameDuration;

[self.captureSession commitConfiguration];

self.format = [OTVideoFormat videoFormatNV12WithWidth:self.imageWidth
height:self.imageHeight];
}

The `[self bestFrameRateForDevice]` method returns the best frame rate for the capturing device:

- (double)bestFrameRateForDevice
{
double bestFrameRate = 0;
for (AVFrameRateRange* range in
self.inputDevice.device.activeFormat.videoSupportedFrameRateRanges)
{
CMTime currentDuration = range.minFrameDuration;
double currentFrameRate = currentDuration.timescale / currentDuration.value;
if (currentFrameRate > bestFrameRate && currentFrameRate < self.desiredFrameRate) {
bestFrameRate = currentFrameRate;
}
}
return bestFrameRate;
}

The AVFoundation framework requires a minimum and maximum range of frame rates to optimize the quality of an image capture. This range is set in the `bestFrameRate` object. For simplicity, the minimum and maximum frame rate is set as the same number but you may want to set your own minimum and maximum frame rates to obtain better image quality based on the speed of your network. In this application, the frame rate and resolution are fixed.

This method sets the video capture consumer, defined by the OTVideoCaptureConsumer protocol.

- (void)setVideoCaptureConsumer:(id<OTVideoCaptureConsumer>)videoCaptureConsumer
{
self.consumer = videoCaptureConsumer;
}

The `[OTVideoCapture captureSettings]` method sets the pixel format and size of the image used
by the video capturer, by setting properties of the OTVideoFormat object.

The `[[OTVideoCapture currentDeviceOrientation]` method queries the orientation of the image in
AVFoundation framework and returns its equivalent defined by the OTVideoOrientation enum in
OpenTok iOS SDK.

## Capturing frames for the publisher's video

The implementation of the `[OTVideoCapture startCapture]` method is called when the
publisher starts capturing video to publish. It calls the `[AVCaptureSession startRunning]` method
of the AVCaptureSession object:

- (int32_t)startCapture
{
self.captureStarted = YES;
[self.captureSession startRunning];

return 0;
}

The
`[AVCaptureVideoDataOutputSampleBufferDelegate captureOutput:didOutputSampleBuffer:fromConnection:]`
delegate method is called when a new video frame is available from the camera.

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
fromConnection:(AVCaptureConnection *)connection
{
if (!self.captureStarted)
return;

CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
OTVideoFrame *frame = [[OTVideoFrame alloc] initWithFormat:self.format];

NSUInteger planeCount = CVPixelBufferGetPlaneCount(imageBuffer);

uint8_t *buffer = malloc(sizeof(uint8_t) * CVPixelBufferGetDataSize(imageBuffer));
uint8_t *dst = buffer;
uint8_t *planes[planeCount];

CVPixelBufferLockBaseAddress(imageBuffer, 0);
for (int i = 0; i < planeCount; i++) {
size_t planeSize = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i)
* CVPixelBufferGetHeightOfPlane(imageBuffer, i);

planes[i] = dst;
dst += planeSize;

memcpy(planes[i],
CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i),
planeSize);
}

CMTime minFrameDuration = self.inputDevice.device.activeVideoMinFrameDuration;
frame.format.estimatedFramesPerSecond = minFrameDuration.timescale / minFrameDuration.value;
frame.format.estimatedCaptureDelay = 100;
frame.orientation = [self currentDeviceOrientation];

CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
frame.timestamp = time;
[frame setPlanesWithPointers:planes numPlanes:planeCount];

[self.consumer consumeFrame:frame];

free(buffer);
CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

This method does the following:

* Creates an OTVideoFrame instance to define the new video frame.

* Saves an image buffer of memory based on the size of the image.

* Writes image data from two planes into one member buffer. Since the image is an NV12, its data is
distributed over two planes. There is a plane for Y data and a plane for UV data. A for loop is
executed to iterate through both planes and write their data into one memory buffer.

* Creates a timestamp to tag a captured image. Every image is tagged with a timestamp so both
publisher and subscriber are able to create the same timeline and reference the frames in the same
order.

* Calls the `[OTVideoCaptureConsumer consumeFrame:]` method, passing in the OTVideoFrame object.
This causes the publisher to send the frame in the stream it publishes.

The implementation of the
`[AVCaptureVideoDataOutputSampleBufferDelegate captureOutput:didDropSampleBuffer:fromConnection]`
method is called whenever there is a delay in receiving frames. It drops frames to keep publishing
to the session without interruption:

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
fromConnection:(AVCaptureConnection *)connection
{
NSLog(@"Frame dropped");
}

## Other notes on the app

The OTVideoCapture protocol includes other required methods, which are implemented by
the OTKBasicVideoCapturer class. However, this sample does not do anything interesting in
these methods, so they are not included in this discussion.


# Screen sharing (screen-sharing branch)

To see the code for this sample, switch to the screen-sharing branch. This branch shows you
how to capture the screen (a UIView) using a custom video capturer.

Before studying this sample, see the video-capturer-basic sample.

This sample code demonstrates how to use the OpenTok iOS SDK to publish a screen-sharing video,
using the device screen as the source for the stream's video. The sample uses the `initCapture`,
`releaseCapture`, `startCapture`, `stopCapture`, and `isCaptureStarted` methods of the OTVideoKit
class to manage capture functions of the application. The ViewController class creates a session,
instantiates subscribers and sets up the publisher. The OTKBasicVideoCapturer class creates a frame,
captures a screenshot, tags the frame with a timestamp and saves it in an instance of consumer. The
publisher accesses the consumer to obtain the frame.

The `initCapture` method is used to initialize the capture and sets value for the pixel format of
an OTVideoFrame object. In this  example, it is set to RGB.

- (void)initCapture
{
self.format = [[OTVideoFormat alloc] init];
self.format.pixelFormat = OTPixelFormatARGB;
}

The `releaseCapture` method clears the memory buffer:

- (void)releaseCapture
{
self.format = nil;
}

The `startCapture` method creates a separate thread and calls the `produceFrame` method to start
screen captures:

- (int32_t)startCapture
{
self.captureStarted = YES;
dispatch_after(kTimerInterval,
dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
^{
@autoreleasepool {
[self produceFrame];
}
});

return 0;
}

The produceFrame method:

* Defines the frame for captured images.

* Creates a timestamp to tag a captured image.

* Takes a screenshot

* Converts the screenshot to a readable format

* Tags the screenshot with a timestamp

* Calculates the size of the image

* Sets the consumeFrame with the image

* Calls itself 15 times per second once the capture starts

The frame for the captured images is set as an object of OTVideoFrame. Properties of OTVideoFrame define the planes, timestamp, orientation and format of a frame.

OTVideoFrame *frame = [[OTVideoFrame alloc] initWithFormat:self.format];

A timestamp is created to tag the image. Every image is tagged with a timestamp so both publisher and subscriber are able to create the same timeline and reference the frames in the same order.

static mach_timebase_info_data_t time_info;
uint64_t time_stamp = 0;

time_stamp = mach_absolute_time();
time_stamp *= time_info.numer;
time_stamp /= time_info.denom;

The screenshot method is called to obtain an image of the screen.

CGImageRef screenshot = [[self screenshot] CGImage];

The fillPixelBufferFromCGImage method converts the image data of a CGImage into a CVPixelBuffer.

[self fillPixelBufferFromCGImage:screenshot];

The frame is tagged with a timestamp and capture rate in frames per second and delay between captures are set.

CMTime time = CMTimeMake(time_stamp, 1000);   
frame.timestamp = time;
frame.format.estimatedFramesPerSecond = kFramesPerSecond;
frame.format.estimatedCaptureDelay = 100;

The number of bytes in a single row is multiplied with the height of the image to obtain the size of the image. Note, the single element array and bytes per row are based on a 4-byte, single plane specification of an RGB image. 

frame.format.imageWidth = CVPixelBufferGetWidth(pixelBuffer);
frame.format.imageHeight = CVPixelBufferGetHeight(pixelBuffer);
frame.format.bytesPerRow = [@[@(frame.format.imageWidth * 4)] mutableCopy];
frame.orientation = OTVideoOrientationUp;

CVPixelBufferLockBaseAddress(pixelBuffer, 0);
uint8_t *planes[1];

planes[0] = CVPixelBufferGetBaseAddress(pixelBuffer);
[frame setPlanesWithPointers:planes numPlanes:1];

The frame is saved in an instance of consumer. The publisher accesses captured images through the consumer instance.

[self.consumer consumeFrame:frame];

The pixel buffer is cleared and a background-priority queue (separate from the queue used by the UI)
is used to capture images. If image capture is in progress, the `produceFrame` method calls itself
15 times per second.

CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);   
if (self.captureStarted) {
dispatch_after(kTimerInterval,
dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
^{
@autoreleasepool {
[self produceFrame];
}
});
}

The `screenshot` method takes a screenshot and returns an image. This method is called by the
`produceFrame` method.

- (UIImage *)screenshot
{
CGSize imageSize = CGSizeZero;

imageSize = [UIScreen mainScreen].bounds.size;

UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
UIWindow *window = [UIApplication sharedApplication].keyWindow;

if ([window respondsToSelector:
@selector(drawViewHierarchyInRect:afterScreenUpdates:)])
{
[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
}
else {
[window.layer renderInContext:UIGraphicsGetCurrentContext()];
}

UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();
return image;
}


# Other resources

See the following:

* [API reference] [7] -- Provides details on the OpenTok iOS SDK API
* [Tutorials] [8] -- Includes conceptual information and code samples for all OpenTok features
* [Sample code] [9] (Also included in the OpenTok iOS SDK download) -- Includes sample apps
that show more features of the OpenTok iOS SDK

[1]: https://tokbox.com/opentok/libraries/client/ios/
[2]: https://dashboard.tokbox.com
[3]: https://tokbox.com/opentok/starter-kits/
[4]: https://tokbox.com/opentok/tutorials/create-session/#media-mode
[5]: https://tokbox.com/opentok/tutorials/create-token/
[6]: https://developer.apple.com/library/mac/documentation/AVFoundation/Reference/AVCaptureDevice_Class
[7]: https://tokbox.com/opentok/libraries/client/ios/reference/
[8]: https://tokbox.com/opentok/tutorials/
[9]: https://github.com/opentok/opentok-ios-sdk-samples
