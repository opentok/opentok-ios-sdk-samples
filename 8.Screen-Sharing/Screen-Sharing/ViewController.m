//
//  ViewController.m
//  Screen-Sharing
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import "TBScreenPublisher.h"
#import "TBScreenCapture.h"
#import <OpenTok/OpenTok.h>

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"100";
// Replace with your generated session ID
static NSString* const kSessionId = @"1_MX4xMDB-MTI3LjAuMC4xfjE0MTY4NTI2NDAyNjN-dFlOb2JIaHdMVHpZUEhTOGVSeHN4NHcyfn4";
// Replace with your generated token
static NSString* const kToken = @"T1==cGFydG5lcl9pZD0xMDAmc2RrX3ZlcnNpb249dGJwaHAtdjAuOTEuMjAxMS0wNy0wNSZzaWc9YTIxNGQ5YzJjZTI1YjU0MWYxOWQ0MGY4ODNkYjNlMDFmODFiNTgwYzpzZXNzaW9uX2lkPTFfTVg0eE1EQi1NVEkzTGpBdU1DNHhmakUwTVRZNE5USTJOREF5TmpOLWRGbE9iMkpJYUhkTVZIcFpVRWhUT0dWU2VITjROSGN5Zm40JmNyZWF0ZV90aW1lPTE0MTY4NTI1MjMmcm9sZT1tb2RlcmF0b3Imbm9uY2U9MTQxNjg1MjUyMy42MDgxMjQ3MDA0MjIyJmV4cGlyZV90aW1lPTE0MTk0NDQ1MjM=";

@interface ViewController () <OTSessionDelegate, OTPublisherDelegate>

@end

@interface OTSession()
- (void)setApiRootURL:(NSURL*)aURL;
@end

@implementation ViewController
{
    OTSession* _session;
    TBScreenPublisher* _publisher;
}

@synthesize timeDisplay;

#pragma mark - View lifecycle

dispatch_queue_t  queue;
dispatch_source_t timer;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    queue = dispatch_queue_create("com.firm.app.timer", 0);
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 10ull * NSEC_PER_MSEC, 1ull * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(timer, ^{
        double timestamp = [[NSDate date] timeIntervalSince1970];
        int64_t timeInMilisInt64 = (int64_t)(timestamp*1000);
        
        NSString *mills = [NSString stringWithFormat:@"%lld", timeInMilisInt64];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.timeDisplay setText:mills];
        });
    });
    
    dispatch_resume(timer);
    
    _session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                        delegate:self];
    [_session setApiRootURL:[NSURL URLWithString:@"https://api-rel.opentok.com"]];
    [self doConnect];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
    if (UIInterfaceOrientationPortrait == interfaceOrientation) {
        return YES;
    }
    else {
        return NO;
    }
//    // Return YES for supported orientations
//    if (UIUserInterfaceIdiomPhone == [[UIDevice currentDevice] userInterfaceIdiom]) {
//        return NO;
//    }
//    else {
//        return YES;
//    }
}

#pragma mark - OpenTok methods

- (void)doConnect
{
    OTError *error = nil;
    
    [_session connectWithToken:kToken error:&error];
    if (error) {
        [self showAlert:[error localizedDescription]];
    }
}

- (void)doPublish
{
    _publisher = [[TBScreenPublisher alloc] initWithDelegate:self
                                                        name:[[UIDevice currentDevice] name]];
    
    TBScreenCapture* videoCapture = [[TBScreenCapture alloc] init];
    videoCapture.view = self.view;
    [_publisher setVideoCapture:videoCapture];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error) {
        [self showAlert:[error localizedDescription]];
    }
}

- (void)cleanupPublisher {
    [_publisher.view removeFromSuperview];
    _publisher = nil;
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage = [NSString stringWithFormat:@"Session disconnected: (%@)", session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}


- (void)session:(OTSession*)mySession streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
}

- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
}

- (void) session:(OTSession *)session connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void) session:(OTSession *)session connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
}

- (void) session:(OTSession*)session didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit*)publisher streamDestroyed:(OTStream *)stream
{
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

- (void)showAlert:(NSString *)string
{
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OTError"
                                                        message:string
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] ;
        [alert show];
    });
}

@end
