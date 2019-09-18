//
//  OTBroadcastExtAudioDeviceIOS.m
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import "OTBroadcastExtAudioDevice.h"
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
#define kSampleRate 44100
#endif

#define OT_ENABLE_AUDIO_DEBUG 1

#if OT_ENABLE_AUDIO_DEBUG
#define OT_AUDIO_DEBUG(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#define OT_AUDIO_DEBUG(fmt, ...)
#endif

static double kPreferredIOBufferDuration = 0.01;

static mach_timebase_info_data_t info;

static OSStatus playout_cb(void *ref_con,
                           AudioUnitRenderActionFlags *action_flags,
                           const AudioTimeStamp *time_stamp,
                           UInt32 bus_num,
                           UInt32 num_frames,
                           AudioBufferList *data);

@interface OTBroadcastExtAudioDevice ()
- (BOOL) setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout;
- (void) setupListenerBlocks;
@end

@implementation OTBroadcastExtAudioDevice
{
    OTAudioFormat *_audioFormat;
    
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
    
@public
    id _audioBus;
    
    AudioBufferList *buffer_list;
    uint32_t buffer_num_frames;
    uint32_t buffer_size;
    uint32_t _playoutDelay;
    uint32_t _playoutDelayMeasurementCounter;
    Float64 _playout_AudioUnitProperty_Latency;
    Float64 _recording_AudioUnitProperty_Latency;
    
    uint32_t _recordingDelay;
    uint32_t _recordingDelayMeasurementCounter;
    uint32_t _recordingDelayHWAndOS;
}

#pragma mark - OTAudioDeviceImplementation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioFormat = [[OTAudioFormat alloc] init];
        _audioFormat.sampleRate = kSampleRate;
        _audioFormat.numChannels = 1;
        _safetyQueue = dispatch_queue_create("ot-audio-driver",
                                             DISPATCH_QUEUE_SERIAL);
        _restartRetryCount = 0;
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
    return playout_initialized;
}

- (BOOL)captureIsAvailable
{
    return YES;
}

// Audio Unit lifecycle is bound to start/stop cycles, so we don't have much
// to do here.
- (BOOL)initializeCapture
{
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
    return recording_initialized;
}

- (BOOL)startRendering
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"startRendering %d", playing);
        
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
        
        return playing;
    }
}

- (BOOL)stopRendering
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"stopRendering %d", playing);
        
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
        OT_AUDIO_DEBUG(@"startCapture %d", recording);
        // We don't have to do anything since SampleHandler directly provides the audio samples
        recording = YES;
        return YES;
    }
}

- (BOOL)stopCapture
{
    @synchronized(self) {
        OT_AUDIO_DEBUG(@"stopCapture %d", recording);
        
        recording = NO;
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

- (void) teardownAudio
{
    [self disposePlayoutUnit];
    [self freeupAudioBuffers];
    
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    [mySession setCategory:_previousAVAudioSessionCategory error:nil];
    [mySession setMode:avAudioSessionMode error:nil];
    [mySession setPreferredSampleRate: avAudioSessionPreffSampleRate
                                error: nil];
    [mySession setPreferredInputNumberOfChannels:avAudioSessionChannels
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
    if(isAudioSessionSetup)
        return;
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    _previousAVAudioSessionCategory = mySession.category;
    avAudioSessionMode = mySession.mode;
    avAudioSessionPreffSampleRate = mySession.preferredSampleRate;
    avAudioSessionChannels = mySession.inputNumberOfChannels;
    
    [mySession setPreferredSampleRate: kSampleRate error: nil];
    //[mySession setPreferredInputNumberOfChannels:1 error:nil];
    [mySession setPreferredIOBufferDuration:kPreferredIOBufferDuration
                                      error:nil];
    
    NSError *error = nil;
    NSUInteger audioOptions = 0;
    
    audioOptions |= AVAudioSessionCategoryOptionAllowBluetooth ;
    audioOptions |= AVAudioSessionCategoryOptionDefaultToSpeaker;
    audioOptions |= AVAudioSessionCategoryOptionMixWithOthers;
    
    [mySession setCategory:AVAudioSessionCategoryPlayback
               withOptions:audioOptions
                     error:&error];
    
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
    
    isAudioSessionSetup = true;
    
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
                // Reconfigure audio session with highest priority device
                [self configureAudioSessionWithDesiredAudioRoute:
                 AUDIO_DEVICE_BLUETOOTH];
                if(isPlayerInterrupted)
                {
                    isPlayerInterrupted = NO;
                    [self startRendering];
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
    
    @synchronized(self) {
        // We've made it here, there's been a legit route change.
        // Restart the audio units with correct sample rate
        _isResetting = YES;
        
        if (recording)
        {
            [self stopCapture];
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

static void update_recording_delay(OTBroadcastExtAudioDevice* device) {
    
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

static void update_playout_delay(OTBroadcastExtAudioDevice* device) {
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

-(void)writeAudioSamples:(CMSampleBufferRef)sampleBuffer
{
    if (recording) {
        
        int32_t num_frames = (int32_t)CMSampleBufferGetNumSamples(sampleBuffer);
        if (!buffer_list || CMSampleBufferGetNumSamples(sampleBuffer) > buffer_num_frames)
        {
            
            if (buffer_list) {
                free(buffer_list->mBuffers[0].mData);
                free(buffer_list);
            }
            
            buffer_list =
            (AudioBufferList*)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer));
            buffer_list->mNumberBuffers = 1;
            buffer_list->mBuffers[0].mNumberChannels = 1;
            
            buffer_list->mBuffers[0].mDataByteSize = num_frames*sizeof(UInt16);
            buffer_list->mBuffers[0].mData = malloc(num_frames*sizeof(UInt16));
            
            buffer_num_frames = num_frames;
            buffer_size = buffer_list->mBuffers[0].mDataByteSize;
        }
        CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer,0 , num_frames, buffer_list);
        [_audioBus writeCaptureData:buffer_list->mBuffers[0].mData
                    numberOfSamples:num_frames];
    }
    update_recording_delay(self);
}

static OSStatus playout_cb(void *ref_con,
                           AudioUnitRenderActionFlags *action_flags,
                           const AudioTimeStamp *time_stamp,
                           UInt32 bus_num,
                           UInt32 num_frames,
                           AudioBufferList *buffer_list)
{
    OTBroadcastExtAudioDevice *dev = (__bridge OTBroadcastExtAudioDevice*) ref_con;
    
    if (!dev->playing) { return 0; }
    
    uint32_t count =
    [dev->_audioBus readRenderData:buffer_list->mBuffers[0].mData
                   numberOfSamples:num_frames];
    
    if (count != num_frames) {
        //TODO: Not really an error, but concerning. Network issues?
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
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                        error:&err];
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
    
#if !(TARGET_OS_TV)
    audio_unit_description.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
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
    
    UInt32 enable_output = 1;
    AudioUnitSetProperty(*voice_unit, kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output, kOutputBus, &enable_output,
                         sizeof(enable_output));
    AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input, kOutputBus,
                         &stream_format, sizeof (stream_format));
    // Disable Input on playout
    UInt32 enable_input = 0;
    AudioUnitSetProperty(*voice_unit, kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input, kInputBus, &enable_input,
                         sizeof(enable_input));
    [self setPlayOutRenderCallback:*voice_unit];
    
    Float64 f64 = 0;
    UInt32 size = sizeof(f64);
    OSStatus latency_result = AudioUnitGetProperty(*voice_unit,
                                                   kAudioUnitProperty_Latency,
                                                   kAudioUnitScope_Global,
                                                   0, &f64, &size);
    
    _playout_AudioUnitProperty_Latency = (0 == latency_result) ? f64 : 0;
    
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
