//
//  ViewController.m
//  Hello-World
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"99a8aedf-7988-4395-8864-012683b76f5d";
// Replace with your generated session ID
static NSString* const kSessionId = @"1_MX45OWE4YWVkZi03OTg4LTQzOTUtODg2NC0wMTI2ODNiNzZmNWR-fjE3NDAwODkxOTAyNzB-NGV4cVl3SDI3czllOEMxbllxREZXbGNhfn5-";
// Replace with your generated token
static NSString* const kToken = @"eyJhbGciOiJSUzI1NiIsImprdSI6Imh0dHBzOi8vYW51YmlzLWNlcnRzLWMxLXVzdzIucHJvZC52MS52b25hZ2VuZXR3b3Jrcy5uZXQvandrcyIsImtpZCI6IkNOPVZvbmFnZSAxdmFwaWd3IEludGVybmFsIENBOjoyNTM3NjAxOTQwODY1MTMyNzYyMjQyNTY0MjU2NjUxMTAzNjIzODIiLCJ0eXAiOiJKV1QiLCJ4NXUiOiJodHRwczovL2FudWJpcy1jZXJ0cy1jMS11c3cyLnByb2QudjEudm9uYWdlbmV0d29ya3MubmV0L3YxL2NlcnRzLzhkMWM3Yzg4YjdiMjBlZGYyODkzYjk3YWVkYzAzNmY3In0.eyJwcmluY2lwYWwiOnsiYWNsIjp7InBhdGhzIjp7Ii8qKiI6e319fSwidmlhbUlkIjp7ImVtYWlsIjoicHJhc2hhbnRoaS52ZW51bXVkZGFsYUB2b25hZ2UuY29tIiwiZ2l2ZW5fbmFtZSI6IlByYXNoYW50aGkiLCJmYW1pbHlfbmFtZSI6InZlbnVtdWRkYWxhIiwicGhvbmVfbnVtYmVyIjoiMTg0ODQ1OTU4MjkiLCJwaG9uZV9udW1iZXJfY291bnRyeSI6IlVTIiwib3JnYW5pemF0aW9uX2lkIjoiOTgxNDE0YTktMmZkNC00ZDE4LWIzN2ItNDhlMWQ5Y2EwMDdiIiwiYXV0aGVudGljYXRpb25NZXRob2RzIjpbeyJjb21wbGV0ZWRfYXQiOiIyMDI1LTAyLTIwVDIyOjA1OjU5Ljk4MzM1NDI5M1oiLCJtZXRob2QiOiJpbnRlcm5hbCJ9XSwiaXBSaXNrIjp7InJpc2tfbGV2ZWwiOjB9LCJ0b2tlblR5cGUiOiJ2aWFtIiwiYXVkIjoicG9ydHVudXMuaWRwLnZvbmFnZS5jb20iLCJleHAiOjE3NDAwODk0ODksImp0aSI6ImU3MjVjYTE1LWUxYjMtNGFlZi1iNDNiLTkzZWIyZWMwMTA3MiIsImlhdCI6MTc0MDA4OTE4OSwiaXNzIjoiVklBTS1JQVAiLCJuYmYiOjE3NDAwODkxNzQsInN1YiI6ImY2OGQ3NzFkLWMyOTUtNDU2NS04NDhmLWY4OGM1NWI5N2RhOCJ9fSwiZmVkZXJhdGVkQXNzZXJ0aW9ucyI6eyJ2aWRlby1hcGkiOlt7ImFwaUtleSI6IjA3ZGI3NDUxIiwiYXBwbGljYXRpb25JZCI6Ijk5YThhZWRmLTc5ODgtNDM5NS04ODY0LTAxMjY4M2I3NmY1ZCIsImV4dHJhQ29uZmlnIjp7InZpZGVvLWFwaSI6eyJpbml0aWFsX2xheW91dF9jbGFzc19saXN0IjoiIiwicm9sZSI6Im1vZGVyYXRvciIsInNjb3BlIjoic2Vzc2lvbi5jb25uZWN0Iiwic2Vzc2lvbl9pZCI6IjFfTVg0NU9XRTRZV1ZrWmkwM09UZzRMVFF6T1RVdE9EZzJOQzB3TVRJMk9ETmlOelptTldSLWZqRTNOREF3T0RreE9UQXlOekItTkdWNGNWbDNTREkzY3psbE9FTXhibGx4UkVaWGJHTmhmbjUtIn19fV19LCJhdWQiOiJwb3J0dW51cy5pZHAudm9uYWdlLmNvbSIsImV4cCI6MTc0MDY5Mzk5OCwianRpIjoiMDczODk2M2ItY2Q0ZS00NzlkLTg5NmItY2IwN2ZlZTJiNzcxIiwiaWF0IjoxNzQwMDg5MTk4LCJpc3MiOiJWSUFNLUlBUCIsIm5iZiI6MTc0MDA4OTE4Mywic3ViIjoiZjY4ZDc3MWQtYzI5NS00NTY1LTg0OGYtZjg4YzU1Yjk3ZGE4In0.VcRlwGbPG2aHfGG-vopYJCRXGU8UwQEWGLGdIEB67XVuZlKxGItNhEaQSYVo2mGfSV1f9508e10zF6s7M089zsp1YGrn0RcNomNqonIefRIYYHUhN6v92V5ZSkYi7JxExKF6sJlucAvKsTqz_j07Ag_oN9Y302akNFS1R7bNlssMAdFSYVh5WSBSbgrfTJb3bY0jShRSESBKClELtLlkJlRT_Rw-OcKYla9NFao4ZUd5prAfPNKh9uWsKgD3zxSzZwDvdksZ14ZS-Nl1KslFsVhRwMVcf3onFUF4BfXlKHoY6II_5KFJ5wYWZcRm8LY1xRhy51U4Wz9yoqlvdIfCBA";

@interface ViewController ()<OTSessionDelegate, OTSubscriberDelegate, OTPublisherDelegate>
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@end

static double widgetHeight = 240;
static double widgetWidth = 320;

@interface customTransformer : NSObject <OTCustomVideoTransformer>

- (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size;

@end


@implementation customTransformer

- (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

- (void)transform:(nonnull OTVideoFrame *)videoFrame {
    
    UIImage* image = [UIImage imageNamed:@"Vonage_Logo.png"];

    uint32_t videoWidth = videoFrame.format.imageWidth;
    uint32_t videoHeight = videoFrame.format.imageHeight;

    // Calculate the desired size of the image
    CGFloat desiredWidth = videoWidth / 8;  // Adjust this value as needed
    CGFloat desiredHeight = image.size.height * (desiredWidth / image.size.width);

    // Resize the image to the desired size
    UIImage *resizedImage = [self resizeImage:image toSize:CGSizeMake(desiredWidth, desiredHeight)];

    // Get pointer to the Y plane
    uint8_t* yPlane = [videoFrame getPlaneBinaryData:0];
    
    // Create a CGContext from the Y plane
    CGContextRef context = CGBitmapContextCreate(yPlane, videoWidth, videoHeight, 8, videoWidth, CGColorSpaceCreateDeviceGray(), kCGImageAlphaNone);
    
    // Location of the image (in this case right bottom corner)
    CGFloat x = videoWidth * 4/5;
    CGFloat y = videoHeight * 1/5;
    
    // Draw the resized image on top of the Y plane
    CGRect rect = CGRectMake(x, y, desiredWidth, desiredHeight);
    CGContextDrawImage(context, rect, resizedImage.CGImage);
    
    CGContextRelease(context);
}

@end

customTransformer* logoTransformer;

@implementation ViewController

UIButton *buttonMediaTransformerToggle;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Step 1: As the view comes into the foreground, initialize a new instance
    // of OTSession and begin the connection process.
    _session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                        delegate:self];
    [self doConnect];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
}
#pragma mark - OpenTok methods

/** 
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnect
{
    OTError *error = nil;
    
    [_session connectWithToken:kToken error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
    OTPublisherSettings *settings = [[OTPublisherSettings alloc] init];
    settings.name = [UIDevice currentDevice].name;
    _publisher = [[OTPublisher alloc] initWithDelegate:self settings:settings];
   
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
    
    [self.view addSubview:_publisher.view];
    [_publisher.view setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
    
    // Configure toogle button
    buttonMediaTransformerToggle = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonMediaTransformerToggle.frame = CGRectMake(widgetWidth - 65, 15, 50, 25);
    buttonMediaTransformerToggle.layer.cornerRadius = 5.0;
    [self.view addSubview:buttonMediaTransformerToggle];
    [self.view bringSubviewToFront:buttonMediaTransformerToggle];
    [buttonMediaTransformerToggle setTitle:@"set" forState:UIControlStateNormal];
    buttonMediaTransformerToggle.titleLabel.font = [UIFont systemFontOfSize:12];
    [buttonMediaTransformerToggle setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    buttonMediaTransformerToggle.backgroundColor = [UIColor whiteColor];
    buttonMediaTransformerToggle.layer.borderWidth = 1.0;  // Adjust the width as desired
    buttonMediaTransformerToggle.layer.borderColor = [UIColor grayColor].CGColor;
    [buttonMediaTransformerToggle addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];

}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [_publisher.view removeFromSuperview];
    _publisher = nil;
    // this is a good place to notify the end-user that publishing has stopped.
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish, 
 * this method does not add the subscriber to the view hierarchy. Instead, we 
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Cleans the subscriber from the view hierarchy, if any.
 * NB: You do *not* have to call unsubscribe in your controller in response to
 * a streamDestroyed event. Any subscribers (or the publisher) for a stream will
 * be automatically removed from the session during cleanup of the stream.
 */
- (void)cleanupSubscriber
{
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    // Step 2: We have successfully connected, now instantiate a publisher and
    // begin pushing A/V streams into OpenTok.
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}


- (void)session:(OTSession*)mySession
  streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    if (nil == _subscriber)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
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
    if ([_subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    assert(_subscriber == subscriber);
    [_subscriber.view setFrame:CGRectMake(0, widgetHeight, widgetWidth,
                                         widgetHeight)];
    [self.view addSubview:_subscriber.view];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    NSLog(@"Publishing");
}

- (void)publisher:(OTPublisherKit*)publisher
  streamDestroyed:(OTStream *)stream
{
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
    
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher
 didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"OTError"
                                                                         message:string
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertVC animated:YES completion:nil];
    });
}

bool isSet = false;

- (void)buttonTapped:(UIButton *)sender {
    
    if(!isSet) {
        // Create background blur Vonage transformer
        OTVideoTransformer *BackgroundBlur = [[OTVideoTransformer alloc] initWithName:@"BackgroundBlur" properties:@"{\"radius\":\"High\"}"];
        
        // Create custom transformer
        logoTransformer = [customTransformer alloc];
        OTVideoTransformer *myCustomTransformer = [[OTVideoTransformer alloc] initWithName:@"logo" transformer:logoTransformer];
        
        NSMutableArray * myVideoTransformers = [[NSMutableArray alloc] init];
        
        [myVideoTransformers addObject:BackgroundBlur];
        [myVideoTransformers addObject:myCustomTransformer];

        // Create Noise Suppression Vonage transformer
        OTAudioTransformer *ns = [[OTAudioTransformer alloc] initWithName:@"NoiseSuppression" properties:@""];

        NSMutableArray * myAudioTransformers = [[NSMutableArray alloc] init];
        
        [myAudioTransformers addObject:ns];
        
        // Set video transformers to publisher video stream
        _publisher.videoTransformers = [[NSMutableArray alloc] initWithArray:myVideoTransformers];

        // Set audio transformers to publisher audio stream
        _publisher.audioTransformers = [[NSMutableArray alloc] initWithArray:myAudioTransformers];
        
        [buttonMediaTransformerToggle setTitle:@"reset" forState:UIControlStateNormal];
        isSet = true;
    } else {
        // Clear all transformers from video stream
        _publisher.videoTransformers = [[NSArray alloc] init];
        _publisher.audioTransformers = [[NSArray alloc] init];
        
        [buttonMediaTransformerToggle setTitle:@"set" forState:UIControlStateNormal];
        isSet = false;
    }
    
}


@end
