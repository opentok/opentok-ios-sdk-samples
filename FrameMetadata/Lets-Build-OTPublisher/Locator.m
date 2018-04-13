//
//  Locator.m
//  Custom-Video-Driver
//
//  Created by Lucas Huang on 4/12/18.
//  Copyright © 2018 TokBox, Inc. All rights reserved.
//

#import "Locator.h"
#import <CoreLocation/CoreLocation.h>

@interface Locator() <CLLocationManagerDelegate>
@property (nonatomic, readwrite) NSArray *latestLocation;
@property (nonatomic) CLLocationManager *locationManager;
@end

@implementation Locator

- (instancetype)init {
    if (self = [super init]) {
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
        [_locationManager requestWhenInUseAuthorization];
    }
    return self;
}

- (void)startGettingLocation {
    [self.locationManager startUpdatingLocation];
}

- (void)stopGettingLocation {
    [self.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (locations.count != 0) {
        self.latestLocation = @[@(locations[0].coordinate.latitude), @(locations[0].coordinate.longitude)];
    }
}

@end
