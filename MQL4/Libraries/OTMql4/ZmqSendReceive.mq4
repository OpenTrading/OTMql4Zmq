// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-

//+------------------------------------------------------------------+
//|                                                      mql4zmq.mq4 |
//|                                    Copyright 2012, Austen Conrad |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+

#property copyright "Copyright 2012 Austen Conrad and 2014 Open Trading"
#property link      "https://github.com/OpenTrading/"
#property library

#include <stdlib.mqh>
#include <stderror.mqh>
#include <OTMql4/OTLibStrings.mqh>
#include <OTMql4/OTMql4Zmq.mqh>
#include <OTMql4/OTLibLog.mqh>

//FixMe: move
#import "kernel32.dll"
   int lstrlenA(int);
   void RtlMoveMemory(uchar & arr[], int, int);
   int LocalFree(int); // May need to be changed depending on how the DLL allocates memory
#import

bool bZmqSend(int iSpeaker, string uMessage) {
    // returns true on success, false on failure
    int response[1];
    bool bRetval = false;
    int iPointer;
    int iMessLen;

    if (iSpeaker < 1) {
        vError("bZmqSend: Un Allocated speaker " + ": " + IntegerToString(iSpeaker));
        return(false);
    }
    uMessage = "0123456789ABCDEF" + uMessage;
    iMessLen = StringLen(uMessage);
    // ALLOW null messages

    if (false) {
        // vTrace("bZmqSend: zmq_msg_init_size "+ uMessage + " length " + IntegerToString(iMessLen));
        /*
          if (zmq_msg_init_size(response, iMessLen) == -1) {
          vError("error creating ZeroMQ message for size: " + uMessage);
          return(false);
          }
          uchar sCharArray[];
          ArrayResize(sCharArray, iMessLen);
          StringToCharArray(uMessage, sCharArray);
          iPointer = mql4zmq_msg_data(response);
          RtlMoveMemory(iPointer, sCharArray, iMessLen);
        */
    } else {
        // vTrace("bZmqSend: zmq_msg_init_data "+ uMessage + " length " + IntegerToString(iMessLen));

        // Select the pointer to use, Select the memory address of the data buffer to point to,
        // Set the length of the message pointer
        // (needs to match the length of the memory address pointed to).
        // Finally, we check for a return of -1 and catch the error.

        if (zmq_msg_init_data(response, uMessage, iMessLen) == -1) {
            vError("error creating ZeroMQ message for data: " + uMessage);
            return(false);
        }
    }

    // Publish data.
    //
    // If you need to send a Multi-part message do the following (example is a three part message).
    //    zmq_send(speaker, part_1, ZMQ_SNDMORE);
    //    zmq_send(speaker, part_2, ZMQ_SNDMORE);
    //    zmq_send(speaker, part_3);
    // ZMQ_NOBLOCK
    if (zmq_send(iSpeaker, response) == -1)  {
        //? Will return -1 if no clients are connected to receive message.
        vWarn("No clients subscribed: " + uMessage);
    } else {
	// See if sleeping here helps not corrupt the payload with the following stdout
	// Zmq is async on send, so it could be that we are reusing memonry before
	// the message has actually been delivered
	// See https://github.com/OpenTrading/OTMql4Zmq/wiki/CompiledDllOTMql4Zmq
	Sleep(2);
        vDebug("Published message: " + uMessage);
        bRetval = true;
    }
    // Deallocate message.
    zmq_msg_close(response);
    return(bRetval);
}

// crashes after 5-15 sec
string uZmqReceiveNew (int iListener) {
    // Receive subscription data via main API //
    string uMessage = "";
    int request[1];
    int iMessageLength;

    if (iListener < 1) {
        vError("uZmqReceive: unallocated listener");
        return(-1);
    }
    // vTrace("uZmqReceive: Check for inbound message");
    // Note: If we do NOT specify ZMQ_NOBLOCK it will wait here until
    //       we recieve a message. This is a problem as this function
    //       will effectively block the MQL4 'Start' function from firing
    //       when the next tick arrives if no message has arrived from
    //       the publisher. If you want it to block and, therefore, instantly
    //       receive messages (doesn't have to wait until next tick) then
    //       change the below line to:
    //
    //       if (zmq_recv(iListener, request) != -1)

    uMessage = s_recv(iListener, ZMQ_NOBLOCK);
    iMessageLength = StringLen(uMessage);
    if (iMessageLength > 0) {
        // vTrace("Received message "+uMessage+" of StringLen: " + IntegerToString(iMessageLength));

    }

    return(uMessage);
}

// access violation
string uZmqReceive (int iListener) {
    // Receive subscription data via main API //
    string uMessage = "";
    int iRequestPtr[1];
    int iMessageLength;

    if (iListener < 1) {
        vError("uZmqReceive: unallocated listener");
        return(-1);
    }
    // vTrace("uZmqReceive: initialize iRequestPtr");
    zmq_msg_init(iRequestPtr);
    if ( iRequestPtr[0] < 1) {
        vError("zmq_msg_init(iRequestPtr) failed!");
        return("");
    }
    // Note: If we do NOT specify ZMQ_NOBLOCK it will wait here until
    //       we recieve a message. This is a problem as this function
    //       will effectively block the MQL4 'Start' function from firing
    //       when the next tick arrives if no message has arrived from
    //       the publisher. If you want it to block and, therefore, instantly
    //       receive messages (doesn't have to wait until next tick) then
    //       change the below line to:
    //
    //       if (zmq_recv(iListener, iRequestPtr) != -1)

    // Will return -1 if no message was received.
    // vTrace("uZmqReceive: zmq_recv");
    if (zmq_recv(iListener, iRequestPtr, ZMQ_NOBLOCK) != -1) {
        // vTrace("uZmqReceive: Retrieve message size");
        iMessageLength = zmq_msg_size(iRequestPtr);
        if (iMessageLength > 0) {
            // vTrace("uZmqReceive: Retrieve pointer to message data");
            uMessage = zmq_msg_data(iRequestPtr);

            vDebug("uZmqReceive: Received message of zmq_msg_size: " + iMessageLength);

            // vTrace("uZmqReceive: Drop excess null's from the pointer.");
            uMessage = StringSubstr(uMessage, 0, iMessageLength);
            // vTrace("uZmqReceive: Returning message: " + uMessage + " of length " + StringLen(uMessage));
        }
    }

    // vTrace("uZmqReceive: Deallocate iRequestPtr.");
    zmq_msg_close(iRequestPtr);

    return(uMessage);
}
