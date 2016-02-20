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
#include <OTMql4/ZmqConstants.mqh>

//FixMe: move
#import "kernel32.dll"
   int lstrlenA(int);
   void RtlMoveMemory(uchar & arr[], int, int);
   int LocalFree(int); // May need to be changed depending on how the DLL allocates memory
#import

bool bZmqSend(int iSpeaker, string uMessage) {
    //  Returns true on success, false on failure
    int iPointer[1];
    bool bRetval = false;
    int iError;
    int iMessLen;

    if (iSpeaker < 1) {
        vError("bZmqSend: Un Allocated speaker " + ": " + IntegerToString(iSpeaker));
        return(false);
    }
    iMessLen = StringLen(uMessage);
    //? ALLOW null messages

    if (true) {
        //vTrace("bZmqSend: s_send "+ uMessage + " length " + IntegerToString(iMessLen));
	if (s_send(iSpeaker, uMessage) == -1) {
	    iError = zmq_errno(); uMessage = zmq_strerror(iError);
	    vError("bZmqSend: error sending message: " +iError +" " +uMessage);
	    return(false);
	}
	bRetval = true;
    } else {
        // vTrace("bZmqSend: zmq_msg_init_data "+ uMessage + " length " + IntegerToString(iMessLen));
        if (zmq_msg_init_data(iPointer, uMessage, iMessLen) == -1) {
	    iError = zmq_errno(); uMessage = zmq_strerror(iError);
            vError("bZmqSend: error creating ZeroMQ message for data: "  +iError +" " +uMessage);
            return(false);
        }

	// ZMQ_NOBLOCK
	if (zmq_send(iSpeaker, iPointer, 0) == -1)  {
	    //? Will return -1 if no clients are connected to receive message.
	    vWarn("bZmqSend: No clients subscribed: " + uMessage);
	} else {
	    // See if sleeping here helps not corrupt the payload with the following stdout
	    // Zmq is async on send, so it could be that we are reusing memonry before
	    // the message has actually been delivered
	    // See https://github.com/OpenTrading/OTMql4Zmq/wiki/CompiledDllOTMql4Zmq
	    Sleep(1000);
	    vDebug("bZmqSend: Published message: " + uMessage);
	    bRetval = true;
	}
    }
    // Deallocate message.
    zmq_msg_close(iPointer);
    return(bRetval);
}

string uZmqReceive(int iListener) {
    string uMessage = "";
    int iRequestPtr[1];
    int iMessageLength, iError, iRetval;

    if (iListener < 1) {
        vError("uZmqReceive: unallocated listener");
        return("");
    }

    if (true) {
	//vTrace("uZmqReceive: calling s_recv");
	uMessage = s_recv(iListener, ZMQ_NOBLOCK);
	iMessageLength = StringLen(uMessage);
	if (iMessageLength > 0) {
	    //vTrace("uZmqReceive: Received message "+uMessage+" of StringLen: " + IntegerToString(iMessageLength));
	}
    } else {
	// THIS CODE DOES NOT WORK - but should
	// I've even seen access violations (but not crashes)
	// vTrace("uZmqReceive: initialize iRequestPtr");
	iRetval = zmq_msg_init(iRequestPtr);
	if ( iRetval < 0) {
	    iError = zmq_errno(); uMessage = zmq_strerror(iError);
	    vError("uZmqReceive: zmq_msg_init() failed! " +iError +" " +uMessage);
	    return("");
	}
	// Note: If we do NOT specify ZMQ_NOBLOCK it will wait here until
	// we receive a message. This is a problem as this function
	// will effectively block the MQL4 'Start' function from firing
	// when the next tick arrives if no message has arrived from
	// the publisher. If you want it to block and, therefore, instantly
	// receive messages (doesn't have to wait until next tick) then
	// change the below line to:
	//
	// if (zmq_recv(iListener, iRequestPtr) != -1)

	//vTrace("uZmqReceive: calling zmq_recv");
	// Will return -1 if no message was received.
	if (zmq_recv(iListener, iRequestPtr, ZMQ_NOBLOCK) != -1) {
	    // vTrace("uZmqReceive: Retrieve message size");
	    iMessageLength = zmq_msg_size(iRequestPtr);
	    if (iMessageLength > 0) {
		// vTrace("uZmqReceive: Retrieve pointer to message data");
		uMessage = zmq_msg_data(iRequestPtr);

		vDebug("uZmqReceive: Received message of zmq_msg_size: " + iMessageLength);

		// vTrace("uZmqReceive: Drop excess null's from the pointer.");
		// uMessage = StringSubstr(uMessage, 0, iMessageLength);
		//vTrace("uZmqReceive: Returning message: " + uMessage + " of length " + StringLen(uMessage));
	    }
	} else {
	    iError = zmq_errno();
	    // 11 EAGAIN resource unavailable
	    if (iError != ZMQ_EAGAIN && iError != ZMQ_EVENT_CLOSED) {
		uMessage = zmq_strerror(iError);
		vWarn("uZmqReceive: zmq_recv() failed with error " +iError +" " +uMessage);
	    }
	    uMessage = "";
	}
	// vTrace("uZmqReceive: Deallocate iRequestPtr.");
	zmq_msg_close(iRequestPtr);
    }
    return(uMessage);
}
