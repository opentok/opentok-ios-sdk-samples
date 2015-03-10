//
//  ViewController.m
//  Multi-Party-Call
//
//  Created by Sridhar on 07/04/14.
//  Copyright (c) 2014 Tokbox. All rights reserved.
//

#import "TBViewController.h"
#import <OpenTok/OpenTok.h>
#import "TBVoiceViewCell.h"

static NSString* const kApiKey = @"";
//// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";

// Change to NO to subscribe to streams other than your own.
static bool subscribeToSelf = NO;

#define PUBLISHER_ARCHIVE_CONTAINER_HEIGHT 85.0f

@interface TBViewController ()<OTSessionDelegate, OTSubscriberKitDelegate,
OTPublisherDelegate>{

	NSMutableDictionary *allSubscribers;
	NSMutableArray *allConnectionsIds;
    
	OTSession *_session;
	OTPublisher *_publisher;
	OTSubscriber *_currentSubscriber;
	CGPoint _startPosition;
    
	BOOL initialized;
   
}
@property(nonatomic,retain) NSMutableDictionary *viewControllers;
@end

@implementation TBViewController

@synthesize videoContainerView;

- (void)viewDidLoad
{
	[super viewDidLoad];
    
    self.publisherName = [[UIDevice currentDevice] name];
    self.title = @"Voice Only Sample App";
    
	[self.view sendSubviewToBack:self.videoContainerView];
	self.endCallButton.titleLabel.lineBreakMode = NSLineBreakByCharWrapping;
	self.endCallButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    
    
    // configure video container view
	self.videoContainerView.scrollEnabled = NO;
    
    self.tableView.hidden = YES;
    self.publisherView.hidden = YES;
    
	allSubscribers = [[NSMutableDictionary alloc] init];
	allConnectionsIds = [[NSMutableArray alloc] init];
    
	// set up look of the page
	[self.navigationController setNavigationBarHidden:NO];
    self.navigationItem.hidesBackButton = YES;
    
    self.archiveOverlay.hidden = YES;
    
    UIColor *bgColor = [UIColor colorWithRed:40.0f/255.0f
                                       green:40.0f/255.0f
                                        blue:40.0f/255.0f
                                       alpha:1.0];
    self.videoContainerView.backgroundColor = bgColor;
    self.view.backgroundColor = bgColor;
    self.publisherView.backgroundColor = bgColor;
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = bgColor;
    self.tableView.rowHeight = 78.0f;
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    
    bgColor = [UIColor colorWithRed:47.0f/255.0f
                              green:47.0f/255.0f
                               blue:47.0f/255.0f
                              alpha:1.0];
    [self.tableView setSeparatorColor:bgColor];
    self.bottomOverlayView.layer.borderColor = bgColor.CGColor;
    self.bottomOverlayView.layer.borderWidth = 1;
    
    bgColor = [UIColor colorWithRed:54.0f/255.0f
                              green:54.0f/255.0f
                               blue:54.0f/255.0f
                              alpha:1.0];
    self.bottomOverlayView.backgroundColor = bgColor;
    
    
    NSString *myIdentifier = @"MyCell";
    [self.tableView registerNib:
     [UINib nibWithNibName:@"TBVoiceViewCell" bundle:nil]
         forCellReuseIdentifier:myIdentifier];
    
    [self setupSession];
    [self.endCallButton sendActionsForControlEvents:UIControlEventTouchDown];
}

-(void)viewDidLayoutSubviews
{
    CGRect frame = self.videoContainerView.frame;
    frame.origin.y = 0;
    self.videoContainerView.frame = frame;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotate
{
	return NO;
}

- (void)setupSession
{
    //setup one time session
	_session = [[OTSession alloc] initWithApiKey:kApiKey
									   sessionId:kSessionId
										delegate:self];
    [_session connectWithToken:kToken error:nil];
    [self setupPublisher];
    
}

- (void)setupPublisher
{
    // create one time publisher and style publisher
	 _publisher = [[OTPublisher alloc]
                              initWithDelegate:self name:self.publisherName];
    _publisher.publishVideo = NO;
}

#pragma mark - OpenTok Session
- (void)        session:(OTSession *)session
	connectionDestroyed:(OTConnection *)connection
{
	NSLog(@"connectionDestroyed: %@", connection);
}

- (void)      session:(OTSession *)session
	connectionCreated:(OTConnection *)connection
{
	NSLog(@"addConnection: %@", connection.connectionId);
}

- (void)sessionDidConnect:(OTSession *)session
{
    // now publish
    OTError *error = nil;
	[_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

    [self.spinningWheel stopAnimating];
    
    self.publisherNameLbl.text = self.publisherName;
    self.publisherView.hidden = NO;
    self.tableView.hidden = NO;
    TBAudioLevelMeter *tbAudioLevelMeter = [[TBAudioLevelMeter alloc]
                                           initWithFrame:CGRectZero];
    tbAudioLevelMeter.toucesPassToView = self.publisherMicButton;
    tbAudioLevelMeter.userInteractionEnabled = NO;
    
    self.publisherAudioLevelMeter = tbAudioLevelMeter;

    self.publisherAudioLevelMeter.opaque = false;
    CGRect frame = self.publisherMicButton.frame;
    _publisherAudioLevelMeter.frame = frame;
    _publisher.audioLevelDelegate = self;
    [self.publisherMicContainerView insertSubview:self.publisherAudioLevelMeter
                                     aboveSubview:self.publisherMicButton];
}

- (void)publisher:(OTPublisherKit *)publisher
audioLevelUpdated:(float)audioLevel
{
    float db = 20 * log10(audioLevel);
    float floor = -40;
    float level = 0;
    if (db > floor) {
        level = db + abs(floor);
        level /= abs(floor);
    }
    self.publisherAudioLevelMeter.level = level;
}

- (void)sessionDidDisconnect:(OTSession *)session
{
    session.delegate = nil;
    _publisher.audioLevelDelegate = nil;
    [self.publisherAudioLevelMeter removeFromSuperview];
    self.publisherView.hidden = YES;
    
	[allSubscribers removeAllObjects];
	[allConnectionsIds removeAllObjects];
    
    if (self.archiveStatusImgView.isAnimating)
    {
        [self stopArchiveAnimation];
    }
    [self.tableView reloadData];
}

- (void)    session:(OTSession *)session
	streamDestroyed:(OTStream *)stream
{
	NSLog(@"streamDestroyed %@", stream.connection.connectionId);
	   
    OTSubscriber *subscriber = [allSubscribers
                                valueForKey:stream.connection.connectionId];
    subscriber.audioLevelDelegate = nil;
    
	[allSubscribers removeObjectForKey:stream.connection.connectionId];
	[allConnectionsIds removeObject:stream.connection.connectionId];
    
    [self.tableView reloadData];
}

- (void)subscribeToStream:(OTStream *)stream
{
	   
    // create subscriber
	OTSubscriber *subscriber = [[OTSubscriber alloc]
                                       initWithStream:stream
                                delegate:self] ;
    
    subscriber.subscribeToVideo = NO;
    
    // subscribe now
    OTError *error = nil;
	[_session subscribe:subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
        return;
    }
}

- (void)subscriberDidConnectToStream:(OTSubscriberKit *)subscriber
{
	NSLog(@"subscriberDidConnectToStream %@, connection id %@",
          subscriber.stream.streamId,subscriber.stream.connection.connectionId);
    
    [allConnectionsIds addObject:subscriber.stream.connection.connectionId];
    [allSubscribers setObject:subscriber forKey:subscriber.stream.connection.connectionId];
    
    [self.tableView reloadData];
}

- (void)  session:(OTSession *)mySession
	streamCreated:(OTStream *)stream
{
    // create remote subscriber
    [self subscribeToStream:stream];
}

- (void)  publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    // subscribe to self
    if (subscribeToSelf ==  YES)
        [self subscribeToStream:stream];
}

- (void)session:(OTSession *)session didFailWithError:(OTError *)error
{
	NSLog(@"sessionDidFail");
	[self showAlert:
     [NSString stringWithFormat:@"There was an error connecting to session %@",
      error.localizedDescription]];
	[self endCallAction:nil];
}

- (void)publisher:(OTPublisher *)publisher didFailWithError:(OTError *)error
{
	NSLog(@"publisher didFailWithError %@", error);
	[self showAlert:[NSString stringWithFormat:
                     @"There was an error publishing."]];
	[self endCallAction:nil];
}

- (void)subscriber:(OTSubscriber *)subscriber didFailWithError:(OTError *)error
{
	NSLog(@"subscriber could not connect to stream");
}

#pragma mark - Helper Methods
- (IBAction)endCallAction:(UIButton *)button
{
    
	if (_session && _session.sessionConnectionStatus ==
        OTSessionConnectionStatusConnected) {
        // disconnect session
		NSLog(@"disconnecting....");
		[_session disconnect:nil];
		return;
	}
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc]
                               initWithTitle:@"Message from video session"
                               message:string
                               delegate:self
                               cancelButtonTitle:@"OK"
                               otherButtonTitles:nil] ;
        [alert show];
    });
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Other Interactions

- (IBAction)toggleAudioPublish:(id)sender
{
	if (_publisher.publishAudio == YES) {
        _publisher.audioLevelDelegate = nil;
        self.publisherAudioLevelMeter.level = 0.0f;
		_publisher.publishAudio = NO;
		self.publisherMicButton.selected = YES;
	} else {
        _publisher.audioLevelDelegate = self;
		_publisher.publishAudio = YES;
		self.publisherMicButton.selected = NO;
	}
}

- (void)startArchiveAnimation
{
    
    if (self.archiveOverlay.hidden)
    {
        self.archiveOverlay.hidden = NO;
    }
    
    // set animation images
    self.archiveStatusLbl.text = @"Archiving call";
    UIImage *imageOne = [UIImage imageNamed:@"archiving_on-10.png"];
    UIImage *imageTwo = [UIImage imageNamed:@"archiving_pulse-15.png"];
    NSArray *imagesArray =
    [NSArray arrayWithObjects:imageOne, imageTwo, nil];
    self.archiveStatusImgView.animationImages = imagesArray;
    self.archiveStatusImgView.animationDuration = 1.0f;
    self.archiveStatusImgView.animationRepeatCount = 0;
    [self.archiveStatusImgView startAnimating];
    
}

- (void)stopArchiveAnimation
{
    [self.archiveStatusImgView stopAnimating];
    self.archiveStatusLbl.text = @"Archiving off";
    self.archiveStatusImgView.image =
    [UIImage imageNamed:@"archiving-off-15.png"];
    self.archiveOverlay.hidden = YES;
}

- (void)     session:(OTSession*)session
archiveStartedWithId:(NSString*)archiveId
                name:(NSString*)name
{
    NSLog(@"started session archiving name %@", name);
    [self startArchiveAnimation];
}

- (void)     session:(OTSession*)session
archiveStoppedWithId:(NSString*)archiveId
{
    NSLog(@"stopping session archiving");
    [self stopArchiveAnimation];
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 78;
}
- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [allConnectionsIds count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    TBVoiceViewCell *cell = [tableView
                        dequeueReusableCellWithIdentifier:@"MyCell"
                                                    forIndexPath:indexPath];
    
    if (cell == nil)
    {
        NSArray *topLevelObjects = [[NSBundle mainBundle]
                                    loadNibNamed:@"TBVoiceViewCell"
                                    owner:self
                                    options:nil];
        cell = [topLevelObjects objectAtIndex:0];
        
    }
    
    UIColor *bgColor = [UIColor colorWithRed:62.0f/255.0f
                                       green:62.0f/255.0f
                                        blue:62.0f/255.0f
                                       alpha:1.0];
    cell.contentView.backgroundColor = bgColor;

    OTSubscriber *subscriber = [allSubscribers valueForKey:
                                [allConnectionsIds objectAtIndex:indexPath.row]];
    cell.name.text = subscriber.stream.name;
    cell.subscriber = subscriber;
    subscriber.audioLevelDelegate = cell;
    
    return cell;
}

@end