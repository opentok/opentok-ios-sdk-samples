iOS SDK Cookbook
================

This repository is meant to provide some examples for you to better understand
the new features presented in version 2.2 of the OpenTok iOS SDK.

What's Inside
-------------

There are three projects that each build on the lessons of the previous. By the
end of a code review of all, you will have an understanding of the new video
capture and render API. Additionally, you will be able to get started with
writing your own extensions to the default capture implementations provided 
herein.

1.	**Hello World** - This basic application demonstrates a short path to 
	getting started with the OpenTok iOS SDK.

2.	**Let's Build OTPublisher** - This project provides classes that implement
	the OTVideoCapture and OTVideoRender interfaces of the core Publisher and
	Subscriber classes. Using these modules, we can see the basic workflow of
	sourcing video frames from the device camera in and out of OpenTok, via the
	OTPublisherKit and OTSubscriberKit interfaces.

3.	**Live Photo Capture** - This project extends the video capture module 
	implemented in project 2, and demonstrates how the AVFoundation media 
	capture APIs can be used to simultaneously stream video and capture 
	high-resolution photos from the same camera.

4.	**Overlay Graphics** - This project shows how to overlay graphics on 
	publisher and subscriber views and uses SVG graphic format for icons.
	This project barrows publisher and subscribers modules implemented in 
	project 2.
	
5.	**Multi Party Call** - This project demonstrate how to use Opentok SDK for 
	a multi party call. The application publish audio/video from iOS device and
	can connect to N number of subscribers. However it shows only one subscriber 
	video at a time due to cpu limitations on iOS devices. 
	