Project 5: Multi Party Call
==================================

This project shows how to use Opentok SDK to develop multi party call.(one 
publisher, N subscribers with only one subscriber video enabled at a time).
It basically extends the Let’s build publisher sample project included in 
this cookbook. By the end of a code review, you should learn how to add a 
multi party calls with Opentok SDK. This example also shows how to use 
archiving feature.


Configuration Notes
===================

1.  Since we are importing a number of classes implemented in Project 2, the 
    header search paths in the project build settings must be extended to look
    in the project 2 directory. Additionally, we must recompile the 
    implementation files in order to continue using our TBExamplePublisher,
    created in project 2. You will notice an extra group in this project's 
    navigator space with references to the files we need.
    

Application Notes
=================

1. This sample shows a publisher bar(bottom), subscriber bar (top) and  an 
   archiving overlay

2. Publisher bar has buttons for publisher's toggle camera and mute/unmute 
   publisher's audio
   
3. Subscriber bar has a button which allows subscriber to enable/disable audio

4. Swipe right/left to navigate to the next/previous subscriber in the session