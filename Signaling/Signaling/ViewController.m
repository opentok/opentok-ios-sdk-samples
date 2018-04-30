//
//  ViewController.h
//  Getting Started
//
//  Created by Jeff Swartz on 11/19/14.
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "Config.h"

@interface ViewController() <OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate, UITextFieldDelegate, UIScrollViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UIView *videoContainerView;
@property (weak, nonatomic) IBOutlet UIView *subscriberView;
@property (weak, nonatomic) IBOutlet UIView *publisherView;
@property (weak, nonatomic) IBOutlet UIButton *swapCameraBtn;
@property (weak, nonatomic) IBOutlet UITextView *chatReceivedTextView;
@property (weak, nonatomic) IBOutlet UIButton *publisherAudioBtn;
@property (weak, nonatomic) IBOutlet UIButton *subscriberAudioBtn;
@property (weak, nonatomic) IBOutlet UITextField *chatInputTextField;

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

    self.chatInputTextField.delegate = self;

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

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
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

    
    self.publisherAudioBtn.hidden = NO;
    [self.publisherAudioBtn addTarget:self
                          action:@selector(togglePublisherMic)
                forControlEvents:UIControlEventTouchUpInside];
    
    self.swapCameraBtn.hidden = NO;
    [self.swapCameraBtn addTarget:self
               action:@selector(swapCamera)
     forControlEvents:UIControlEventTouchUpInside];
}


-(void)togglePublisherMic
{
    self.publisher.publishAudio = !self.publisher.publishAudio;
    UIImage *buttonImage;
    if (self.publisher.publishAudio) {
        buttonImage = [UIImage imageNamed: @"mic-24.png"];
    } else {
        buttonImage = [UIImage imageNamed: @"mic_muted-24.png"];
    }
    [self.publisherAudioBtn setImage:buttonImage forState:UIControlStateNormal];
}

-(void)toggleSubscriberAudio
{
    self.subscriber.subscribeToAudio = !self.subscriber.subscribeToAudio;
    UIImage *buttonImage;
    if (self.subscriber.subscribeToAudio) {
        buttonImage = [UIImage imageNamed: @"Subscriber-Speaker-35.png"];
    } else {
        buttonImage = [UIImage imageNamed: @"Subscriber-Speaker-Mute-35.png"];
    }
    [self.subscriberAudioBtn setImage:buttonImage forState:UIControlStateNormal];
}

-(void)swapCamera
{
    if (self.publisher.cameraPosition == AVCaptureDevicePositionFront) {
        self.publisher.cameraPosition = AVCaptureDevicePositionBack;
    } else {
        self.publisher.cameraPosition = AVCaptureDevicePositionFront;
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

- (void) sendChatMessage
{
    OTError* error = nil;
    [self.session signalWithType:@"chat" string:self.chatInputTextField.text connection:nil error:&error];
    if (error) {
        NSLog(@"Signal error: %@", error);
    } else {
        NSLog(@"Signal sent: %@", self.chatInputTextField.text);
    }
    self.chatInputTextField.text = @"";
}

- (void)logSignalString:(NSString*)string fromSelf:(Boolean)fromSelf {
    unsigned long prevLength = self.chatReceivedTextView.text.length - 1;
    [self.chatReceivedTextView insertText:string];
    [self.chatReceivedTextView insertText:@"\n"];
    
    if (fromSelf) {
        NSDictionary* formatDict = @{NSForegroundColorAttributeName: [UIColor blueColor]};
        NSRange textRange = NSMakeRange(prevLength + 1, string.length);
        [self.chatReceivedTextView.textStorage setAttributes:formatDict range:textRange];
    }
    [self.chatReceivedTextView setContentOffset:self.chatReceivedTextView.contentOffset animated:NO];
    [self.chatReceivedTextView scrollRangeToVisible:NSMakeRange([self.chatReceivedTextView.text length], 0)];
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

- (void)session:(OTSession*)session receivedSignalType:(NSString*)type fromConnection:(OTConnection*)connection withString:(NSString*)string {
    NSLog(@"Received signal %@", string);
    Boolean fromSelf = NO;
    if ([connection.connectionId isEqualToString:session.connection.connectionId]) {
        fromSelf = YES;
    }
    [self logSignalString:string fromSelf:fromSelf];
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
    
    self.subscriberAudioBtn.hidden = NO;
    [self.subscriberAudioBtn addTarget:self
                           action:@selector(toggleSubscriberAudio)
                 forControlEvents:UIControlEventTouchUpInside];

}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - UITextFieldDelegate callbacks

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    self.chatInputTextField.text = @"";
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendChatMessage];
    [self.view endEditing:YES];
    return YES;
}

@end
