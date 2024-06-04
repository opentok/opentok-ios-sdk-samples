//
//  OTDefaultAudioDeviceIOS.m
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import "OTDefaultAudioDevice.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

/*
 *  System Versioning Preprocessor Macros
 */

#define SYSTEM_VERSION_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v \
options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v) \
([[[UIDevice currentDevice] systemVersion] compare:v \
options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v \
options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v) \
([[[UIDevice currentDevice] systemVersion] compare:v \
options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v \
options:NSNumericSearch] != NSOrderedDescending)


// Simulator *must* run at 44.1 kHz in order to function properly.
#if (TARGET_IPHONE_SIMULATOR)
#define kSampleRate 44100
#else
#define kSampleRate 48000
#endif

#define OT_ENABLE_AUDIO_DEBUG 1
#define RETRY_COUNT 5
#if OT_ENABLE_AUDIO_DEBUG
#define OT_AUDIO_DEBUG(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#define OT_AUDIO_DEBUG(fmt, ...)
#endif

static double kPreferredIOBufferDuration = 0.01;

static mach_timebase_info_data_t info;

static OSStatus recording_cb(void *ref_con,
                             AudioUnitRenderActionFlags *action_flags,
                             const AudioTimeStamp *time_stamp,
                             UInt32 bus_num,
                             UInt32 num_frames,
                             AudioBufferList *data);

static OSStatus playout_cb(void *ref_con,
                           AudioUnitRenderActionFlags *action_flags,
                           const AudioTimeStamp *time_stamp,
                           UInt32 bus_num,
                           UInt32 num_frames,
                           AudioBufferList *data);
static NSInteger channelState;

@interface OTDefaultAudioDevice ()
- (BOOL) setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout;
- (void) setupListenerBlocks;
@end

@implementation OTDefaultAudioDevice
{
    OTAudioFormat *_audioFormat;
    
    AudioUnit recording_voice_unit;
    AudioUnit playout_voice_unit;
    BOOL playing;
    BOOL playout_initialized;
    BOOL recording;
    BOOL recording_initialized;
    BOOL interrupted_playback;
    NSString* _previousAVAudioSessionCategory;
    NSString* avAudioSessionMode;
    double avAudioSessionPreffSampleRate;
    NSInteger avAudioSessionChannels;
    BOOL isAudioSessionSetup;
    BOOL isRecorderInterrupted;
    BOOL isPlayerInterrupted;
    BOOL areListenerBlocksSetup;
    BOOL _isResetting;
    int _restartRetryCount;
    
    /* synchronize all access to the audio subsystem */
    dispatch_queue_t _safetyQueue;
    NSTimer *channelTimer;

@public
    id _audioBus;
    
    AudioBufferList *buffer_list;
    uint32_t buffer_num_frames;
    uint32_t buffer_size;
    uint32_t _recordingDelay;
    uint32_t _playoutDelay;
    uint32_t _playoutDelayMeasurementCounter;
    uint32_t _recordingDelayHWAndOS;
    uint32_t _recordingDelayMeasurementCounter;
    Float64 _playout_AudioUnitProperty_Latency;
    Float64 _recording_AudioUnitProperty_Latency;
}

#pragma mark - OTAudioDeviceImplementation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioFormat = [[OTAudioFormat alloc] init];
        _audioFormat.sampleRate = kSampleRate;
        _audioFormat.numChannels = 2;
        _safetyQueue = dispatch_queue_create("ot-audio-driver",
                                             DISPATCH_QUEUE_SERIAL);
        _restartRetryCount = 0;
    }
    return self;
}

- (BOOL)setAudioBus:(id<OTAudioBus>)audioBus
{
    OT_AUDIO_DEBUG(@"%s", __PRETTY_FUNCTION__);
    _audioBus = audioBus;
    _audioFormat = [[OTAudioFormat alloc] init];
    _audioFormat.sampleRate = kSampleRate;
    _audioFormat.numChannels = 2;
    
    channelState = 1;  // Start with state 1
    channelTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                         target:self
                                                       selector:@selector(updateChannelState)
                                                       userInfo:nil
                                                        repeats:YES];
    
    return YES;
}

- (void)updateChannelState {
    channelState = (channelState % 6) + 1;
    NSLog(@"Channel State Updated to: %ld", (long)channelState);
}

- (void)dealloc
{
    [self removeObservers];
    [self teardownAudio];
    _audioFormat = nil;
}

- (OTAudioFormat*)captureFormat
{
    return _audioFormat;
}

- (OTAudioFormat*)renderFormat
{
    return _audioFormat;
}

- (BOOL)renderingIsAvailable
{
    return YES;
}

// Audio Unit lifecycle is bound to start/stop cycles, so we don't have much
// to do here.
- (BOOL)initializeRendering
{
    OT_AUDIO_DEBUG(@"%s", __PRETTY_FUNCTION__);
    if (playing) {
        return NO;
    }
    if (playout_initialized) {
        return YES;
    }
    playout_initialized = true;
    return YES;
}

- (BOOL)renderingIsInitialized
{
    OT_AUDIO_DEBUG(@"%s %d", __PRETTY_FUNCTION__, playout_initialized);
    return playout_initialized;
}

- (BOOL)captureIsAvailable
{
    OT_AUDIO_DEBUG(@"%s", __PRETTY_FUNCTION__);
    return YES;
}

// Audio Unit lifecycle is bound to start/stop cycles, so we don't have much
// to do here.
- (BOOL)initializeCapture
{
    OT_AUDIO_DEBUG(@"%s", __PRETTY_FUNCTION__);
    if (recording) {
        return NO;
    }
    if (recording_initialized) {
        return YES;
    }
    recording_initialized = true;
    return YES;
}

- (BOOL)captureIsInitialized
{
    OT_AUDIO_DEBUG(@"%s %d", __PRETTY_FUNCTION__, recording_initialized);
    return recording_initialized;
}

- (BOOL)startRendering
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"startRendering started with playing flag = %d", playing);
        
        if (playing) {
            return YES;
        }
        
        playing = YES;
        // Initialize only when playout voice unit is already teardown
        if(playout_voice_unit == NULL)
        {
            if (NO == [self setupAudioUnit:&playout_voice_unit playout:YES]) {
                playing = NO;
                return NO;
            }
        }
        
        OSStatus result = AudioOutputUnitStart(playout_voice_unit);
        if (CheckError(result, @"startRendering.AudioOutputUnitStart")) {
            playing = NO;
        }
        OT_AUDIO_DEBUG(@"startRendering ended with playing flag = %d", playing);
        return playing;
    }
}

- (BOOL)stopRendering
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"stopRendering started with playing flag = %d", playing);
        
        if (!playing) {
            return YES;
        }
        
        playing = NO;
        
        OSStatus result = AudioOutputUnitStop(playout_voice_unit);
        if (CheckError(result, @"stopRendering.AudioOutputUnitStop")) {
            return NO;
        }
        
        // publisher is already closed
        if (!recording && !isPlayerInterrupted && !_isResetting)
        {
            OT_AUDIO_DEBUG(@"teardownAudio from stopRendering");
            [self teardownAudio];
        }
        OT_AUDIO_DEBUG(@"stopRendering finshed properly");
        return YES;
    }
}

- (BOOL)isRendering
{
    return playing;
}

- (BOOL)startCapture
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"startCapture started with recording flag = %d", recording);
        
        if (recording) {
            return YES;
        }
        
        recording = YES;
        // Initialize only when recording voice unit is already teardown
        if(recording_voice_unit == NULL)
        {
            if (NO == [self setupAudioUnit:&recording_voice_unit playout:NO]) {
                recording = NO;
                return NO;
            }
        }

        OSStatus result = AudioOutputUnitStart(recording_voice_unit);
        if (CheckError(result, @"startCapture.AudioOutputUnitStart")) {
            recording = NO;
        }
        OT_AUDIO_DEBUG(@"startCapture finished with recording flag = %d", recording);
        return recording;
    }
}

- (BOOL)stopCapture
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"stopCapture started with recording flag = %d", recording);
        
        if (!recording) {
            return YES;
        }
        
        recording = NO;
        
        OSStatus result = AudioOutputUnitStop(recording_voice_unit);
        
        if (CheckError(result, @"stopCapture.AudioOutputUnitStop")) {
            return NO;
        }
        
        [self freeupAudioBuffers];
        
        // subscriber is already closed
        if (!playing && !isRecorderInterrupted && !_isResetting)
        {
            OT_AUDIO_DEBUG(@"teardownAudio from stopCapture");
            [self teardownAudio];
        }
        OT_AUDIO_DEBUG(@"stopCapture finshed properly");
        return YES;
    }
}

- (BOOL)isCapturing
{
    return recording;
}

- (uint16_t)estimatedRenderDelay
{
    return _playoutDelay;
}

- (uint16_t)estimatedCaptureDelay
{
    return _recordingDelay;
}

#pragma mark - AudioSession Setup

static NSString* FormatError(OSStatus error)
{
    uint32_t as_int = CFSwapInt32HostToLittle(error);
    uint8_t* as_char = (uint8_t*) &as_int;
    // see if it appears to be a 4-char-code
    if (isprint(as_char[0]) &&
        isprint(as_char[1]) &&
        isprint(as_char[2]) &&
        isprint(as_char[3]))
    {
        return [NSString stringWithFormat:@"%c%c%c%c",
                as_int >> 24, as_int >> 16, as_int >> 8, as_int];
    }
    else
    {
        // no, format it as an integer
        return [NSString stringWithFormat:@"%d", error];
    }
}

/**
 * @return YES if in error
 */
static bool CheckError(OSStatus error, NSString* function) {
    if (!error) return NO;
    
    NSString* error_string = FormatError(error);
    NSLog(@"ERROR[OpenTok]:Audio device error: %@ returned error: %@",
          function, error_string);
    
    return YES;
}

- (void)checkAndPrintError:(OSStatus)error function:(NSString *)function
{
    CheckError(error,function);
}

- (void)disposePlayoutUnit
{
    if (playout_voice_unit) {
        AudioUnitUninitialize(playout_voice_unit);
        AudioComponentInstanceDispose(playout_voice_unit);
        playout_voice_unit = NULL;
    }
}

- (void)disposeRecordUnit
{
    if (recording_voice_unit) {
        AudioUnitUninitialize(recording_voice_unit);
        AudioComponentInstanceDispose(recording_voice_unit);
        recording_voice_unit = NULL;
    }
}

- (void) teardownAudio
{
    [self disposePlayoutUnit];
    [self disposeRecordUnit];
    [self freeupAudioBuffers];
    
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    [mySession setCategory:_previousAVAudioSessionCategory error:nil];
    [mySession setMode:avAudioSessionMode error:nil];
    [mySession setPreferredSampleRate: avAudioSessionPreffSampleRate
                                error: nil];
    [mySession setPreferredInputNumberOfChannels:2
                                           error:nil];

    AVAudioSessionSetActiveOptions audioOptions = AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation;
    [mySession setActive:NO
             withOptions:audioOptions
                   error:nil];

    isAudioSessionSetup = NO;
}

- (void)freeupAudioBuffers
{
    if (buffer_list && buffer_list->mBuffers[0].mData) {
        free(buffer_list->mBuffers[0].mData);
        buffer_list->mBuffers[0].mData = NULL;
    }
    
    if (buffer_list) {
        free(buffer_list);
        buffer_list = NULL;
        buffer_num_frames = 0;
    }
}
- (void) setupAudioSession
{
    if (isAudioSessionSetup) return;
    
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    _previousAVAudioSessionCategory = mySession.category;
    avAudioSessionMode = mySession.mode;
    avAudioSessionPreffSampleRate = mySession.preferredSampleRate;
    avAudioSessionChannels = 2;
    
    [mySession setPreferredSampleRate: kSampleRate error: nil];
    [mySession setPreferredInputNumberOfChannels:2 error:nil];
    [mySession setPreferredIOBufferDuration:kPreferredIOBufferDuration
                                      error:nil];
    
    NSError *error = nil;
    NSUInteger audioOptions = 0;
#if !(TARGET_OS_TV)
    [mySession setCategory:AVAudioSessionCategoryPlayAndRecord
                        error:nil];
    AVAudioSessionPortDescription *routePort = mySession.currentRoute.outputs.firstObject;
    NSString *portType = routePort.portType;
    if ([portType isEqualToString:@"Receiver"]) {
           [mySession  overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    } else {
           [mySession  overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
    }
#else
    [mySession setCategory:AVAudioSessionCategoryPlayback
               withOptions:audioOptions
                     error:&error];
#endif
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        [mySession setMode:AVAudioSessionModeVideoChat error:nil];
    }
    else {
        [mySession setMode:AVAudioSessionModeVoiceChat error:nil];
    }
    
    if (error)
        OT_AUDIO_DEBUG(@"Audiosession setCategory %@",error);
    
    error = nil;
    
    [self setupListenerBlocks];
    [mySession setActive:YES error:&error];
    
    if (error)
        OT_AUDIO_DEBUG(@"Audiosession setActive %@",error);

    if (@available(iOS 15, *)) {
        // do nothing refer comments for self.setBluetoothAsPrefferedInputDevice method.
    } else {
        [self setBluetoothAsPrefferedInputDevice];
    }
    isAudioSessionSetup = YES;
}

- (void)setBluetoothAsPrefferedInputDevice {
  // Apple's Bug(???) : Before iOS 15 AVAudioSessionInterruptionTypeEnded notification would
  // not be called for bluetooth if we dont set bluetooth as preferred input as
  // in setupAudioSession. In iOS 15 starting a session with BT and then disconnecting it
  // would cause the camera to freeze for some reason (an Apple Bug again ??)
  //
  // This method is also called on AVAudioSessionInterruptionTypeEnded, because BT audio
  // routing would be lost, if you received a phone call and ended it, while
  // using BT with OT
  //
  // Should work for non bluetooth routes/ports too. This makes both input
  // and output to bluetooth device if available.
  NSArray *bluetoothRoutes = @[
    AVAudioSessionPortBluetoothA2DP, AVAudioSessionPortBluetoothLE,
    AVAudioSessionPortBluetoothHFP
  ];
  NSArray *routes = [[AVAudioSession sharedInstance] availableInputs];
  for (AVAudioSessionPortDescription *route in routes) {
    if ([bluetoothRoutes containsObject:route.portType]) {
      [[AVAudioSession sharedInstance] setPreferredInput:route error:nil];
      break;
    }
  }
}

#pragma mark - System interruptions and audio route changes

- (void) onInterruptionEvent:(NSNotification *) notification
{
    OT_AUDIO_DEBUG(@"onInterruptionEvent %@",notification);
    
    NSDictionary *interruptionDict = notification.userInfo;
    NSInteger interruptionType =
    [[interruptionDict valueForKey:AVAudioSessionInterruptionTypeKey]
     integerValue];

    dispatch_async(_safetyQueue, ^() {
        [self handleInterruptionEvent:interruptionType];
    });
}

- (void) handleInterruptionEvent:(NSInteger) interruptionType
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"handleInterruptionEvent %ld",(long)interruptionType);
        switch (interruptionType) {
            case AVAudioSessionInterruptionTypeBegan:
            {
                OT_AUDIO_DEBUG(@"AVAudioSessionInterruptionTypeBegan");
                if(recording)
                {
                    isRecorderInterrupted = YES;
                    [self stopCapture];
                }
                if(playing)
                {
                    isPlayerInterrupted = YES;
                    [self stopRendering];
                }
            }
                break;
                
            case AVAudioSessionInterruptionTypeEnded:
            {
                OT_AUDIO_DEBUG(@"AVAudioSessionInterruptionTypeEnded");
                if (@available(iOS 15, *)) {
                    [self setBluetoothAsPrefferedInputDevice];
                } else {
                    // do nothing refer comments for self.setBluetoothAsPrefferedInputDevice method.
                }
                if(isRecorderInterrupted)
                {
                    if([self startCapture] == YES)
                    {
                        isRecorderInterrupted = NO;
                        _restartRetryCount = 0;
                    } else
                    {
                        _restartRetryCount++;
                        if(_restartRetryCount < RETRY_COUNT)
                        {
                            dispatch_after(
                                           dispatch_time(
                                                         DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                                           _safetyQueue, ^{
                                               [self handleInterruptionEvent:
                                                AVAudioSessionInterruptionTypeEnded];
                                            OT_AUDIO_DEBUG(@"Recorder retry");
                                           });
                        } else
                        {
                            // This shouldn't happen!
                            isRecorderInterrupted = NO;
                            isPlayerInterrupted = NO;
                            _restartRetryCount = 0;
                            OT_AUDIO_DEBUG(@"Unable to acquire audio session");
                        }
                        return;
                    }
                }
                
                if(isPlayerInterrupted)
                {
                    if([self startRendering] == YES)
                    {
                        isPlayerInterrupted = NO;
                        _restartRetryCount = 0;
                    } else
                    {
                        _restartRetryCount++;
                        if(_restartRetryCount < RETRY_COUNT)
                        {
                            dispatch_after(
                                           dispatch_time(
                                                         DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                                           _safetyQueue, ^{
                                               [self handleInterruptionEvent:
                                                AVAudioSessionInterruptionTypeEnded];
                                            OT_AUDIO_DEBUG(@"Player restart");
                                           });
                        } else
                        {
                            isRecorderInterrupted = NO;
                            isPlayerInterrupted = NO;
                            _restartRetryCount = 0;
                            OT_AUDIO_DEBUG(@"Unable to acquire audio session");
                        }
                        return;
                    }
                }

            }
                break;
                
            default:
                OT_AUDIO_DEBUG(@"Audio Session Interruption Notification"
                               " case default.");
                break;
        }
    }
}

- (void) onRouteChangeEvent:(NSNotification *) notification
{
    OT_AUDIO_DEBUG(@"onRouteChangeEvent %@",notification);
    dispatch_async(_safetyQueue, ^() {
        [self handleRouteChangeEvent:notification];
    });
}

- (void) handleRouteChangeEvent:(NSNotification *) notification
{
    NSDictionary *interruptionDict = notification.userInfo;
    NSInteger routeChangeReason =
    [[interruptionDict valueForKey:AVAudioSessionRouteChangeReasonKey]
     integerValue];

    // We'll receive a routeChangedEvent when the audio unit starts; don't
    // process events we caused internally. And when switching calls using
    // CallKit, iOS system generates a category change which we should Ignore!
    if (AVAudioSessionRouteChangeReasonRouteConfigurationChange ==
            routeChangeReason ||
        AVAudioSessionRouteChangeReasonCategoryChange == routeChangeReason) {
      return;
    }

    if(routeChangeReason == AVAudioSessionRouteChangeReasonOverride ||
       routeChangeReason == AVAudioSessionRouteChangeReasonCategoryChange)
    {
        NSString *oldOutputDeviceName = nil;
        NSString *currentOutputDeviceName = nil;
        
        AVAudioSessionRouteDescription* oldRouteDesc =
        [interruptionDict valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
        NSArray<AVAudioSessionPortDescription*>* outputs =
        [oldRouteDesc outputs];
        
        if(outputs.count > 0)
        {
            AVAudioSessionPortDescription *portDesc =
            (AVAudioSessionPortDescription *)[outputs objectAtIndex:0];
            oldOutputDeviceName = [portDesc portName];
        }
        
        if([[[AVAudioSession sharedInstance] currentRoute] outputs].count > 0)
        {
            currentOutputDeviceName = [[[[[AVAudioSession sharedInstance] currentRoute] outputs]
                                        objectAtIndex:0] portName];
        }
        
        // we need check this because some times we will receive category change
        // with the same device.
        if([oldOutputDeviceName isEqualToString:currentOutputDeviceName] ||
           currentOutputDeviceName == nil ||  oldOutputDeviceName == nil) {
            return;
        }
        OT_AUDIO_DEBUG(@"routeChanged: old=%@ new=%@",
                       oldOutputDeviceName, currentOutputDeviceName);
    }
    
    @synchronized(self) {
        // We've made it here, there's been a legit route change.
        // Restart the audio units with correct sample rate
        _isResetting = YES;
        
        if (recording)
        {
            [self stopCapture];
            [self disposeRecordUnit];
            [self startCapture];
        }
        
        if (playing)
        {
            [self stopRendering];
            [self disposePlayoutUnit];
            [self startRendering];
        }
        
        _isResetting = NO;
    }

}

/* When ringer is off, we dont get interruption ended callback
 as mentioned in apple doc : "There is no guarantee that a begin
 interruption will have an end interruption."
 The only caveat here is, some times we get two callbacks from interruption
 handler as well as from here which we handle synchronously with safteyQueue
 */
- (void) appDidBecomeActive:(NSNotification *) notification
{
    OT_AUDIO_DEBUG(@"appDidBecomeActive %@",notification);
    dispatch_async(_safetyQueue, ^{
        [self handleInterruptionEvent:AVAudioSessionInterruptionTypeEnded];
    });
}

- (void) setupListenerBlocks
{
    if(!areListenerBlocksSetup)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        
        [center addObserver:self
                   selector:@selector(onInterruptionEvent:)
                       name:AVAudioSessionInterruptionNotification object:nil];
        
        [center addObserver:self
                   selector:@selector(onRouteChangeEvent:)
                       name:AVAudioSessionRouteChangeNotification object:nil];
        
        [center addObserver:self
                   selector:@selector(appDidBecomeActive:)
                       name:UIApplicationDidBecomeActiveNotification
                     object:nil];

        areListenerBlocksSetup = YES;
    }
}

- (void) removeObservers
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self];
    areListenerBlocksSetup = NO;
}

#pragma mark - native audio callbacks

static void update_recording_delay(OTDefaultAudioDevice* device) {
    
    device->_recordingDelayMeasurementCounter++;
    
    if (device->_recordingDelayMeasurementCounter >= 100) {
        // Update HW and OS delay every second, unlikely to change
        
        device->_recordingDelayHWAndOS = 0;
        
        AVAudioSession *mySession = [AVAudioSession sharedInstance];
        
        // HW input latency
        NSTimeInterval interval = [mySession inputLatency];
        
        device->_recordingDelayHWAndOS += (int)(interval * 1000000);
        
        // HW buffer duration
        interval = [mySession IOBufferDuration];
        device->_recordingDelayHWAndOS += (int)(interval * 1000000);
        
        device->_recordingDelayHWAndOS += (int)(device->_recording_AudioUnitProperty_Latency * 1000000);
        
        // To ms
        device->_recordingDelayHWAndOS =
        (device->_recordingDelayHWAndOS - 500) / 1000;
        
        // Reset counter
        device->_recordingDelayMeasurementCounter = 0;
    }
    
    device->_recordingDelay = device->_recordingDelayHWAndOS;
}

#define TONE_FREQUENCY 440
#define M_TAU 2.0 * M_PI

static OSStatus recording_cb(void *ref_con,
                             AudioUnitRenderActionFlags *action_flags,
                             const AudioTimeStamp *time_stamp,
                             UInt32 bus_num,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData)
{
    OTDefaultAudioDevice *dev = (__bridge OTDefaultAudioDevice*) ref_con;
 
  
    
    if (dev->recording) {
        static float theta;

        // Assuming ioData has only one buffer for interleaved data
        SInt16 *buffer = (SInt16 *)ioData->mBuffers[0].mData;
        for (UInt32 frame = 0; frame < inNumberFrames; ++frame) {
            if (channelState == 1) {
                // Write left channel
                buffer[2 * frame] = (SInt16)(sin(theta) * 32767.0f);
                // Write right channel (silenced in your original example)
                buffer[2 * frame + 1] = 0;
            } else if (channelState == 2) {
                // Write left channel
                buffer[2 * frame] = 0;
                // Write right channel (silenced in your original example)
                buffer[2 * frame + 1] = 0; //0;
            } else if (channelState == 3) {
                // Write left channel
                buffer[2 * frame] = (SInt16)(sin(theta) * 32767.0f);;
                // Write right channel (silenced in your original example)
                buffer[2 * frame + 1] = (SInt16)(sin(theta) * 32767.0f);
            }else if (channelState == 4) {
                // Write left channel
                buffer[2 * frame] = 0;
                // Write right channel (silenced in your original example)
                buffer[2 * frame + 1] = 0;
            } else if (channelState == 5) {
                // Write left channel
                buffer[2 * frame] = 0;
                // Write right channel (silenced in your original example)
                buffer[2 * frame + 1] = (SInt16)(sin(theta) * 32767.0f);
            } else if (channelState == 6) {
                // Write left channel
                buffer[2 * frame] = 0;
                // Write right channel (silenced in your original example)
                buffer[2 * frame + 1] = 0;
            }
 

            // Increment theta for the tone frequency
            theta += M_TAU * TONE_FREQUENCY / kSampleRate;
            if (theta > M_TAU) {
                theta -= M_TAU;
            }
        }
        
  
        // Write the captured data to the audio bus
        [dev->_audioBus writeCaptureData:buffer
                          numberOfSamples:inNumberFrames]; // multiply by 2 because each frame now includes two samples (left and right)
        // Access the interleaved buffer
        SInt16 * interleavedBuffer = (SInt16 *)ioData->mBuffers[0].mData;

        // Set all samples to zero for both left and right channels
        for (UInt32 frame = 0; frame < inNumberFrames; ++frame) {
            interleavedBuffer[2 * frame] = 0;      // Left channel
            interleavedBuffer[2 * frame + 1] = 0;  // Right channel
        }

    }

//    // Ensure the buffer size remains constant
//    if (dev->buffer_size != ioData->mBuffers[0].mDataByteSize)
//        ioData->mBuffers[0].mDataByteSize = dev->buffer_size;
    
    update_recording_delay(dev);
    return noErr;
}

static void update_playout_delay(OTDefaultAudioDevice* device) {
    device->_playoutDelayMeasurementCounter++;
    
    if (device->_playoutDelayMeasurementCounter >= 100) {
        // Update HW and OS delay every second, unlikely to change
        
        device->_playoutDelay = 0;
        
        AVAudioSession *mySession = [AVAudioSession sharedInstance];
        
        // HW output latency
        NSTimeInterval interval = [mySession outputLatency];
        
        device->_playoutDelay += (int)(interval * 1000000);
        
        // HW buffer duration
        interval = [mySession IOBufferDuration];
        device->_playoutDelay += (int)(interval * 1000000);
        
        device->_playoutDelay += (int)(device->_playout_AudioUnitProperty_Latency * 1000000);
        
        // To ms
        device->_playoutDelay = (device->_playoutDelay - 500) / 1000;
        
        // Reset counter
        device->_playoutDelayMeasurementCounter = 0;
    }
}

static OSStatus playout_cb(void *ref_con,
                           AudioUnitRenderActionFlags *action_flags,
                           const AudioTimeStamp *time_stamp,
                           UInt32 bus_num,
                           UInt32 num_frames,
                           AudioBufferList *buffer_list)
{
    OTDefaultAudioDevice *dev = (__bridge OTDefaultAudioDevice*) ref_con;
    
    if (!dev->playing) { return 0; }
    
    uint32_t count =
    [dev->_audioBus readRenderData:buffer_list->mBuffers[0].mData
                   numberOfSamples:num_frames];
    
    if (count != num_frames) {
        //TODO: Not really an error, but conerning. Network issues?
    }
    
    update_playout_delay(dev);
    
    return 0;
}

#pragma mark - BlueTooth

- (BOOL)isBluetoothDevice:(NSString*)portType {
    
    return ([portType isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [portType isEqualToString:AVAudioSessionPortBluetoothHFP]);
}


- (BOOL)detectCurrentRoute
{
    // called on startup to initialize the devices that are available...
    OT_AUDIO_DEBUG(@"detect current route");
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    _headsetDeviceAvailable = _bluetoothDeviceAvailable = NO;
    
    //ios 8.0 complains about Deactivating an audio session that has running
    // I/O. All I/O should be stopped or paused prior to deactivating the audio
    // session. Looks like we can get away by not using the setActive call
    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"7.0")) {
        // close down our current session...
        [audioSession setActive:NO error:nil];
        
        // start a new audio session. Without activation, the default route will
        // always be (inputs: null, outputs: Speaker)
        [audioSession setActive:YES error:nil];
    }
    
    // Check for current route
    AVAudioSessionRouteDescription *currentRoute = [audioSession currentRoute];
    for (AVAudioSessionPortDescription *output in currentRoute.outputs) {
        if ([[output portType] isEqualToString:AVAudioSessionPortHeadphones]) {
            _headsetDeviceAvailable = YES;
        } else if ([self isBluetoothDevice:[output portType]]) {
            _bluetoothDeviceAvailable = YES;
        }
    }
    
    if (_headsetDeviceAvailable) {
        OT_AUDIO_DEBUG(@"Current route is Headset");
    }
    
    if (_bluetoothDeviceAvailable) {
        OT_AUDIO_DEBUG(@"Current route is Bluetooth");
    }
    
    if(!_bluetoothDeviceAvailable && !_headsetDeviceAvailable) {
        OT_AUDIO_DEBUG(@"Current route is device speaker");
    }
    
    return YES;
}

- (BOOL)configureAudioSessionWithDesiredAudioRoute:(NSString*)desiredAudioRoute
{
    OT_AUDIO_DEBUG(@"configureAudioSessionWithDesiredAudioRoute %@",desiredAudioRoute);
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *err;
    
    //ios 8.0 complains about Deactivating an audio session that has running
    // I/O. All I/O should be stopped or paused prior to deactivating the audio
    // session. Looks like we can get away by not using the setActive call
    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"7.0")) {
        // close down our current session...
        [audioSession setActive:NO error:nil];
    }
    
    if ([AUDIO_DEVICE_BLUETOOTH isEqualToString:desiredAudioRoute]) {
        [self setBluetoothAsPrefferedInputDevice];
    }
    
    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"7.0")) {
        // Set our session to active...
        if (![audioSession setActive:YES error:&err]) {
            NSLog(@"unable to set audio session active: %@", err);
            return NO;
        }
    }
    
    if ([AUDIO_DEVICE_SPEAKER isEqualToString:desiredAudioRoute]) {
        // replace AudiosessionSetProperty (deprecated from iOS7) with
        // AVAudioSession overrideOutputAudioPort
#if !(TARGET_OS_TV)
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                        error:&err];
#endif
    } else
    {
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone
                                        error:&err];
    }
    
    return YES;
}

- (BOOL)setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout;
{
    OSStatus result;
    
    mach_timebase_info(&info);
    
    if (!isAudioSessionSetup)
    {
        [self setupAudioSession];
    }
    
    UInt32 bytesPerSample = sizeof(SInt16);
    stream_format.mFormatID = kAudioFormatLinearPCM;
    stream_format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; // Ensure no non-interleaved flag is set
    stream_format.mSampleRate = kSampleRate;
    stream_format.mChannelsPerFrame = 2;
    stream_format.mBitsPerChannel = 16;
    stream_format.mBytesPerFrame = (stream_format.mBitsPerChannel / 8) * stream_format.mChannelsPerFrame;
    stream_format.mFramesPerPacket = 1;
    stream_format.mBytesPerPacket = stream_format.mBytesPerFrame * stream_format.mFramesPerPacket;
    
    AudioComponentDescription audio_unit_description;
    audio_unit_description.componentType = kAudioUnitType_Output;
    
#if !(TARGET_OS_TV)
    audio_unit_description.componentSubType = kAudioUnitSubType_RemoteIO;
#else
    audio_unit_description.componentSubType = kAudioUnitSubType_RemoteIO;
#endif
    
    audio_unit_description.componentManufacturer = kAudioUnitManufacturer_Apple;
    audio_unit_description.componentFlags = 0;
    audio_unit_description.componentFlagsMask = 0;
    
    AudioComponent found_vpio_unit_ref =
    AudioComponentFindNext(NULL, &audio_unit_description);
    
    result = AudioComponentInstanceNew(found_vpio_unit_ref, voice_unit);
    
    if (CheckError(result, @"setupAudioUnit.AudioComponentInstanceNew")) {
        return NO;
    }
    
    if (!isPlayout)
    {
        
        AURenderCallbackStruct input_callback;
        input_callback.inputProc = recording_cb;
        input_callback.inputProcRefCon = (__bridge void *)(self);
        
        CheckError(AudioUnitSetProperty(*voice_unit,
                                        kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input, kOutputBus, &input_callback,
                                        sizeof(input_callback)),@"error 3");

        CheckError(AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, kOutputBus,
                                        &stream_format, sizeof (stream_format)),@"playout AudioUnitSetProperty error");


        
    } else
    {


        CheckError(AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, kOutputBus,
                                        &stream_format, sizeof (stream_format)),@"error b");
        AURenderCallbackStruct render_callback;
        render_callback.inputProc = playout_cb;;
        render_callback.inputProcRefCon = (__bridge void *)(self);
            CheckError(AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_SetRenderCallback,
                                     kAudioUnitScope_Input, kOutputBus, &render_callback,
                                            sizeof(render_callback)),@"error last");
    }
    
    Float64 f64 = 0;
    UInt32 size = sizeof(f64);
    OSStatus latency_result = AudioUnitGetProperty(*voice_unit,
                                                   kAudioUnitProperty_Latency,
                                                   kAudioUnitScope_Global,
                                                   0, &f64, &size);
    if (!isPlayout)
    {
        _recording_AudioUnitProperty_Latency = (0 == latency_result) ? f64 : 0;
    }
    else
    {
        _playout_AudioUnitProperty_Latency = (0 == latency_result) ? f64 : 0;
    }
    
    // Initialize the Voice-Processing I/O unit instance.
    result = AudioUnitInitialize(*voice_unit);

    // This patch is picked up from WebRTC audio implementation and
    // is kind of a workaround. We encountered AudioUnitInitialize
    // failure in iOS 13 with Callkit while switching calls.
    int failed_initalize_attempts = 0;
    int kMaxInitalizeAttempts = 5;
    while (result != noErr) {
      ++failed_initalize_attempts;
      if (failed_initalize_attempts == kMaxInitalizeAttempts) {
        // Max number of initialization attempts exceeded, hence abort.
        return false;
      }
      [NSThread sleepForTimeInterval:0.1f];
      result = AudioUnitInitialize(*voice_unit);
    }

    if (CheckError(result, @"setupAudioUnit.AudioUnitInitialize")) {
        return NO;
    }

    return YES;
}

- (BOOL)setPlayOutRenderCallback:(AudioUnit)unit
{
    AURenderCallbackStruct render_callback;
    render_callback.inputProc = playout_cb;;
    render_callback.inputProcRefCon = (__bridge void *)(self);
    OSStatus result = AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback,
                                           kAudioUnitScope_Input, kOutputBus, &render_callback,
                                           sizeof(render_callback));
    return (result == 0);
}

@end
