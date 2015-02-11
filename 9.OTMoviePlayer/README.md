Project 9: Movie Player
==================================

This project shows how to use Opentok SDK to stream a mov file. It does this
by utilizing the extenral Audio and Video API's provided in the iOS SDK. The 
current implementation uses CoreAudio as a timer. CA is setup to sample from 
the microphone at the same sample rate as the demo video. For each recording 
callback audio is pulled from file or a circular buffer. It is then passed 
into the iOS SDK. The time of each audio chunk is monitored and a video image 
is passed into the SDK if the time of the video frame is equal to or less than 
the time of the audio. In this way the video is 'slaved' to the audio. 

NOTE: This is currenly experimental.

Possible Uses
=============

- Inserting ads in a broadcast.
- Mixing recorded media with live media.

Licenses
========

This project uses TPCircularBuffer. The license can be found in TPCircularBuffer.h
or here: https://github.com/michaeltyson/TPCircularBuffer