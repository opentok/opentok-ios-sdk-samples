#!/bin/sh

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -list 
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 1.Basics -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 2.Custom-Video-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 3.Custom-Audio-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 4.Screen-Sharing -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 5.Live-Photo-Capture -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 6.Simple-Multiparty -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 7.Overlay-Graphics -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 8.Audio-Levels -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme 9.Ringtones -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
