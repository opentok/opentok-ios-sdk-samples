# Video Transformers Changelog

All notable changes to this project will be documented in this file.

## 2.25.2

### Added

- Support pre-built transformers in the Vonage Media Processor library or create your own custom video transformer to apply to published video.

### Known issues

- When using Vonage's Background Blur, the ML model is not being automatically added to the main bundle. It is required to be added manually: 
  - Select the target for which you want to add the file. Go to the "Build Phases" tab.
  - Expand the "Copy Bundle Resources" section.
  - Click the "+" button to add a new file. A file picker dialog will appear. Choose ./Pods/VonageClientSDKVideo/OpenTok.xcframework/ios-arm64/OpenTok.framework/selfie_segmentation.tflite

### Fixed

- NA

### Enhancements

- NA

### Changed

- NA

### Deprecated

- NA
