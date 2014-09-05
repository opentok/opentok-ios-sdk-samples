Project 5: Multi-Party Call
==================================

This project shows how to use the OpenTok iOS SDK to develop a multi-party call
(one publisher, N subscribers with only one subscriber video enabled at a time).
By the end of a code review, you will learn how to use the OpenTok iOS SDK to
add a multi-party call to an app.

This example also shows how to display an indicator when the session is being
archived. (See the [Archiving overview][1] documentation.)

Application Notes
-----------------

1. This sample shows a publisher bar (bottom), subscriber bar (top), and  an
   archiving overlay.

2. The publisher bar has buttons to toggle the publisher's camera and to
   mute and unmute the publisher's audio.
   
3. The subscriber bar has a button to enable and disable the subscriber's
   audio.

4. Swipe right/left to navigate to the next/previous subscriber in the session.

5. Use one of the [OpenTok server SDKs][2] or the [OpenTok REST API][3] to start
   archiving the session. Note that you must use a session with the
   [media mode][4] set to "routed" in order to use archiving. When archiving
   begins the `[OTSessionDelegate session:archiveStartedWithId:name:]` message
   is sent.

[1]: https://tokbox.com/opentok/tutorials/archiving/
[2]: https://tokbox.com/opentok/libraries/server/
[3]: https://tokbox.com/opentok/api/
[4]: https://tokbox.com/opentok/tutorials/create-session/#media-mode