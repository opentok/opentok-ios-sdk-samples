//
//  ViewController.h
//  Getting Started
//
//  Created by Jeff Swartz on 11/19/14.
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "Config.h"

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate, UIScrollViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *subscriberView;
@property (weak, nonatomic) IBOutlet UIView *publisherView;
@property (weak, nonatomic) IBOutlet UIImageView *archiveIndicatorImg;
@property (weak, nonatomic) IBOutlet UIButton *archiveControlBtn;
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@property (nonatomic) NSString *archiveId;
@property (nonatomic) NSString *apiKey;
@property (nonatomic) NSString *sessionId;
@property (nonatomic) NSString *token;
@end

@implementation ViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self getSessionCredentials];
}

- (void)getSessionCredentials
{
    NSString* urlPath = SAMPLE_SERVER_BASE_URL;
    urlPath = [urlPath stringByAppendingString:@"/session"];
    NSURL *url = [NSURL URLWithString: urlPath];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setHTTPMethod: @"GET"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if (error){
            if (error.code == -1003) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid server base URL" message:@"Please check the SAMPLE_SERVER_BASE_URL constant value in Config.h file." preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
            NSLog(@"Error,%@, URL: %@", [error localizedDescription],urlPath);
        }
        else{
            NSDictionary *roomInfo = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            self->_apiKey = [roomInfo objectForKey:@"apiKey"];
            self->_token = [roomInfo objectForKey:@"token"];
            self->_sessionId = [roomInfo objectForKey:@"sessionId"];
            
            if(!self->_apiKey || !self->_token || !self->_sessionId) {
                NSLog(@"Error invalid response from server, URL: %@",urlPath);
            } else {
                [self doConnect];
            }
        }
    }];
}

#pragma mark - OpenTok methods
- (void)doConnect
{
    // Initialize a new instance of OTSession and begin the connection process.
    self.session = [[OTSession alloc] initWithApiKey:self.apiKey
                                       sessionId:self.sessionId
                                        delegate:self];
    OTError *error = nil;
    [self.session connectWithToken:self.token error:&error];
    if (error)
    {
        NSLog(@"Unable to connect to session (%@)",
              error.localizedDescription);
    }
}

- (void)doPublish
{
    self.publisher = [[OTPublisher alloc]
                  initWithDelegate:self];
    
    OTError *error = nil;
    [self.session publish:self.publisher error:&error];
    if (error)
    {
        NSLog(@"Unable to publish (%@)",
              error.localizedDescription);
    }
    
    [self.publisher.view setFrame:CGRectMake(0, 0, self.publisherView.bounds.size.width,
                                         self.publisherView.bounds.size.height)];
    [self.publisherView addSubview:self.publisher.view];

    if (SAMPLE_SERVER_BASE_URL) {
        self.archiveControlBtn.hidden = NO;
        [self.archiveControlBtn addTarget:self
                               action:@selector(startArchive)
                     forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)cleanupPublisher {
    [self.publisher.view removeFromSuperview];
    self.publisher = nil;
}

- (void)doSubscribe:(OTStream*)stream
{
    self.subscriber = [[OTSubscriber alloc] initWithStream:stream
                                              delegate:self];
    OTError *error = nil;
    [self.session subscribe:self.subscriber error:&error];
    if (error)
    {
        NSLog(@"Unable to publish (%@)",
              error.localizedDescription);
    }
}

- (void)cleanupSubscriber
{
    [self.subscriber.view removeFromSuperview];
    self.subscriber = nil;
}

-(void)startArchive
{
    self.archiveControlBtn.hidden = YES;
    NSString *fullURL = [NSString stringWithFormat:@"%@/archive/start", SAMPLE_SERVER_BASE_URL];
    NSURL *url = [NSURL URLWithString: fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod: @"POST"];
    NSDictionary *dict = @{@"sessionId": self.sessionId};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if (error){
            NSLog(@"Error starting the archive: %@. URL : %@",
                  [error localizedDescription],
                  fullURL);
        }
        else{
            NSLog(@"Web service call to start the archive: %@", fullURL);
        }
    }];
}

-(void)stopArchive
{
    self.archiveControlBtn.hidden = YES;
    NSString *fullURL = [NSString stringWithFormat:@"%@/archive/%@/stop", SAMPLE_SERVER_BASE_URL, self.archiveId];
    NSURL *url = [NSURL URLWithString: fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setHTTPMethod: @"POST"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if (error){
            NSLog(@"Error stopping the archive: %@. URL : %@",
                  [error localizedDescription],fullURL);
        }
        else{
            NSLog(@"Web service call to stop the archive: %@", fullURL);
        }
    }];
}

-(void)loadArchivePlaybackInBrowser
{
    NSString *fullURL = [NSString stringWithFormat:@"%@/archive/%@/view", SAMPLE_SERVER_BASE_URL, self.archiveId];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:fullURL]];
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}

- (void)session:(OTSession*)session
streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    if (nil == self.subscriber)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([self.subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)  session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

- (void)     session:(OTSession*)session
archiveStartedWithId:(NSString *)archiveId
                name:(NSString *)name
{
    NSLog(@"session archiving started with id:%@ name:%@", archiveId, name);
    self.archiveId = archiveId;
    self.archiveIndicatorImg.hidden = NO;
    if (SAMPLE_SERVER_BASE_URL) {
        self.archiveControlBtn.hidden = NO;
        [self.archiveControlBtn setTitle: @"Stop recording" forState:UIControlStateNormal];
        self.archiveControlBtn.hidden = NO;
        [self.archiveControlBtn removeTarget:self
                                  action:NULL
                        forControlEvents:UIControlEventTouchUpInside];
        [self.archiveControlBtn addTarget:self
                               action:@selector(stopArchive)
                     forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)     session:(OTSession*)session
archiveStoppedWithId:(NSString *)archiveId
{
    NSLog(@"session archiving stopped with id:%@", archiveId);
    self.archiveIndicatorImg.hidden = YES;
    if (SAMPLE_SERVER_BASE_URL) {
        self.archiveControlBtn.hidden = NO;
        [self.archiveControlBtn setTitle: @"View recording" forState:UIControlStateNormal];
        [self.archiveControlBtn removeTarget:self
                                  action:NULL
                        forControlEvents:UIControlEventTouchUpInside];
        [self.archiveControlBtn addTarget:self
                               action:@selector(loadArchivePlaybackInBrowser)
                     forControlEvents:UIControlEventTouchUpInside];
    }
}


# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
streamCreated:(OTStream *)stream
{
    NSLog(@"Now publishing.");
}

- (void)publisher:(OTPublisherKit*)publisher
streamDestroyed:(OTStream *)stream
{
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher
didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    [self.subscriber.view setFrame:CGRectMake(0, 0, self.subscriberView.bounds.size.width,
                                          self.subscriberView.bounds.size.height)];
    [self.subscriberView addSubview:self.subscriber.view];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

@end
