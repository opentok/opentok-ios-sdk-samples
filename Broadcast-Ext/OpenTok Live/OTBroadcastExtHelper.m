//
//  OTBroadcastExtHelper.m
//  OpenTok Live
//
//  Created by Sridhar Bollam on 8/5/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//

#import "OTBroadcastExtHelper.h"
#import "OTBroadcastExtAudioDevice.h"

@interface OTBroadcastExtHelper () <OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate>
@end

@implementation OTBroadcastExtHelper
{
    NSString *_partnerId;
    NSString *_sessionId;
    NSString *_token;
    
    // OT vars
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    OTBroadcastExtAudioDevice* _audioDevice;
    
    id <OTVideoCapture> _videoCapturer;
    
}

-(instancetype)initWithPartnerId:(NSString *)partnerId
                       sessionId:(NSString *)sessionId
                        andToken:(NSString *)token
                   videoCapturer:(id <OTVideoCapture>)videoCapturer
{
    self = [super init];
    if (self) {
        _partnerId = partnerId;
        _sessionId = sessionId;
        _token = token;
        _videoCapturer = videoCapturer;
    }
    return self;
    
}

-(void)showMessage:(NSString *)message
{
    // for now we log to the console.
    NSLog(@"[ERROR] %@",message);
}

-(void)connect
{
    if (_partnerId.length == 0 || _sessionId.length == 0 || _token.length == 0)
    {
        [self showMessage:@"[ERROR] Invalid OpenTok session info."];
        return;
    }
    
    if(_session.sessionConnectionStatus == OTSessionConnectionStatusConnected)
    {
        [self showMessage:@"[ERROR] Session already connected!"];
        return;
    }
    
    if(!_audioDevice)
    {
        _audioDevice =
        [[OTBroadcastExtAudioDevice alloc] init];
        [OTAudioDeviceManager setAudioDevice:_audioDevice];
    }
    
    _session = [[OTSession alloc] initWithApiKey:_partnerId
                                       sessionId:_sessionId
                                        delegate:self];
    
    OTError *error = nil;
    [_session connectWithToken:_token error:&error];
    if (error)
    {
        [self showMessage:[error localizedDescription]];
    }
}

-(void)disconnect
{
    OTError *error = nil;
    [_session disconnect:&error];
    if (error)
    {
        [self showMessage:[error localizedDescription]];
    }
}

- (void)doPublish
{
    OTPublisherSettings *settings = [[OTPublisherSettings alloc] init];
    settings.videoCapture = _videoCapturer;
    
    settings.name = [[UIDevice currentDevice] name];
    _publisher = [[OTPublisher alloc] initWithDelegate:self
                                              settings:settings];
    
    // We need to set publishAudio to false
    // since we don't know the broadcast session is
    // started with audio or without audio. This is mainly for
    // routed sessions as they require audio packets at start
    // when publishAudio is set to true.
    // We set this to true in publisher:streamCreated
    _publisher.publishAudio = false;
    _publisher.videoType = OTPublisherKitVideoTypeScreen;
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showMessage:[error localizedDescription]];
    }
}

- (void)doSubscribe:(OTStream*)stream
{
    OTSubscriber *subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    subscriber.subscribeToVideo = NO; // Nothing to show on the broadcast extension.
    
    OTError *error = nil;
    [_session subscribe:subscriber error:&error];
    if (error)
    {
        [self showMessage:[error localizedDescription]];
    }
}

- (void)cleanupPublisher
{
    _publisher = nil;
}

- (void)cleanupSubscriber
{
    _subscriber = nil;
}

- (void)cleanupSession
{
    _session = nil;
}

- (BOOL)isConnected
{
    return _session.sessionConnectionStatus == OTSessionConnectionStatusConnected;
}

-(void)writeAudioSamples:(CMSampleBufferRef)sampleBuffer
{
    [_audioDevice writeAudioSamples:sampleBuffer];
}

#pragma mark -
#pragma mark === OTSession delegate callbacks ===

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSLog(@"sessionDidDisconnect (%@)", session.sessionId);
    [self cleanupPublisher];
    [self cleanupSubscriber];
    [self cleanupSession];
}

- (void)session:(OTSession*)mySession streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (Id: %@, Name: %@, ConnectionId: %@)", stream.streamId, stream.name, stream.connection.connectionId);
    
    [self doSubscribe:stream];
}

- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (Id: %@, Name: %@, ConnectionId: %@)", stream.streamId, stream.name, stream.connection.connectionId);
    
    if([_subscriber.stream.streamId isEqualToString:stream.streamId])
        [self cleanupSubscriber];
}

- (void)session:(OTSession *)session connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)session:(OTSession *)session connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if([_subscriber.stream.connection.connectionId isEqualToString:connection.connectionId])
        [self cleanupSubscriber];
}

- (void)session:(OTSession*)session didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
    
}

- (void)   session:(OTSession*)session
receivedSignalType:(NSString*)type
    fromConnection:(OTConnection*)connection
        withString:(NSString*)string
{
    NSLog(@"Received signal %@",string);
}

#pragma mark -
#pragma mark === OTSubscriber delegate callbacks ===

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream: %@ (connectionId: %@, video type: %d)", subscriber.stream.name, subscriber.stream.connection.connectionId, subscriber.stream.videoType);
}

- (void)subscriber:(OTSubscriberKit*)subscriber didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@", subscriber.stream.streamId, error);
}

- (void)subscriberVideoDisabled:(OTSubscriberKit*)subscriber reason:(OTSubscriberVideoEventReason)reason
{
    NSLog(@"subscriberVideoDisabled %@, reason : %d", subscriber, reason);
}

- (void)subscriberVideoEnabled:(OTSubscriberKit*)subscriber reason:(OTSubscriberVideoEventReason)reason
{
    NSLog(@"subscriberVideoEnabled %@, reason : %d", subscriber, reason);
}

#pragma mark -
#pragma mark === OTPublisher delegate callbacks ===

- (void)publisher:(OTPublisherKit *)publisher streamCreated:(OTStream *)stream
{
    // This is safe since ReplayKit doesn't send any audio samples, if mic is disabled.
    _publisher.publishAudio = true;
     NSLog(@"publisher streamCreated: %@", stream);
}

- (void)publisher:(OTPublisherKit*)publisher streamDestroyed:(OTStream *)stream
{
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

@end
