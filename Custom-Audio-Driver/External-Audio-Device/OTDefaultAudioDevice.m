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

#define OT_ENABLE_AUDIO_DEBUG 0

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

@interface OTDefaultAudioDevice ()
- (BOOL) setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout;
- (void) setupListenerBlocks;
@end

#define OT_AUDIO_RESTART_ATTEMPTS 3
#define OT_AUDIO_RESTART_DELAY_SECONDS 1.0f

@implementation OTDefaultAudioDevice
{
    OTAudioFormat *_audioFormat;
    
    AudioUnit recording_voice_unit;
    AudioUnit playout_voice_unit;
    
    BOOL _playbackRequested;
    BOOL _playing;
    BOOL _recordingRequested;
    BOOL _recording;
    
    NSString* _previousAVAudioSessionCategory;
    NSString* avAudioSessionMode;
    double avAudioSessionPreffSampleRate;
    NSInteger avAudioSessionChannels;
    BOOL isAudioSessionSetup;
    BOOL areListenerBlocksSetup;
    
    /* synchronize all access to the audio subsystem */
    dispatch_queue_t _safetyQueue;
    
    BOOL _headsetDeviceAvailable;
    BOOL _bluetoothDeviceAvailable;
    
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
    
    uint32_t _preferredAudioComponentSubtype;
}

@synthesize preferredAudioComponentSubtype = _preferredAudioComponentSubtype;

#pragma mark - OTAudioDeviceImplementation

+ (instancetype)sharedInstance {
    static OTDefaultAudioDevice* _sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[OTDefaultAudioDevice alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioFormat = [[OTAudioFormat alloc] init];
        _audioFormat.sampleRate = kSampleRate;
        _audioFormat.numChannels = 1;
        _safetyQueue = dispatch_queue_create("ot-audio-driver",
                                             DISPATCH_QUEUE_SERIAL);
        _preferredAudioComponentSubtype = 0;
    }
    return self;
}

- (BOOL)setAudioBus:(id<OTAudioBus>)audioBus
{
    _audioBus = audioBus;
    _audioFormat = [[OTAudioFormat alloc] init];
    _audioFormat.sampleRate = kSampleRate;
    _audioFormat.numChannels = 1;
    
    return YES;
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
    if (_playing) {
        return NO;
    }
    return YES;
}

- (BOOL)renderingIsInitialized
{
    return YES;
}

- (BOOL)captureIsAvailable
{
    return YES;
}

// Audio Unit lifecycle is bound to start/stop cycles, so we don't have much
// to do here.
- (BOOL)initializeCapture
{
    if (_recording) {
        return NO;
    }
    return YES;
}

- (BOOL)captureIsInitialized
{
    return YES;
}

- (BOOL)startRendering
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"startRendering %d", _playing);
        
        if (_playing) {
            return YES;
        }
        
        // Initialize only when playout voice unit is already teardown
        if(playout_voice_unit == NULL)
        {
            _playing = [self setupAudioUnit:&playout_voice_unit playout:YES];
            if (!_playing) {
                return NO;
            }
        }
        
        OSStatus result = AudioOutputUnitStart(playout_voice_unit);
        if (CheckError(result, @"startRendering.AudioOutputUnitStart")) {
            _playing = NO;
        }
        
        return _playing;
    }
}

- (BOOL)stopRendering
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"stopRendering %d", _playing);
        
        if (!_playing) {
            return YES;
        }
        
        _playing = NO;
        
        OSStatus result = AudioOutputUnitStop(playout_voice_unit);
        if (CheckError(result, @"stopRendering.AudioOutputUnitStop")) {
            return NO;
        }
        
        // publisher is already closed
        if (!_recording && !_recordingRequested)
        {
            OT_AUDIO_DEBUG(@"teardownAudio from stopRendering");
            [self teardownAudio];
        }
        
        return YES;
    }
}

- (BOOL)isRendering
{
    return _playing;
}

- (BOOL)startCapture
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"startCapture %d", _recording);
        
        if (_recording) {
            return YES;
        }
        
        _recording = YES;
        // Initialize only when recording voice unit is already teardown
        if(recording_voice_unit == NULL)
        {
            _recording = [self setupAudioUnit:&recording_voice_unit playout:NO];
            
            if (!_recording) {
                return NO;
            }
        }

        OSStatus result = AudioOutputUnitStart(recording_voice_unit);
        if (CheckError(result, @"startCapture.AudioOutputUnitStart")) {
            _recording = NO;
        }
        
        return _recording;
    }
}

- (BOOL)stopCapture
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"stopCapture %d", _recording);
        
        if (!_recording) {
            return YES;
        }
        
        _recording = NO;
        
        OSStatus result = AudioOutputUnitStop(recording_voice_unit);
        
        if (CheckError(result, @"stopCapture.AudioOutputUnitStop")) {
            return NO;
        }
        
        [self freeupAudioBuffers];
        
        // teardown if system is not in use
        if (!_recording && !_recordingRequested)
        {
            OT_AUDIO_DEBUG(@"teardownAudio from stopCapture");
            [self teardownAudio];
        }
        
        return YES;
    }
}

- (BOOL)isCapturing
{
    return _recording;
}

- (uint16_t)estimatedRenderDelay
{
    return _playoutDelay;
}

- (uint16_t)estimatedCaptureDelay
{
    return _recordingDelay;
}

#pragma mark - Additional Public Interface (Utility)

- (void)restartAudio {
    dispatch_async(_safetyQueue, ^() {
        [self doRestartAudio:OT_AUDIO_RESTART_ATTEMPTS];
    });
}

- (void)doRestartAudio:(int)retries {
    if (retries <= 0) {
        OT_AUDIO_DEBUG(@"Could not restart audio. Giving up.");
        return;
    } else {
        OT_AUDIO_DEBUG(@"Restarting audio with record=%d playback=%d retry=%d",
                       _recordingRequested, _playbackRequested, retries);
    }
    
    BOOL success = YES;
    
    if (_recordingRequested)
    {
        success &= [self stopCapture];
        [self disposeRecordUnit];
        success &= [self startCapture];
    }
    
    if (_playbackRequested)
    {
        success &= [self stopRendering];
        [self disposePlayoutUnit];
        success &= [self startRendering];
    }
    
    if (success) {
        OT_AUDIO_DEBUG(@"Restart audio success");
        _recordingRequested = NO;
        _playbackRequested = NO;
    } else {
        --retries;
        OT_AUDIO_DEBUG(@"Could not restart audio. Will retry %d times.",
                       retries);
        dispatch_after
        (dispatch_time(DISPATCH_TIME_NOW,
                       (int64_t)(OT_AUDIO_RESTART_DELAY_SECONDS *
                                 NSEC_PER_SEC)),
         _safetyQueue,
         ^(){
             [self doRestartAudio:retries];
         });
    }
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
    [mySession setPreferredInputNumberOfChannels:avAudioSessionChannels
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
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    _previousAVAudioSessionCategory = mySession.category;
    avAudioSessionMode = mySession.mode;
    avAudioSessionPreffSampleRate = mySession.preferredSampleRate;
    avAudioSessionChannels = mySession.inputNumberOfChannels;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        [mySession setMode:AVAudioSessionModeVideoChat error:nil];
    }
    else {
        [mySession setMode:AVAudioSessionModeVoiceChat error:nil];
    }
    
    [mySession setPreferredSampleRate: kSampleRate error: nil];
    [mySession setPreferredInputNumberOfChannels:1 error:nil];
    [mySession setPreferredIOBufferDuration:kPreferredIOBufferDuration
                                      error:nil];
    
    NSError *error = nil;
    NSUInteger audioOptions = AVAudioSessionCategoryOptionMixWithOthers;
#if !(TARGET_OS_TV)
    audioOptions |= AVAudioSessionCategoryOptionAllowBluetooth ;
    audioOptions |= AVAudioSessionCategoryOptionDefaultToSpeaker;
    [mySession setCategory:AVAudioSessionCategoryPlayAndRecord
               withOptions:audioOptions
                     error:&error];
#else
    [mySession setCategory:AVAudioSessionCategoryPlayback
               withOptions:audioOptions
                     error:&error];
#endif
    
    if (error)
        OT_AUDIO_DEBUG(@"Audiosession setCategory %@",error);
    
    error = nil;
    
    [self setupListenerBlocks];
    [mySession setActive:YES error:&error];
    
    if (error)
        OT_AUDIO_DEBUG(@"Audiosession setActive %@",error);

}

- (void)setBluetoothAsPrefferedInputDevice
{
    // Apple's Bug(???) : Audio Interruption Ended notification won't be called
    // for bluetooth devices if we dont set preffered input as bluetooth.
    // Should work for non bluetooth routes/ports too. This makes both input
    // and output to bluetooth device if available.
    NSArray* bluetoothRoutes = @[AVAudioSessionPortBluetoothA2DP,
                                 AVAudioSessionPortBluetoothLE,
                                 AVAudioSessionPortBluetoothHFP];
    NSArray* routes = [[AVAudioSession sharedInstance] availableInputs];
    for (AVAudioSessionPortDescription* route in routes)
    {
        if ([bluetoothRoutes containsObject:route.portType])
        {
            [[AVAudioSession sharedInstance] setPreferredInput:route
                                                         error:nil];
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
                _recordingRequested = _recording;
                _playbackRequested = _playing;
                if (_recording)
                {
                    [self stopCapture];
                }
                if (_playing)
                {
                    [self stopRendering];
                }
            }
                break;
                
            case AVAudioSessionInterruptionTypeEnded:
            {
                OT_AUDIO_DEBUG(@"AVAudioSessionInterruptionTypeEnded");
                // Reconfigure audio session with highest priority device
                [self configureAudioSessionWithDesiredAudioRoute:
                 AUDIO_DEVICE_BLUETOOTH];
                [self restartAudio];
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
    // process events we caused internally.
    if (AVAudioSessionRouteChangeReasonRouteConfigurationChange ==
        routeChangeReason)
    {
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
    
    // We've made it here, there's been a legit route change.
    // Restart the audio units with correct sample rate
    _recordingRequested = _recording;
    _playbackRequested = _playing;
    [self restartAudio];
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

static OSStatus recording_cb(void *ref_con,
                             AudioUnitRenderActionFlags *action_flags,
                             const AudioTimeStamp *time_stamp,
                             UInt32 bus_num,
                             UInt32 num_frames,
                             AudioBufferList *data)
{
    
    OTDefaultAudioDevice *dev = (__bridge OTDefaultAudioDevice*) ref_con;
    
    if (!dev->buffer_list || num_frames > dev->buffer_num_frames)
    {
        if (dev->buffer_list) {
            free(dev->buffer_list->mBuffers[0].mData);
            free(dev->buffer_list);
        }
        
        dev->buffer_list =
        (AudioBufferList*)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer));
        dev->buffer_list->mNumberBuffers = 1;
        dev->buffer_list->mBuffers[0].mNumberChannels = 1;
        
        dev->buffer_list->mBuffers[0].mDataByteSize = num_frames*sizeof(UInt16);
        dev->buffer_list->mBuffers[0].mData = malloc(num_frames*sizeof(UInt16));
        
        dev->buffer_num_frames = num_frames;
        dev->buffer_size = dev->buffer_list->mBuffers[0].mDataByteSize;
    }
    
    OSStatus status;
    
    uint64_t time = time_stamp->mHostTime;
    /* Convert to nanoseconds */
    time *= info.numer;
    time /= info.denom;
    
    status = AudioUnitRender(dev->recording_voice_unit,
                             action_flags,
                             time_stamp,
                             1,
                             num_frames,
                             dev->buffer_list);
    
    if (status != noErr) {
        CheckError(status, @"AudioUnitRender");
    }
    
    if (dev->_recording) {
        
        // Some sample code to generate a sine wave instead of use the mic
        //        static double startingFrameCount = 0;
        //        double j = startingFrameCount;
        //        double cycleLength = kSampleRate. / 880.0;
        //        int frame = 0;
        //        for (frame = 0; frame < num_frames; ++frame)
        //        {
        //            int16_t* data = (int16_t*)dev->buffer_list->mBuffers[0].mData;
        //            Float32 sample = (Float32)sin (2 * M_PI * (j / cycleLength));
        //            (data)[frame] = (sample * 32767.0f);
        //            j += 1.0;
        //            if (j > cycleLength)
        //                j -= cycleLength;
        //        }
        //        startingFrameCount = j;
        [dev->_audioBus writeCaptureData:dev->buffer_list->mBuffers[0].mData
                         numberOfSamples:num_frames];
    }
    // some ocassions, AudioUnitRender only renders part of the buffer and then next
    // call to the AudioUnitRender fails with smaller buffer.
    if (dev->buffer_size != dev->buffer_list->mBuffers[0].mDataByteSize)
        dev->buffer_list->mBuffers[0].mDataByteSize = dev->buffer_size;
    
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
    
    if (!dev->_playing) {
        return 0;
    }
    
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
        isAudioSessionSetup = YES;
    }
    
    UInt32 bytesPerSample = sizeof(SInt16);
    stream_format.mFormatID    = kAudioFormatLinearPCM;
    stream_format.mFormatFlags =
    kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    stream_format.mBytesPerPacket  = bytesPerSample;
    stream_format.mFramesPerPacket = 1;
    stream_format.mBytesPerFrame   = bytesPerSample;
    stream_format.mChannelsPerFrame= 1;
    stream_format.mBitsPerChannel  = 8 * bytesPerSample;
    stream_format.mSampleRate = (Float64) kSampleRate;
    
    AudioComponentDescription audio_unit_description;
    audio_unit_description.componentType = kAudioUnitType_Output;
    if (_preferredAudioComponentSubtype) {
        audio_unit_description.componentSubType =
        _preferredAudioComponentSubtype;
    } else {
#if !(TARGET_OS_TV)
        audio_unit_description.componentSubType =
        kAudioUnitSubType_VoiceProcessingIO;
#else
        audio_unit_description.componentSubType =
        kAudioUnitSubType_RemoteIO;
#endif
    }
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
        UInt32 enable_input = 1;
        AudioUnitSetProperty(*voice_unit, kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input, kInputBus, &enable_input,
                             sizeof(enable_input));
        AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output, kInputBus,
                             &stream_format, sizeof (stream_format));
        AURenderCallbackStruct input_callback;
        input_callback.inputProc = recording_cb;
        input_callback.inputProcRefCon = (__bridge void *)(self);
        
        AudioUnitSetProperty(*voice_unit,
                             kAudioOutputUnitProperty_SetInputCallback,
                             kAudioUnitScope_Global, kInputBus, &input_callback,
                             sizeof(input_callback));
        UInt32 flag = 0;
        AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_ShouldAllocateBuffer,
                             kAudioUnitScope_Output, kInputBus, &flag,
                             sizeof(flag));
        
    } else
    {
        UInt32 enable_output = 1;
        AudioUnitSetProperty(*voice_unit, kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Output, kOutputBus, &enable_output,
                             sizeof(enable_output));
        AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, kOutputBus,
                             &stream_format, sizeof (stream_format));
        [self setPlayOutRenderCallback:*voice_unit];
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
    if (CheckError(result, @"setupAudioUnit.AudioUnitInitialize")) {
        return NO;
    }
    
    [self setBluetoothAsPrefferedInputDevice];
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
