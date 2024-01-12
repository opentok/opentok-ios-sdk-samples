#!/bin/sh

set -e

cd Basic-Video-Chat/
pod install
xcodebuild -workspace Basic-Video-Chat.xcworkspace  -scheme Basic-Video-Chat -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Custom-Video-Driver/
pod install
xcodebuild -workspace Custom-Video-Driver.xcworkspace  -scheme Custom-Video-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Custom-Audio-Driver/
pod install
xcodebuild -workspace Custom-Audio-Driver.xcworkspace  -scheme Custom-Audio-Driver -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Screen-Sharing/
pod install
xcodebuild -workspace Screen-Sharing.xcworkspace  -scheme Screen-Sharing -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Live-Photo-Capture/
pod install
xcodebuild -workspace Live-Photo-Capture.xcworkspace  -scheme Live-Photo-Capture -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Simple-Multiparty/
pod install
xcodebuild -workspace Simple-Multiparty.xcworkspace  -scheme Simple-Multiparty -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Overlay-Graphics/
pod install
xcodebuild -workspace Overlay-Graphics.xcworkspace  -scheme Overlay-Graphics -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Audio-Levels/
pod install
xcodebuild -workspace Audio-Levels.xcworkspace  -scheme Audio-Levels -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Ringtones/
pod install
xcodebuild -workspace Ringtones.xcworkspace  -scheme Ringtones -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Archiving/
pod install
xcodebuild -workspace Archiving.xcworkspace  -scheme Archiving -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Signaling/
pod install
xcodebuild -workspace Signaling.xcworkspace  -scheme Signaling -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../FrameMetadata/
pod install
xcodebuild -workspace FrameMetadata.xcworkspace  -scheme FrameMetadata -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd ../Broadcast-Ext/
pod install
xcodebuild -workspace Broadcast-Ext.xcworkspace  -scheme Broadcast-Ext -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO

cd Video-Transformers/
pod install
xcodebuild -workspace Video-Transformers.xcworkspace  -scheme Video-Transformers -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -UseModernBuildSystem=NO
