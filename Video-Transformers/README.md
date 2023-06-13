Video Transformers
======================

The Video Transformers app is a very simple application created on top of Basic Video Chat meant to get a new developer
started using Media Processor APIs on OpenTok iOS SDK. For a full description, see the [Video Transformers tutorial at the
OpenTok developer center](https://tokbox.com/developer/guides/vonage-media-processor/ios).

You can use pre-built transformers in the Vonage Media Processor library or create your own custom video transformer to apply to published video.

You can use the OTPublisherKit.videoTransformers properties to apply video transformers to a stream.

You can combine the Vonage Media library transformer with custom transformer or apply multiple custom transformers by adding multiple PublisherKit.VideoTransformer objects to the ArrayList used for the OTPublisherKit.videoTransformers property.

To clear video transformers for a publisher, set the OTPublisherKit.videoTransformers property to an empty array.

