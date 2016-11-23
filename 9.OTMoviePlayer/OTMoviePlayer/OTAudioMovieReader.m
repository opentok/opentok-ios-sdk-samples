//
//  MyAudioDevice.m
//  OTAudioMovieReader
//
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import "OTAudioMovieReader.h"
#import "TPCircularBuffer.h"
#import "TPCircularBuffer+AudioBufferList.h"
#include <mach/mach.h>
#include <mach/mach_time.h>

#define kMixerInputBusCount 2
#define kOutputBus 0
#define kInputBus 1
#define kAudioBufferSize 65535 * 32
#define kSampleRate 32000.0

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

@interface OTAudioMovieReader ()
- (BOOL) setupAudio;
- (void) setupListenerBlocks;
- (BOOL) startRenderingAndCapture;
- (BOOL) stopRenderingAndCapture;
- (void) releaseAsset;
@end

@implementation OTAudioMovieReader
{
    OTAudioFormat *_audioFormat;
    id _interuptObserver;
    id _routeObserver;
    
    BOOL rendering;
    BOOL rendering_initialized;
    BOOL capturing;
    BOOL capturing_initialized;
    BOOL interrupted_rendering;
    BOOL _auGraphStated;
    
@public
    
    id<OTAudioBus> _audioBus;
    AudioBufferList *buffer_list;
    AudioStreamBasicDescription	stream_format;
    AUGraph au_graph;
    AudioUnit mixer_unit;
    AudioUnit voice_unit;
    uint32_t _capturingDelay;
    uint32_t _renderingDelay;
    uint32_t _renderingDelayMeasurementCounter;
    uint32_t _capturingDelayHWAndOS;
    uint32_t _capturingDelayMeasurementCounter;
    
    AVAssetReader* audioAssetReader;
    AVAssetReaderOutput *audioReaderOutput;
    TPCircularBuffer circularBuffer;
    uint64_t audioSampleTime;
    
    BOOL asset_read_complete;
}

@synthesize listener;

-(void)dealloc
{
    [self releaseAsset];
    if (buffer_list) {
        free(buffer_list);
    }
    [super dealloc];
}

- (void) releaseAsset
{
    [audioAssetReader release];
    [audioReaderOutput release];
    TPCircularBufferCleanup(&circularBuffer);
}

- (void) loadAsset:(AVURLAsset*) movieAsset
{
    if (NULL != &circularBuffer) {
        [self releaseAsset];
    }
    
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:kSampleRate], AVSampleRateKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    @1, AVNumberOfChannelsKey,
                                    nil];
    NSError *assetError = nil;
    audioAssetReader = [[AVAssetReader alloc] initWithAsset:movieAsset
                                                      error:&assetError];
    if (assetError) {
        NSLog (@"error: %@", assetError);
        return;
    }
    
    AVAssetTrack* track = [[movieAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    audioReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track
                                                         outputSettings:outputSettings];
    
    if (! [audioAssetReader canAddOutput: audioReaderOutput]) {
        NSLog (@"can't add reader output... die!");
        return;
    }
    
    // add output reader to reader
    [audioAssetReader addOutput: audioReaderOutput];
    
    if (! [audioAssetReader startReading]) {
        NSLog(@"Unable to start reading!");
        return;
    }
    
    // Init circular buffer
    // This should go into init. This is a memory leak if we load more assets
    TPCircularBufferInit(&circularBuffer, kAudioBufferSize);
    
    audioSampleTime = 0;
    
    asset_read_complete = NO;
    load_audio_samples(self);
}

#pragma mark - Audio Imp.

- (BOOL)setAudioBus:(id<OTAudioBus>)audioBus
{
    _audioBus = audioBus;
    _audioFormat = [[OTAudioFormat alloc] init];
    _audioFormat.sampleRate = kSampleRate;
    _audioFormat.numChannels = 1;
    return [self setupAudio];
}

- (OTAudioFormat*) captureFormat
{
    return _audioFormat;
}

- (OTAudioFormat*) renderFormat
{
    return _audioFormat;
}

- (BOOL)renderingIsAvailable
{
    return YES;
}

- (BOOL)initializeRendering
{
    if (rendering) {
        return NO;
    }
    
    if (rendering_initialized) {
        return YES;
    }
    
    rendering_initialized = true;
    return YES;
}

- (BOOL)renderingIsInitialized
{
    return rendering_initialized;
}

- (BOOL)capturingIsAvailable
{
    return YES;
}

- (BOOL)initializeCapture
{
    if (capturing) {
        return NO;
    }
    
    if (capturing_initialized) {
        return YES;
    }
    
    capturing_initialized = true;
    return YES;
}

- (BOOL)captureIsInitialized
{
    return capturing_initialized;
}

- (BOOL)startRendering
{
    if (!rendering_initialized) {
        return NO;
    }
    
    if (rendering) {
        return YES;
    }
    
    rendering = [self startRenderingAndCapture];
    return rendering;
}

- (BOOL)stopRendering
{
    BOOL ret = [self stopRenderingAndCapture];
    rendering = NO;
    rendering_initialized = NO;
    return ret;
}

- (BOOL)isRendering
{
    return rendering;
}

- (BOOL)startCapture
{
    if (!capturing_initialized) {
        return NO;
    }
    
    if (capturing) {
        return YES;
    }
    
    capturing = [self startRenderingAndCapture];
    return capturing;
}

- (BOOL)stopCapture
{
    BOOL ret = [self stopRenderingAndCapture];
    capturing = NO;
    return ret;
}

- (BOOL)isCapturing
{
    return capturing;
}

- (uint16_t)estimatedRenderDelay
{
    return _renderingDelay;
}

- (uint16_t)estimatedCaptureDelay
{
    return _capturingDelay;
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

- (BOOL) setupAudio
{
    
    NSUInteger options = 0;
    OSStatus result = noErr;
    mach_timebase_info(&info);
    
    //AVAudioSessionCategoryOptionMixWithOthers;
    //AVAudioSessionCategoryOptionAllowBluetooth |
    //AVAudioSessionCategoryOptionDefaultToSpeaker;
    
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    [mySession setPreferredSampleRate: kSampleRate error: nil];
    [mySession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [mySession setMode:AVAudioSessionModeVideoChat error:nil];
    [self setupListenerBlocks];
    [mySession setActive:YES withOptions:options error:nil];
    //demonstrateInputSelection();
    
    //    [mySession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    size_t bytesPerSample = sizeof (SInt16);	// Sint16
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
    io_dec.componentSubType       = kAudioUnitSubType_RemoteIO;
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
        input_cb.inputProcRefCon = self;
        
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
        
        AudioUnitSetParameter(mixer_unit,
                              kMultiChannelMixerParam_Volume,
                              kAudioUnitScope_Input,
                              bus_num,
                              1.0,
                              0);
    }
    
    AudioUnitParameterValue is_on = 1;
    result = AudioUnitSetParameter(mixer_unit,
                                   kMultiChannelMixerParam_Enable,
                                   kAudioUnitScope_Input,
                                   kMicBus,
                                   is_on,
                                   0);
    if (noErr != result) {
        print_error("AudioUnitSetParameter (enable the mixer unit)",
                    result);
        return NO;
    }
    
    AURenderCallbackStruct output_cb;
    output_cb.inputProc = recording_cb;
    output_cb.inputProcRefCon = self;
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
        print_error("AudioUnitSetProperty (set mixer unit output stream format)",
                    result);
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
    
    return YES;
}

- (void) setupListenerBlocks
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    _interuptObserver =
    [center addObserverForName:AVAudioSessionInterruptionNotification object:nil
                         queue:mainQueue
                    usingBlock:^(NSNotification *note) {
                        NSDictionary *interuptionDict = note.userInfo;
                        NSInteger interuptionType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
                        switch (interuptionType) {
                            case AVAudioSessionInterruptionTypeBegan:
                                [self stopRenderingAndCapture];
                                break;
                                
                            case AVAudioSessionInterruptionTypeEnded:
                                [self startRenderingAndCapture];
                                break;
                                
                            default:
                                NSLog(@"Audio Session Interruption Notification case default.");
                                break;
                        }
                    }];
    
    _routeObserver =
    [center addObserverForName:AVAudioSessionRouteChangeNotification object:nil
                         queue:mainQueue
                    usingBlock:^(NSNotification *note) {
                        NSDictionary *interuptionDict = note.userInfo;
                        NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
                        
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
                    }];
    
}

- (BOOL) startRenderingAndCapture;
{
    if (_auGraphStated) {
        return YES;
    }
    _auGraphStated = YES;
    
    OSStatus result = AUGraphStart(au_graph);
    if (noErr != result) {
        print_error("AUGraphStart", result);
        return NO;
    }
    return YES;
}

- (BOOL) stopRenderingAndCapture
{
    if (!_auGraphStated) {
        return YES;
    }
    _auGraphStated = NO;
    
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
    //check fourcc
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

static void update_recording_delay(OTAudioMovieReader* device) {
    device->_capturingDelayMeasurementCounter++;
    
    if (device->_capturingDelayMeasurementCounter >= 100) {
        // Update HW and OS delay every second, unlikely to change
        
        device->_capturingDelayHWAndOS = 0;
        
        // HW input latency
        Float32 f32 = 0;
        UInt32 size = sizeof(f32);
        OSStatus result =
        AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputLatency,
                                &size,
                                &f32);
        
        if (0 != result) { return; }
        
        device->_capturingDelayHWAndOS += (int)(f32 * 1000000);
        
        // HW buffer duration
        f32 = 0;
        result =
        AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration,
                                &size,
                                &f32);
        if (0 != result) { return ; }
        device->_capturingDelayHWAndOS += (int)(f32 * 1000000);
        
        // AU latency
        Float64 f64 = 0;
        size = sizeof(f64);
        result = AudioUnitGetProperty(device->voice_unit,
                                      kAudioUnitProperty_Latency,
                                      kAudioUnitScope_Global, 0, &f64, &size);
        if (0 != result) { return  ; }
        device->_capturingDelayHWAndOS += (int)(f64 * 1000000);
        
        // To ms
        device->_capturingDelayHWAndOS =
        (device->_capturingDelayHWAndOS - 500) / 1000;
        
        // Reset counter
        device->_capturingDelayMeasurementCounter = 0;
    }
    
    device->_capturingDelay = device->_capturingDelayHWAndOS;
}

static bool load_audio_samples(OTAudioMovieReader* player)
{
    CMSampleBufferRef sample = [player->audioReaderOutput copyNextSampleBuffer];
    size_t sample_size;
    sample_size = CMSampleBufferGetTotalSampleSize(sample);
    
    if (NULL == sample) {
        return false;
    }
    int32_t availableBytes;
    CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
    CMSampleBufferGetSampleTimingInfo(sample, 0, &timingInfo);
    
    AudioBufferList abl;
    CMBlockBufferRef blockBuffer;
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
    
    (void)TPCircularBufferTail(&player->circularBuffer, &availableBytes);
    
    int bytesCopied = TPCircularBufferProduceBytes(&player->circularBuffer, abl.mBuffers[0].mData, sample_size);
    
    CFRelease( sample );
    CFRelease(blockBuffer);
    
    return true;
}

/*
 CoreAudio is sending in 186|185 for the number of samples. Sampling at 16Khz
 a 10ms buffer is 160 samples. WebRTC only works with 10ms of audio data at a
 time. OpenTok's Audio Device Interface implementation handles this by buffering
 any extra data you send it. Because of this synchronization can be tricky.
 (todo)
 */
static OSStatus recording_cb(void *ref_con,
                             AudioUnitRenderActionFlags *action_flags,
                             const AudioTimeStamp *time_stamp,
                             UInt32 bus_num,
                             UInt32 num_frames,
                             AudioBufferList *data)
{
    OTAudioMovieReader *player = (OTAudioMovieReader*) ref_con;
    
    if (!player->buffer_list)
    {
        player->buffer_list =
        (AudioBufferList*) malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer));
        player->buffer_list->mNumberBuffers = 1;
        player->buffer_list->mBuffers[0].mNumberChannels = 1;
        
        player->buffer_list->mBuffers[0].mDataByteSize = num_frames * sizeof(UInt16);
        player->buffer_list->mBuffers[0].mData = malloc(num_frames * sizeof(UInt16));
    }
    
    // Then:
    // Obtain recorded samples
    
    OSStatus status;
    
    uint64_t time = time_stamp->mHostTime;
    /* Convert to nanoseconds */
    time *= info.numer;
    time /= info.denom;
    
    status = AudioUnitRender(player->voice_unit,
                             action_flags,
                             time_stamp,
                             1,
                             num_frames,
                             player->buffer_list);
    
    if (status != noErr) {
        CheckError(status, "AudioUnitRender Failed");
    }
    
    if (player->capturing && NO == player->asset_read_complete) {
        AudioSampleType *outSample = (AudioSampleType *)player->buffer_list->mBuffers[0].mData;
        int32_t availableBytes;
        AudioSampleType *bufferTail = TPCircularBufferTail(&player->circularBuffer, &availableBytes);
        
        memcpy(outSample, bufferTail, MIN(availableBytes, num_frames * 2) );
        TPCircularBufferConsume(&player->circularBuffer, MIN(availableBytes, num_frames * 2) );
        
        [player->_audioBus writeCaptureData:player->buffer_list->mBuffers[0].mData
                            numberOfSamples:num_frames];
        
        double audio_time = player->audioSampleTime / kSampleRate;
        
        [player.listener wroteSamplesAtTime:audio_time];
        
        availableBytes = availableBytes - MIN(availableBytes, num_frames * 2);
        
        if (availableBytes <= num_frames * 2) {
            //dispatch_async(dispatch_get_main_queue(), ^{
            bool loaded_samples = load_audio_samples(player);
            if (false == loaded_samples) {
                player->asset_read_complete = YES;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [player.listener completedMovie];
                });
                return noErr;
            }
        }
        
        player->audioSampleTime += num_frames;
    }
    
    update_recording_delay(player);
    
    return noErr;
}

static void update_playout_delay(OTAudioMovieReader* device) {
    device->_renderingDelayMeasurementCounter++;
    
    if (device->_renderingDelayMeasurementCounter >= 100) {
        // Update HW and OS delay every second, unlikely to change
        
        device->_renderingDelay = 0;
        
        // HW output latency
        Float32 f32 = 0;
        UInt32 size = sizeof(f32);
        OSStatus result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputLatency, &size, &f32);
        
        if (noErr != result) { return; }
        
        device->_renderingDelay += (int)(f32 * 1000000);
        
        // HW buffer duration
        f32 = 0;
        result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration,
                                         &size,
                                         &f32);
        if (noErr != result) { return; }
        
        device->_renderingDelay += (int)(f32 * 1000000);
        
        // AU latency
        Float64 f64 = 0;
        size = sizeof(f64);
        result = AudioUnitGetProperty(device->voice_unit,
                                      kAudioUnitProperty_Latency,
                                      kAudioUnitScope_Global,
                                      0, &f64, &size);
        if (0 != result) { return ; }
        device->_renderingDelay += (int)(f64 * 1000000);
        
        // To ms
        device->_renderingDelay = (device->_renderingDelay - 500) / 1000;
        
        // Reset counter
        device->_renderingDelayMeasurementCounter = 0;
    }
    
    // todo: Add playout buffer? (Only used for 44.1 kHz)
}

static OSStatus playout_cb(void *ref_con,
                           AudioUnitRenderActionFlags *action_flags,
                           const AudioTimeStamp *time_stamp,
                           UInt32 bus_num,
                           UInt32 num_frames,
                           AudioBufferList *buffer_list)
{
    OTAudioMovieReader *dev = (OTAudioMovieReader*) ref_con;
    
    if (!dev->rendering) { return 0; }
    
    //TODO(STEVE): Check the returned number of samples.
    uint32_t count =
    [dev->_audioBus onOutputData:buffer_list->mBuffers[0].mData
                 numberOfSamples:num_frames];
    
    if (count != num_frames) {
        //Not really an error, but conerning. Network?
    }
    
    update_playout_delay(dev);
    
    return 0;
}


@end
