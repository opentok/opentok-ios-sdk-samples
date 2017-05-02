#!/bin/sh

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -list 
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Basic-Video-Chat -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Custom-Video-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Custom-Audio-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Screen-Sharing -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Live-Photo-Capture -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Simple-Multiparty -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Overlay-Graphics -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Audio-Levels -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Ringtones -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Archiving -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO

xcodebuild -workspace Opentok-iOS-samples.xcworkspace  -scheme Signaling -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO
