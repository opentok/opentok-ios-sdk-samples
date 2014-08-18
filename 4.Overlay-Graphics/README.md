Project 4: Overlay Graphics
==================================

This project shows how to overlay graphics and UI controls onto publisher and 
subscriber views. It basically extends the "Let's build OTublisher' sample
project included in this cookbook. By the end of a code review, you should learn
how to add graphics on top of publisher and subscriber renders. The sample uses
SVG icons for faster rendering.


Configuration Notes
===================

1.  This project uses open source QuickSVG SDK to process SVG files. In order 
	to compile the sample, you must first run the"./clone-quick-svg" build
	script from the terminal.

2.  Since we are importing a number of classes implemented in Project 2, the 
    header search paths in the project build settings must be extended to look
    in the project 2 directory. Additionally, we must recompile the 
    implementation files in order to continue using our TBExamplePublisher,
    created in project 2. You will notice an extra group in this project's 
    navigator space with references to the files we need.
    

Application Notes
=================

1. This sample shows a toolbar containing a mute microphone button and a toggle
   camera button for the Publisher and a volume mute button for the Subscriber.

2. Microphone mute/un mute works by publish audio and unpublish audio on the 
   publisher respectively. Toggle camera switches between using the back and
   front cameras.

3. The volume mute button on the subscriber view sets subscriber's audio
   enable/disable.

4. All SVG Icons are included in the class file TBExampleSVG.m as NSStrings.
