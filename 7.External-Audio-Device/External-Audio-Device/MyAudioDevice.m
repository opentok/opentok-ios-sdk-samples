//
//  MyAudioDevice.m
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import "MyAudioDevice.h"
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


#define kMixerInputBusCount 2
#define kOutputBus 0
#define kInputBus 1

// Simulator *must* run at 44.1 kHz in order to function properly.
#if (TARGET_IPHONE_SIMULATOR)
#define kSampleRate 44100
#else
#define kSampleRate 16000
#endif


static mach_timebase_info_data_t info;

static const UInt32 kMixerBusCount	= kMixerInputBusCount;
static const UInt32 kMicBus			= 0;
static const UInt32 kMixerStreamInStart = 1;

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

static void print_error(const char* error, OSStatus code);


@interface MyAudioDevice ()
- (BOOL) setupAudio;
- (void) setupListenerBlocks;
- (BOOL) startRenderingAndCapturing;
- (BOOL) stopRenderingAndCapturing;
@end

@implementation MyAudioDevice
{
    OTAudioFormat *_audioFormat;
    
    BOOL playing;
    BOOL playout_initialized;
    BOOL recording;
    BOOL recording_initialized;
    BOOL interrupted_playback;
    BOOL auGraphStarted;
    BOOL audioGraphInitialized;
@public
    id _audioBus;
    
    AudioBufferList *buffer_list;
    uint32_t buffer_list_size;
    AudioStreamBasicDescription	stream_format;
    AUGraph au_graph;
    AudioUnit mixer_unit;
    AudioUnit voice_unit;
    uint32_t _recordingDelay;
    uint32_t _playoutDelay;
    uint32_t _playoutDelayMeasurementCounter;
    uint32_t _recordingDelayHWAndOS;
    uint32_t _recordingDelayMeasurementCounter;
}

#pragma mark - OTAudioDeviceImplementation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioFormat = [[OTAudioFormat alloc] init];
        _audioFormat.sampleRate = kSampleRate;
        _audioFormat.numChannels = 1;
    }
    return self;
}

- (BOOL)setAudioBus:(id<OTAudioBus>)audioBus
{
    _audioBus = audioBus;
    _audioFormat = [[OTAudioFormat alloc] init];
    _audioFormat.sampleRate = kSampleRate;
    _audioFormat.numChannels = 1;
    
    return [self setupAudio];
}

- (void)dealloc
{
    if (buffer_list) {
        free(buffer_list);
    }
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
    if (!playout_initialized) {
        return NO;
    }
    
    if (playing) {
        return YES;
    }
    
    playing = [self startRenderingAndCapturing];
	return playing;
}

- (BOOL)stopRendering
{
    BOOL ret = [self stopRenderingAndCapturing];
    playing = NO;
    playout_initialized = NO;
    return ret;
}

- (BOOL)isRendering
{
    return playing;
}

- (BOOL)startCapture
{
    if (!recording_initialized) {
        return NO;
    }
    
    if (recording) {
        return YES;
    }
    
    recording = [self startRenderingAndCapturing];
	return recording;
}

- (BOOL)stopCapture
{
    BOOL ret = [self stopRenderingAndCapturing];
    recording = NO;
    recording_initialized = NO;
    return ret;
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

static void print_error(const char* error, OSStatus code) {
    
    char result_string[5];
    UInt32 result = CFSwapInt32HostToBig (code);
    bcopy (&result, result_string, 4);
    result_string[4] = '\0';
    
    NSLog(@"ERROR[OpenTok]:Audio deivce error: %s error: %4.4s",
          error, (char*) &result_string);
}

- (void) teardownAudio
{
    [self removeObservers];
    [self stopRenderingAndCapturing];
    if (au_graph) {
        DisposeAUGraph(au_graph);
    }
    if (buffer_list) {
        free(buffer_list);
    }
}

- (BOOL) setupAudio
{
    
    NSUInteger options = 0;
    OSStatus result = noErr;
    
    if (YES == audioGraphInitialized) { return YES; }
    
    mach_timebase_info(&info);
    
    //AVAudioSessionCategoryOptionMixWithOthers;
    //AVAudioSessionCategoryOptionAllowBluetooth |
    //AVAudioSessionCategoryOptionDefaultToSpeaker;
    
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        [mySession setMode:AVAudioSessionModeVoiceChat error:nil];
    }
    else {
        [mySession setMode:AVAudioSessionModeVoiceChat error:nil];
    }

    [mySession setPreferredSampleRate: kSampleRate error: nil];
    [mySession setPreferredInputNumberOfChannels:1 error:nil];
    [mySession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    [self setupListenerBlocks];
    [mySession setActive:YES withOptions:options error:nil];
    
    size_t bytesPerSample = sizeof(SInt16);
    stream_format.mFormatID    = kAudioFormatLinearPCM;
    stream_format.mFormatFlags =
    kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    stream_format.mBytesPerPacket  = bytesPerSample;
    stream_format.mFramesPerPacket = 1;
    stream_format.mBytesPerFrame   = bytesPerSample;
    stream_format.mChannelsPerFrame= 1;
    stream_format.mBitsPerChannel  = 8 * bytesPerSample;
    stream_format.mSampleRate = (Float64) _audioFormat.sampleRate;
    
    result = NewAUGraph(&au_graph);
    
    if (noErr != result) {NSLog(@"Error creating AUGraph"); return NO;}
    
    AudioComponentDescription io_dec;
    io_dec.componentType          = kAudioUnitType_Output;
    io_dec.componentSubType       = kAudioUnitSubType_VoiceProcessingIO;
    io_dec.componentManufacturer  = kAudioUnitManufacturer_Apple;
    io_dec.componentFlags         = 0;
    io_dec.componentFlagsMask     = 0;
    
    // Multichannel mixer unit
    AudioComponentDescription mixer_desc;
    mixer_desc.componentType          = kAudioUnitType_Mixer;
    mixer_desc.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
    mixer_desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
    mixer_desc.componentFlags         = 0;
    mixer_desc.componentFlagsMask     = 0;
    
    AUNode   io_node;         // node for I/O unit
    AUNode   mixer_node;      // node for Multichannel Mixer unit
    
    // Add the nodes to the audio processing graph
    result = AUGraphAddNode (au_graph, &io_dec, &io_node);
    
    if (noErr != result) {
        print_error("AUGraphNewNode failed for I/O unit", result);
        return NO;
    }
    
    result = AUGraphAddNode (au_graph, &mixer_desc, &mixer_node);
    
    if (noErr != result) {
        print_error("AUGraphNewNode failed for Mixer unit", result);
        return NO;
    }
    
    result = AUGraphOpen(au_graph);
    
    if (noErr != result) {
        print_error("AUGraphOpen", result);
        return NO;
    }
    
    result = AUGraphNodeInfo(au_graph,
                             mixer_node,
                             NULL,
                             &mixer_unit);
    if (noErr != result) {
        print_error("AUGraphNodeInfo", result);
        return NO;
    }
    
    result = AUGraphNodeInfo(au_graph,
                             io_node,
                             NULL,
                             &voice_unit);
    if (noErr != result) {
        print_error("AUGraphNodeInfo", result);
        return NO;
    }
    
    UInt32 flag = 1;
	result = AudioUnitSetProperty(voice_unit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  kOutputBus,
                                  &flag,
                                  sizeof (flag));
	if (noErr != result) {
        print_error("AudioUnitSetProperty Enable Output", result);
        return NO;
    }
    
    result = AudioUnitSetProperty(voice_unit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &flag,
                                  sizeof (flag));
    if (noErr != result) {
        print_error("AudioUnitSetProperty Enable Input", result);
        return NO;
    }
    
    result = AudioUnitSetProperty(voice_unit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &stream_format,
                                  sizeof (stream_format));
    if (noErr != result) {
        print_error("AudioUnitSetProperty Set Format", result);
        return NO;
    }
    
    result = AudioUnitSetProperty(mixer_unit,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  0,
                                  &kMixerBusCount,
                                  sizeof (kMixerBusCount));
    if (noErr != result) {
        print_error("AudioUnitSetProperty Set Mixer Buss Count", result);
        return NO;
    }
    
    UInt32 maximumFramesPerSlice = 640;
    
    result = AudioUnitSetProperty(mixer_unit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  0,
                                  &maximumFramesPerSlice,
                                  sizeof (maximumFramesPerSlice));
    if (noErr != result) {
        print_error("AudioUnitSetProperty Set Mixer Frames Per Slice", result);
        return NO;
    }
    
    UInt16 bus_num = kMixerStreamInStart;
    for (; bus_num < kMixerBusCount; ++bus_num) {
        
        AURenderCallbackStruct input_cb;
        input_cb.inputProc = &playout_cb;
        input_cb.inputProcRefCon = (__bridge void *)(self);
        
        result = AUGraphSetNodeInputCallback(au_graph,
                                             mixer_node,
                                             bus_num,
                                             &input_cb);
        if (noErr != result) {
            print_error("AUGraphSetNodeInputCallback", result);
            return NO;
        }
        
        result = AudioUnitSetParameter(mixer_unit,
                                       kMultiChannelMixerParam_Enable,
                                       kAudioUnitScope_Input,
                                       bus_num,
                                       1,
                                       0);
    }
    
    AudioUnitParameterValue is_off = 0;
	result = AudioUnitSetParameter(mixer_unit,
                                   kMultiChannelMixerParam_Enable,
                                   kAudioUnitScope_Input,
                                   kMicBus,
                                   is_off,
                                   0);
    if (noErr != result) {
        print_error("AudioUnitSetParameter (enable the mixer unit)",
                    result);
        return NO;
    }
    
    AURenderCallbackStruct output_cb;
	output_cb.inputProc = recording_cb;
    output_cb.inputProcRefCon = (__bridge void *)(self);
	result = AUGraphSetNodeInputCallback (au_graph,
										  mixer_node,
										  kMicBus,
										  &output_cb);
    if (noErr != result) {
        print_error("AudioUnitSetProperty callback setup",
                    result);
        return NO;
    }
    
    UInt16 busNumber = kMixerStreamInStart;
    for (; busNumber < kMixerBusCount; ++busNumber) {
		
        result = AudioUnitSetProperty(mixer_unit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      busNumber,
                                      &stream_format,
                                      sizeof (stream_format));
		if (noErr != result) {
            print_error("AudioUnitSetParameter (enable the mixer unit)",
                        result);
            return NO;
        }
	}
    
    result = AudioUnitSetProperty(mixer_unit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kMicBus,
                                  &stream_format,
                                  sizeof (stream_format));
    if (noErr != result) {
        print_error("AudioUnitSetProperty (set mixer unit input stream format)",
                    result);
        return NO;
    }
    
    Float64 sample_rate = _audioFormat.sampleRate;
    
    result = AudioUnitSetProperty(mixer_unit,
                                  kAudioUnitProperty_SampleRate,
                                  kAudioUnitScope_Output,
                                  0,
                                  &sample_rate,
                                  sizeof (Float64));
    if (noErr != result) {
        print_error("AudioUnitSetProperty (set mixer output stream format)",
                    result);
        return NO;
    }
    
    result = AudioUnitSetProperty(mixer_unit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &stream_format,
                                  sizeof (stream_format));
    if (noErr != result) {
        print_error
        ("AudioUnitSetProperty (set mixer unit output stream format)", result);
        return NO;
    }
    
    result = AUGraphConnectNodeInput(au_graph,
                                     mixer_node,
                                     0,
                                     io_node,
                                     0);
    if (noErr != result) {
        print_error("AUGraphConnectNodeInput", result);
        return NO;
    }
    
#ifdef DEBUG
    CAShow (au_graph);
#endif
    
    [mySession setCategory:AVAudioSessionCategoryPlayAndRecord
               withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    
    result = AUGraphInitialize(au_graph);
    
    if (noErr != result) {
        print_error("AUGraphInitialize", result);
        return NO;
    }
    
    audioGraphInitialized = YES;
    
    return YES;
}

- (void) onInteruptionEvent: (NSNotification *) notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger interuptionType =
    [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    switch (interuptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stopRenderingAndCapturing];
            break;
            
        case AVAudioSessionInterruptionTypeEnded:
            [self configureAudioSessionWithDesiredAudioRoute: AUDIO_DEVICE_BLUETOOTH];
            [self startRenderingAndCapturing];
            break;
            
        default:
            NSLog(@"Audio Session Interruption Notification"
                  " case default.");
            break;
    }
}

- (void) onRouteChangeEvent: (NSNotification *) notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason =
    [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey]
     integerValue];
    
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonUnknown:
            break;
            
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            break;
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            break;
            
        case AVAudioSessionRouteChangeReasonCategoryChange:
            break;
            
        case AVAudioSessionRouteChangeReasonOverride:
            break;
            
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            break;
            
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            break;
            
        default:
            break;
    }
}


- (void) setupListenerBlocks
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self
               selector:@selector(onInteruptionEvent:)
                   name:AVAudioSessionInterruptionNotification object:nil];
    
    [center addObserver:self
               selector:@selector(onRouteChangeEvent:)
                   name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void) removeObservers
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self];
}

- (BOOL) startRenderingAndCapturing
{
    if (auGraphStarted) {
        return YES;
    }
    auGraphStarted = YES;
    OSStatus result = AUGraphStart(au_graph);
    if (noErr != result) {
        print_error("AUGraphStart", result);
        auGraphStarted = NO;
    }
    return auGraphStarted;
}

- (BOOL) stopRenderingAndCapturing
{
    if (!auGraphStarted) {
        return YES;
    }
    
    auGraphStarted = NO;
    
    OSStatus result = AUGraphStop(au_graph);
    
    if (noErr != result) {
        print_error("AUGraphStop", result);
        return NO;
    }
    
    return YES;
}

static void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    
    char errorString[20] = {};
    //check fourcc code
    *(UInt32*)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) &&
        isprint(errorString[3]) && isprint(errorString[4]))
    {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    }
    else {
        //sprintf(errorString, "%d", (int)error);
    }
    //fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
}

static void update_recording_delay(MyAudioDevice* device) {
	device->_recordingDelayMeasurementCounter++;
	
	if (device->_recordingDelayMeasurementCounter >= 100) {
		// Update HW and OS delay every second, unlikely to change
		
		device->_recordingDelayHWAndOS = 0;
		
		// HW input latency
        AVAudioSession *mySession = [AVAudioSession sharedInstance];
        
        // HW output latency
        NSTimeInterval interval = [mySession outputLatency];
        
		device->_recordingDelayHWAndOS += (int)(interval * 1000000);
		
		// HW buffer duration
        interval = [mySession IOBufferDuration];
		device->_recordingDelayHWAndOS += (int)(interval * 1000000);
		
		// AU latency
		Float64 f64 = 0;
		UInt32 size = sizeof(f64);
		OSStatus result = AudioUnitGetProperty(device->voice_unit,
                                               kAudioUnitProperty_Latency,
                                               kAudioUnitScope_Global,
                                               0,
                                               &f64,
                                               &size);
		if (0 != result) { return  ; }
		device->_recordingDelayHWAndOS += (int)(f64 * 1000000);
		
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
    MyAudioDevice *dev = (__bridge MyAudioDevice*) ref_con;
	
	if (!dev->buffer_list || num_frames > dev->buffer_list_size)
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
        
        dev->buffer_list_size = num_frames;
	}
	
    OSStatus status;
	
	uint64_t time = time_stamp->mHostTime;
	/* Convert to nanoseconds */
	time *= info.numer;
	time /= info.denom;
	
	status = AudioUnitRender(dev->voice_unit,
                             action_flags,
                             time_stamp,
                             1,
                             num_frames,
                             dev->buffer_list);
    
	if (status != noErr) {
		CheckError(status, "AudioUnitRender Failed");
	}
	
    if (dev->recording) {
        
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
    
    update_recording_delay(dev);
    
    return noErr;
}

static void update_playout_delay(MyAudioDevice* device) {
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
		
		// AU latency
		Float64 f64 = 0;
		UInt32 size = sizeof(f64);
		OSStatus result = AudioUnitGetProperty(device->voice_unit,
                                               kAudioUnitProperty_Latency,
                                               kAudioUnitScope_Global,
                                               0, &f64, &size);
		if (0 != result) { return ; }
		device->_playoutDelay += (int)(f64 * 1000000);
		
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
    MyAudioDevice *dev = (__bridge MyAudioDevice*) ref_con;
    
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

#pragma mark BlueTooth

- (BOOL)isBluetoothDevice:(NSString*)portType {
    
    return ([portType isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [portType isEqualToString:AVAudioSessionPortBluetoothHFP]);
}


- (BOOL)detectCurrentRoute
{
	// called on startup to initialize the devices that are available...
	NSLog(@"detect current route");
	
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *err;
    
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

    
	// Open a session and see what our default is...
	if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                       withOptions:AVAudioSessionCategoryOptionAllowBluetooth
                             error:&err])
    {
		NSLog(@"unable to set audioSession category: %@", err);
		return NO;
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
		NSLog(@"Current route is Headset");
    }
	
	if (_bluetoothDeviceAvailable) {
		NSLog(@"Current route is Bluetooth");
    }
    
    if(!_bluetoothDeviceAvailable && !_headsetDeviceAvailable) {
        NSLog(@"Current route is device speaker");
    }
	
	return YES;
}

- (BOOL)configureAudioSessionWithDesiredAudioRoute:(NSString *)desiredAudioRoute
{
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *err;
	
    //ios 8.0 complains about Deactivating an audio session that has running
    // I/O. All I/O should be stopped or paused prior to deactivating the audio
    // session. Looks like we can get away by not using the setActive call
    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"7.0")) {
        // close down our current session...
        [audioSession setActive:NO error:nil];
    }
	
    NSUInteger audioOptions = 0;
    if ([AUDIO_DEVICE_BLUETOOTH isEqualToString:desiredAudioRoute]) {
        audioOptions |= AVAudioSessionCategoryOptionAllowBluetooth;
    }
    
	if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                       withOptions:audioOptions
                             error:&err])
    {
		NSLog(@"unable to set audioSession category: %@", err);
		return NO;
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
	}
	
	return YES;
}
@end
