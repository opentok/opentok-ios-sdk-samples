Archiving
==================================

This application provides a completed version of the OpenTok Archiving tutorial for iOS (differing only in some additional validation checks). Upon deploying this sample application, you should be able to start, stop, and play back recordings of your sessions.

If you aren't familiar with how to set up a basic video chat application, you should do that first. Check out the [Basic-Video-Chat project](https://github.com/opentok/opentok-ios-sdk-samples/tree/develop/Basic-Video-Chat), and [accompanying tutorial](https://tokbox.com/developer/tutorials/ios/basic-video-chat/).

Note that you will need a valid TokBox account for this and all other TokBox samples and tutorials.

## Quick Start
=================
#### 1. Deploy a sample back end web service
Because the actual archiving is not done on the user's device, but in the OpenTok cloud, you will need to set up a web service that communicates with it to start and stop archiving.

For the purposes of this tutorial, we'll be using a pre-built sample that we've provided. You can deploy this by going to the [learning-opentok-php](https://github.com/opentok/learning-opentok-php) repository, and clicking on the purple deploy to Heroku button.

You can look through the details of that tutorial at a later point. For now, you just need to know that the sample web service provides a RESTful interface to interact with Archiving controls.

#### 2. Configure the app to use your web service
In `Config.h`, configure the `SAMPLE_SERVER_BASE_URL` string to your web service domain.

#### 3. Use Xcode to build and run the app on an iOS simulator or device.
That's it!
