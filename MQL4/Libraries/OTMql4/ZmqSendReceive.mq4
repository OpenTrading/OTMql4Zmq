// -*-mode: c++; fill-column: 75; tab-width: 8; coding: utf-8-dos -*-

//+------------------------------------------------------------------+
//|                                                      mql4zmq.mq4 |
//|                                  Copyright © 2012, Austen Conrad |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+

#property copyright "Copyright © 2012, Austen Conrad and 2014 Open Trading"
#property link      "https://github.com/OpenTrading/"
#property library

#include <stdlib.mqh>
#include <stderror.mqh>
#include <OTMql4/OTMql4Zmq.mqh>
#include <OTMql4/OTLibLog.mqh>

bool bZmqSend(int iSpeaker, string sMess) {
  // returns true on success, false on failure
  int response[1];
  bool bRetval = false;

  if (iSpeaker < 1) {
      vError("Un Allocated speaker " + ": " + IntegerToString(iSpeaker));
      return(false);  
  }
  // ALLOW null messages

  // Select the pointer to use, Select the memory address of the data buffer to point to,
  // Set the length of the message pointer
  // (needs to match the length of the memory address pointed to).
  // Finally, we check for a return of -1 and catch the error.
  if (zmq_msg_init_data(response, sMess, StringLen(sMess)) == -1) {
    vError("error creating ZeroMQ message for data: " + sMess);
    return(bRetval);
  }

  // Publish data.
  //
  // If you need to send a Multi-part message do the following (example is a three part message).
  //    zmq_send(speaker, part_1, ZMQ_SNDMORE);
  //    zmq_send(speaker, part_2, ZMQ_SNDMORE);
  //    zmq_send(speaker, part_3);
  // ZMQ_NOBLOCK
  if (zmq_send(iSpeaker, response) == -1)  {
    // Will return -1 if no clients are connected to receive message.
    vWarn("No clients subscribed: " + sMess);
  } else {
    vDebug("Published message: " + sMess);
    bRetval = true;
  }
  // Deallocate message.
  zmq_msg_close(response);
  return(bRetval);
}

string uZmqReceiveNew (int iListener) {
    // Receive subscription data via main API //
    string uMessage = "";
    int request[1];
    int iMessageLength;

    if (iListener < 1) {
      vError("uZmqReceive: unallocated listener");
      return(-1);  
    }
    //vTrace("uZmqReceive: Check for inbound message");
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
	vTrace("Received message of length: " + iMessageLength);
	
	//vTrace("Drop excess null's from the pointer.");
	//uMessage = StringSubstr(uMessage, 0, iMessageLength);
    } else {
        return("");
    }

    return(uMessage);
}

string uZmqReceive (int iListener) {
    // Receive subscription data via main API //
    string uMessage = "";
    int request[1];
    int iMessageLength;


    if (iListener < 1) {
      vError("uZmqReceive: unallocated listener");
      return(-1);  
    }
    vTrace("Check for inbound message");
    zmq_msg_init(request);

  // Note: If we do NOT specify ZMQ_NOBLOCK it will wait here until
  //       we recieve a message. This is a problem as this function
  //       will effectively block the MQL4 'Start' function from firing
  //       when the next tick arrives if no message has arrived from
  //       the publisher. If you want it to block and, therefore, instantly
  //       receive messages (doesn't have to wait until next tick) then
  //       change the below line to:
  //
  //       if (zmq_recv(iListener, request) != -1)

  // Will return -1 if no message was received.
  if (zmq_recv(iListener, request, ZMQ_NOBLOCK) != -1) {
      vTrace("Retrive message size");
      iMessageLength = zmq_msg_size(request);
      
      vTrace("Retrieve pointer to message data");
      uMessage = zmq_msg_data(request);

      if (iMessageLength > 0) {
	vDebug("Received message of length: " + iMessageLength);
	
	//?vTrace("Drop excess null's from the pointer.");
	//? uMessage = StringSubstr(uMessage, 0, iMessageLength);
      }

    }

  vTrace("Deallocate request.");
  zmq_msg_close(request);
  vTrace("Returning message: " + uMessage);

  return(uMessage);
}
