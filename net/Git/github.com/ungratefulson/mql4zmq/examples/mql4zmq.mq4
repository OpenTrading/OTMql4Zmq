//+------------------------------------------------------------------+
//|                                                      mql4zmq.mq4 |
//|                                  Copyright © 2012, Austen Conrad |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, Austen Conrad"
#property link      "http://www.mql4zmq.org"

// Include the libzmq.dll abstration wrapper.
#include <mql4zmq.mqh>

//+------------------------------------------------------------------+
//| variable definitions                                             |
//+------------------------------------------------------------------+
int speaker,listener,context;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   int major[1];int minor[1];int patch[1];
   zmq_version(major,minor,patch);
   Print("Using zeromq version " + major[0] + "." + minor[0] + "." + patch[0]);
   
   Print(ping("Hello World"));
   
   Print("NOTE: to use the precompiled libraries you will need to have the Microsoft Visual C++ 2010 Redistributable Package installed. To Download: http://www.microsoft.com/download/en/details.aspx?id=5555");
   
   context = zmq_init(1);
   speaker = zmq_socket(context, ZMQ_PUB);
   listener = zmq_socket(context, ZMQ_SUB);
  
   // Subscribe to the command channel (i.e. "cmd").  
   // NOTE: to subscribe to multiple channels call zmq_setsockopt multiple times.
   zmq_setsockopt(listener, ZMQ_SUBSCRIBE, "cmd");
 
   // We chose to have the metatrader side use bind for both listeners and speakers because metatrader instance has to always be up and there
   // will likely only ever be one metatrader instance. Whereas, we may end up scaling or sharding the recieved data amoung several data nodes.
   //
   // This points out that with ZeroMQ it does not matter which end binds and which connects. It is best practice that the more stable
   // end is the bind end.
   if (zmq_bind(speaker,"tcp://*:2027") == -1) 
   {
      Print("Error binding the speaker!");
      return(-1);  
   }
   
   if (zmq_bind(listener,"tcp://*:2028") == -1)
   {
      Print("Error binding the listener!");
      return(-1);
   }
   
  /*
   if (zmq_connect(client,"tcp://10.18.16.16:5555") == -1)
   {
      Print("Error connecting to the client!");
      return(-1);
   }
  */

   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----

   // Protect against memory leaks on shutdown.
   zmq_close(speaker);
   zmq_close(listener);
   zmq_term(context);

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
   
   
////////// We expose both the main ZeroMQ API (http://api.zeromq.org/2-1:_start) and the ZeroMQ helper functions. 
////////// Below is an example of how to receive a message from a source we are subscribed
////////// to using the main API. Then below that is an example of how to do the same thing
////////// using the helpers instead.

////////// Receive subscription data via main API //////////

   // Initialize message.
   int request[1];
   zmq_msg_init(request);
   
   // Check for inbound message.
   // Note: If we do NOT specify ZMQ_NOBLOCK it will wait here until 
   //       we recieve a message. This is a problem as this function
   //       will effectively block the MQL4 'Start' function from firing
   //       when the next tick arrives if no message has arrived from 
   //       the publisher. If you want it to block and, therefore, instantly
   //       receive messages (doesn't have to wait until next tick) then
   //       change the below line to:
   //       
   //       if (zmq_recv(listener, request) != -1)
   //
   if (zmq_recv(listener, request, ZMQ_NOBLOCK) != -1) // Will return -1 if no message was received.
   {
      // Retrive pointer to message data.
      string message = zmq_msg_data(request);
      
      // Retrive message size.
      int message_length = zmq_msg_size(request);
      
      // Drop excess null's from the pointer.
      message = StringSubstr(message, 0, message_length);
      
      // Print message.
      Print("Received message: " + message);
   }
   
   // Deallocate message.
   zmq_msg_close(request);
 
////////// Receive subscription data via helper API //////////

   // Note: If we do NOT specify ZMQ_NOBLOCK it will wait here until 
   //       we recieve a message. This is a problem as this function
   //       will effectively block the MQL4 'Start' function from firing
   //       when the next tick arrives if no message has arrived from 
   //       the publisher. If you want it to block and, therefore, instantly
   //       receive messages (doesn't have to wait until next tick) then
   //       change the below line to:
   //       
   //       string message2 = s_recv(listener);
   //
   string message2 = s_recv(listener, ZMQ_NOBLOCK);
   
   if (message2 != "") // Will return NULL if no message was received.
   {
      Print("Received message: " + message2);
   }
   

////////// We expose both the main ZeroMQ API (http://api.zeromq.org/2-1:_start) and the ZeroMQ helper functions. 
////////// Below is an example of how to publish a message using the main API. Then below that is an example of how 
////////// to do the same thing using the helpers instead.

   // Publish current tick value.
   string current_tick = "tick " + Bid + " " + Ask + " " + Time[0];
   
////////// Publish data via main API //////////
     
   // Initialize message.
   int response[1];
    
   // Select the pointer to use, Select the memory address of the data buffer to point to, 
   // Set the length of the message pointer (needs to match the length of the memory address pointed to),
   //
   // Finally, we check for a return of -1 and catch the error.
   if (zmq_msg_init_data(response, current_tick, StringLen(current_tick)) == -1)
      Print("Error creating ZeroMQ message for data: " + current_tick);

   // Publish data.
   //
   // If you need to send a Multi-part message do the following (example is a three part message). 
   //    zmq_send(speaker, part_1, ZMQ_SNDMORE);
   //    zmq_send(speaker, part_2, ZMQ_SNDMORE);
   //    zmq_send(speaker, part_3);
   if (zmq_send(speaker, response) == -1) // Will return -1 if no clients are connected to receive message.
   {
      Print("No clients subscribed. Dropping data: " + current_tick);
   }
   else
      Print("Published message: " + current_tick);
 
   // Deallocate message.
   zmq_msg_close(response);

////////// Publish data via helpers API //////////

   // Publish data.
   //
   // If you need to send a Multi-part message do the following (example is a three part message). 
   //    s_sendmore(speaker, part_1);
   //    s_sendmore(speaker, part_2);
   //    s_send(speaker, part_3);
   if(s_send(speaker, current_tick) == -1)
      Print("Error sending message: " + current_tick);
   else
      Print("Published message: " + current_tick);
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
