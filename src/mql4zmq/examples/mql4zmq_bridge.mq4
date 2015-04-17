//+------------------------------------------------------------------+
//|                                               mql4zmq_bridge.mq4 |
//|                             Copyright © 2012-2013, Austen Conrad |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, 2013 Austen Conrad"
#property link      "http://www.mql4zmq.org"

// Runtime options to specify.
extern string trade_direction = "short";
extern string ZMQ_transport_protocol = "tcp";
extern string ZMQ_server_address = "192.168.0.5";
extern string ZMQ_inbound_port = "1986";
extern string ZMQ_outbound_port = "1985";
extern int EMA_long = 180;
extern int EMA_short = 60;

// Include the libzmq.dll abstration wrapper.
#include <mql4zmq.mqh>

//+------------------------------------------------------------------+
//| variable definitions                                             |
//+------------------------------------------------------------------+
int speaker,listener,context,i,start_position,end_position,ticket;
string outbound_connection_string,inbound_connection_string,keyword,uid,command_string;

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
   
   Print("This is an example bridge.");

   context = zmq_init(1);
   speaker = zmq_socket(context, ZMQ_PUB);
   listener = zmq_socket(context, ZMQ_SUB);
   outbound_connection_string = ZMQ_transport_protocol + "://" + ZMQ_server_address + ":" + ZMQ_outbound_port;
   inbound_connection_string = ZMQ_transport_protocol + "://" + ZMQ_server_address + ":" + ZMQ_inbound_port;
   command_string = "cmd|" + AccountName();
  
   // Subscribe to the command channel (i.e. "cmd").  
   // NOTE: to subscribe to multiple channels call zmq_setsockopt multiple times.
   zmq_setsockopt(listener, ZMQ_SUBSCRIBE, command_string);
 
   // We chose to have the metatrader side use bind for both listeners and speakers because metatrader instance has to always be up and there
   // will likely only ever be one metatrader instance. Whereas, we may end up scaling or sharding the recieved data amoung several data nodes.
   //
   // This points out that with ZeroMQ it does not matter which end binds and which connects. It is best practice that the more stable
   // end is the bind end.
 /*  if (zmq_bind(speaker,"tcp://*:2027") == -1) 
   {
      Print("Error binding the speaker!");
      return(-1);  
   }
   
   if (zmq_bind(listener,"tcp://*:2028") == -1)
   {
      Print("Error binding the listener!");
      return(-1);
   }
 */  
  
   if (zmq_connect(speaker, outbound_connection_string) == -1)
   {
      Print("Error connecting the speaker to the central queue!");
      return(-1);
   }

   if (zmq_connect(listener, inbound_connection_string) == -1)
   {
      Print("Error connecting the listener to the central queue!");
      return(-1);
   }
   
   // Send Notification that bridge is up.
   // Format: bridge|testaccount UP short EURUSD 1355775144
   string bridge_up = "bridge|" + AccountName() + " UP " + trade_direction + " " + Symbol() + " " + TimeCurrent();
   if(s_send(speaker, bridge_up) == -1)
      Print("Error sending message: " + bridge_up);
   else
      Print("Published message: " + bridge_up);
      
   // Output command string.
   Print("Listening for commands on channel: " + command_string);
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----

   // Delete all objects from the chart.
   for(int i=ObjectsTotal()-1; i>-1; i--) {
      ObjectDelete(ObjectName(i));
   }
   Comment("");
   
   // Send Notification that bridge is down.
   // Format: bridge|testaccount DOWN
   string bridge_up = "bridge|" + AccountName() + " DOWN";
   if(s_send(speaker, bridge_up) == -1)
      Print("Error sending message: " + bridge_up);
   else
      Print("Published message: " + bridge_up);
   
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
/*
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
*/ 
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
      
      // If current currency pair is requested.
      if (StringFind(message2, "currentPair", 0) != -1)
      {
         // Pull out request uid. Message is formatted: "cmd|[account name]|[uid] currentPair"
         uid = message_get_uid(message2);
         
         // ack uid.
         Print("uid: " + uid);
         
         // Send response.
         if(send_response(uid, Symbol()) == false)
            Print("ERROR occurred sending response!");
      }
      
      // Trade wireframe for sending to MetaTrader specification:
      //
      // For new trade or order:
      // cmd|[account name]|[uid] set [trade_type] [pair] [open price] [take profit price] [stop loss price] [lot size]
      // ex=> 
      //   cmd|testaccount|fdjksalr38wufsd= set 2 EURUSD 1.25 1.2503 1.2450
      //   
      // For updating a trade:
      // cmd|[account name]|[uid] reset [ticket_id] [take profit price] [stop loss price]
      // ex=> 
      //   cmd|testaccount|fdjksalr38wufsd= reset 43916144 1.2515 1.2502
      //
      // For updating an order:
      // cmd|[account name]|[uid] reset [ticket_id] [take profit price] [stop loss price] [open price]
      // ex=> 
      //   cmd|testaccount|fdjksalr38wufsd= reset 43916144 1.2515 1.2502 1.2507
      //   
      // For closing a trade or order:
      // cmd|[account name]|[uid] unset [ticket_id]
      // ex=> 
      //   cmd|testaccount|fdjksalr38wufsd= unset 43916144
      
      // If new trade operation is requested.
      //
      // NOTE: MQL4's order type numbers are as follows:
      // 0 = (MQL4) OP_BUY - buying position,
      // 1 = (MQL4) OP_SELL - selling position,
      // 2 = (MQL4) OP_BUYLIMIT - buy limit pending position,
      // 3 = (MQL4) OP_SELLLIMIT - sell limit pending position,
      // 4 = (MQL4) OP_BUYSTOP - buy stop pending position,
      // 5 = (MQL4) OP_SELLSTOP - sell stop pending position.
      if (StringFind(message2, "reset", 0) != -1)
      {
         // Pull out request uid. Message is formatted: "cmd|[account name]|[uid] reset [ticket_id] [take profit price] [stop loss price] [optional open price]"
         uid = message_get_uid(message2);
         
         // ack uid.
         Print("uid: " + uid);
         
         // Initialize array to hold the extracted settings. 
         string trade_update_settings[4] = {"ticket_id", "take_profit", "stop_loss", "open_price"};
    
         // Pull out the trade settings.
         keyword = "reset";
         start_position = StringFind(message2, keyword, 0) + StringLen(keyword) + 1;
         end_position = StringFind(message2, " ", start_position + 1);
         
         for(i = 0; i < ArraySize(trade_update_settings); i++)
         {
            trade_update_settings[i] = StringSubstr(message2, start_position, end_position - start_position);
            
            // Protect against looping back around to the beginning of the string by exiting if the new
            // start position would be a lower index then the current one.
            if(StringFind(message2, " ", end_position) < start_position)
               break;
            else 
            { 
               start_position = StringFind(message2, " ", end_position);
               end_position = StringFind(message2, " ", start_position + 1);
            }
         }

         // Select the requested order.
         OrderSelect(StrToInteger(trade_update_settings[0]),SELECT_BY_TICKET);

         // Since 'open_price' was not received, we know that we're updating a trade.
         bool update_ticket = false;
         if(trade_update_settings[3] == "open_price")
         {
         
            // Send the trade modify instructions.
            update_ticket = OrderModify(OrderTicket(),
                                     OrderOpenPrice(),
                                     NormalizeDouble(StrToDouble(trade_update_settings[2]), Digits),
                                     NormalizeDouble(StrToDouble(trade_update_settings[1]), Digits), 
                                     0, 
                                     Blue); 
         // Since 'open_price' was received, we know that we're updating an order.
         } else {
         Print(NormalizeDouble(StrToDouble(trade_update_settings[3]), Digits));
            // Send the order modify instructions.
            update_ticket = OrderModify(OrderTicket(),
                                     NormalizeDouble(StrToDouble(trade_update_settings[3]), Digits),
                                     NormalizeDouble(StrToDouble(trade_update_settings[2]), Digits),
                                     NormalizeDouble(StrToDouble(trade_update_settings[1]), Digits), 
                                     0, 
                                     Blue);
         }
                  
         if(update_ticket == false)
         {
            Print("OrderSend failed with error #",GetLastError());
            return(0);
         }
         else
         {
            if(trade_update_settings[3] == "open_price")
            {
               Print("Trade: " + trade_update_settings[0] + " updated stop loss to: " + trade_update_settings[2] + " and take profit to: " + trade_update_settings[1]);
            }
            else
            {
               Print("Order: " + trade_update_settings[0] + " updated stop loss to: " + trade_update_settings[2] + ", take profit to: " + trade_update_settings[1] + ", and open price to: " + trade_update_settings[3]);
            }
            
            // Send response.
            if(send_response(uid, "Order has been processed.") == false)
               Print("ERROR occurred sending response!");
         }
      } 
      else if (StringFind(message2, "unset", 0) != -1)
      {
         // Pull out request uid. Message is formatted: "cmd|[account name]|[uid] unset [ticket_id]"
         uid = message_get_uid(message2);
         
         // ack uid.
         Print("uid: " + uid);
         
         // Pull out the trade settings.
         keyword = "unset";
         start_position = StringFind(message2, keyword, 0) + StringLen(keyword) + 1;
         end_position = StringFind(message2, " ", start_position + 1);
 
         string ticket_id = StringSubstr(message2, start_position, end_position - start_position);
            
         // Select the requested order.
         OrderSelect(StrToInteger(ticket_id),SELECT_BY_TICKET);
         
         // Send the oder close instructions.
         bool close_ticket;
         if (OrderType() == OP_BUY)
         {
            close_ticket = OrderClose(OrderTicket(), OrderLots(), Bid, 3, Red);
         }
         else if (OrderType() == OP_SELL)
         {
            close_ticket = OrderClose(OrderTicket(), OrderLots(), Ask, 3, Red);
         }
         else if (OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLLIMIT || OrderType() == OP_SELLSTOP)
         {
            close_ticket = OrderDelete(OrderTicket());
         }
         
         if(close_ticket == false)
         {
            Print("OrderSend failed with error #",GetLastError());
            return(0);
         }
         else
         {
         
            Print("Closed trade: " + ticket_id);
            
            // Send response.
            if(send_response(uid, "Order has been processed.") == false)
               Print("ERROR occurred sending response!");
         }
         
      } 
      else if (StringFind(message2, "set", 0) != -1)
      {
         // Pull out request uid. Message is formatted: "cmd|[account name]|[uid] set [trade_type] [pair] [open price] [take profit price] [stop loss price] [lot_size]"
         uid = message_get_uid(message2);
         
         // ack uid.
         Print("uid: " + uid);
         
         // Initialize array to hold the extracted settings. 
         string trade_settings[6] = {"type", "pair", "open_price" ,"take_profit", "stop_loss", "lot_size"};
    
         // Pull out the trade settings.
         keyword = "set";
         start_position = StringFind(message2, keyword, 0) + StringLen(keyword) + 1;
         end_position = StringFind(message2, " ", start_position + 1);
 
         for(i = 0; i < ArraySize(trade_settings); i++)
         {
            trade_settings[i] = StringSubstr(message2, start_position, end_position - start_position);
            
            // Protect against looping back around to the beginning of the string by exiting if the new
            // start position would be a lower index then the current one.
            if(StringFind(message2, " ", end_position) < start_position)
               break;
            else 
            { 
               start_position = StringFind(message2, " ", end_position);
               end_position = StringFind(message2, " ", start_position + 1);
            }
         }
         
         Print(trade_settings[0] + " " + trade_settings[1] + ", Open: " + trade_settings[2] + ", TP: " + trade_settings[3] + ", SL: " + trade_settings[4] + ", Lots: " + trade_settings[5]);
         
         // Open trade.
         Print(NormalizeDouble(StrToDouble(trade_settings[3]), Digits));
         ticket = OrderSend(StringTrimLeft(trade_settings[1]),
                                          StrToInteger(trade_settings[0]), 
                                          NormalizeDouble(StrToDouble(trade_settings[5]), Digits),
                                          NormalizeDouble(StrToDouble(trade_settings[2]), Digits),
                                          3,
                                          NormalizeDouble(StrToDouble(trade_settings[4]), Digits),
                                          NormalizeDouble(StrToDouble(trade_settings[3]), Digits),
                                          NULL,
                                          0,
                                          TimeCurrent() + 3600,
                                          Green); 
         if(ticket<0)
         {
            Print("OrderSend failed with error #",GetLastError());
            return(0);
         }
         else 
         { 
            // Send response.
            if(send_response(uid, "Order has been processed.") == false)
               Print("ERROR occurred sending response!");
         }
      }
      
      // If a new element to be drawen is requested.
      if (StringFind(message2, "Draw", 0) != -1)
      {
         // Pull out request uid. Message is formatted: "cmd|[account name]|[uid] Draw [obj_type] [open time] [open price] [close time] [close price] [prediction]"
         uid = message_get_uid(message2);
         
         // Initialize array to hold the extracted settings. 
         string object_settings[7] = {"object_type", "window", "open_time", "open_price" ,"close_time", "close_price", "prediction"};
         
         // Pull out the drawing settings.
         keyword = "Draw";
         start_position = StringFind(message2, keyword, 0) + StringLen(keyword) + 1;
         end_position = StringFind(message2, " ", start_position + 1);

         for(i = 0; i < ArraySize(object_settings); i++)
         {
            object_settings[i] = StringSubstr(message2, start_position, end_position - start_position);
            
            // Protect against looping back around to the beginning of the string by exiting if the new
            // start position would be a lower index then the current one.
            if(StringFind(message2, " ", end_position) < start_position)
               break;
            else 
            { 
               start_position = StringFind(message2, " ", end_position);
               end_position = StringFind(message2, " ", start_position + 1);
            }
         }
         
         // ack uid.
         Print("uid: " + uid);
     
         // Generate UID
         double bar_uid = MathRand()%10001/10000.0;
            
         // Draw the rectangle object.
         Print("Drawing: ", object_settings[0], " ", object_settings[1], " ", object_settings[2], " ", object_settings[3], " ", object_settings[4], " ", object_settings[5], " ", object_settings[6]);
         if(!ObjectCreate("bar:" + bar_uid, draw_object_string_to_int(object_settings[0]), StrToInteger(object_settings[1]), StrToInteger(object_settings[2]), StrToDouble(object_settings[3]), StrToInteger(object_settings[4]), StrToDouble(object_settings[5])))
         {
           Print("error: cannot create object! code #",GetLastError());
           // Send response.
           send_response(uid, false);
         }
         else
         {
           // Color the bar based on the predicted direction. If no prediction was sent than the 
           // 'prediction' keyword will still occupy the array element and we need to set to Gray.
           if(StringFind(object_settings[6], "prediction", 0) != -1)
           {
              ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, Gray);
           }
           else if(StrToDouble(object_settings[6]) > 0.5)
           {
              ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, CadetBlue);
           }
           else if(StrToDouble(object_settings[6]) < 0.5)
           {
              ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, IndianRed);
           }
           else
              ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, Gray);
                 
           // Send response.
           send_response(uid, true);
         }         
      }
      
      return(0);
      
   }
   

////////// We expose both the main ZeroMQ API (http://api.zeromq.org/2-1:_start) and the ZeroMQ helper functions. 
////////// Below is an example of how to publish a message using the main API. Then below that is an example of how 
////////// to do the same thing using the helpers instead.

   // Publish current tick value.
   string current_tick = "tick|" + AccountName() + " " + Symbol() + " " + Bid + " " + Ask + " " + Time[0];

   // Publish the currently open orders.
   string current_orders = lookup_open_orders(); 
   
   // Publish account info.
   string current_account_info = "account|" + AccountName() + " " + AccountLeverage() + " " + AccountBalance() + " " + AccountMargin() + " " + AccountFreeMargin();
   
   // Publish currently requested EMA's.
   string current_ema_info = "ema|" + AccountName() + " " + Symbol() + " " + EMA_long + " " + iMA(Symbol(),0,EMA_long,0,MODE_EMA,PRICE_MEDIAN,0) + " " + EMA_short + " " + iMA(Symbol(),0,EMA_short,0,MODE_EMA,PRICE_MEDIAN,0);

   
////////// Publish data via main API //////////
/*     
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
*/
////////// Publish data via helpers API //////////

   // Publish data.
   //
   // If you need to send a Multi-part message do the following (example is a three part message). 
   //    s_sendmore(speaker, part_1);
   //    s_sendmore(speaker, part_2);
   //    s_send(speaker, part_3);
   //
   // Current tick.
   if(s_send(speaker, current_tick) == -1)
      Print("Error sending message: " + current_tick);
   else
      Print("Published message: " + current_tick);
   // Currently open orders.	
   if(s_send(speaker, current_orders) == -1)
      Print("Error sending message: " + current_orders);
   else
      Print("Published message: " + current_orders);   
   // Current account info.	
   if(s_send(speaker, current_account_info) == -1)
      Print("Error sending message: " + current_account_info);
   else
      Print("Published message: " + current_account_info );
   // Current EMA info.	
   if(s_send(speaker, current_ema_info) == -1)
      Print("Error sending message: " + current_ema_info);
   else
      Print("Published message: " + current_ema_info );
//----
   return(0);
  }
  
//+------------------------------------------------------------------+
//| Pulls out the UID for the message. Messages are fomatted:
//|      => "cmd|[account name]|[uid] [some command]
//+------------------------------------------------------------------+
string message_get_uid(string message)
{
   // Pull out request uid. Message is formatted: "cmd|[accountname]|[uid] [some command]"
   string uid_start_string = "cmd|" + AccountName() + "|";
   int uid_start = StringFind(message, uid_start_string, 0) + StringLen(uid_start_string);
   int uid_end = StringFind(message, " ", 0) - uid_start;
   string uid = StringSubstr(message, uid_start, uid_end);
   
   // Return the UID
   return(uid);
} 

//+------------------------------------------------------------------+
//| Returns the currently open orders.
//|      => "orders|testaccount1 {:symbol => 'EURUSD', :type => 'sell', ...}, {... "
//+------------------------------------------------------------------+
string lookup_open_orders()
{
   // Initialize the orders string.
   string current_orders = "orders|" + AccountName() + " ";
   
   // Look up the total number of open orders.
   int total_orders = OrdersTotal();

   // Build a json-like string for each order and add it to eh current_orders return string.  
   for(int position=0; position < total_orders; position++)
   {
     if(OrderSelect(position,SELECT_BY_POS)==false) continue;
   
     current_orders = current_orders + "{:pair => \'" + OrderSymbol() + "\', :type => \'" + OrderType() + "\', :ticket_id => \'" + OrderTicket() + "\', :open_price => \'" + OrderOpenPrice() + "\', :take_profit => \'" + OrderTakeProfit() + "\', :stop_loss => \'" + OrderStopLoss() + "\', :open_time => \'" + OrderOpenTime() + ", :expire_time => \'" + OrderExpiration() + "\', :lots => \'" + OrderLots() + "\'}\n";
   }
      
   // Return the completed string.
   return(current_orders);
}

//+------------------------------------------------------------------+
//| Sends a response to a command. Messages are fomatted:
//|      => "response|[account name]|[uid] [some command]
//+------------------------------------------------------------------+
bool send_response(string uid, string response)
{
   // Compose response string.
   string response_string = "response|" + AccountName() + "|" + uid + " " + response;
   
   // Send the message.
   if(s_send(speaker, response_string) == -1)
   {
      Print("Error sending message: " + response_string);
      return(false);
   }   
   else
   {
      Print("Published message: " + response_string); 
      return(true);
   }
} 

//+------------------------------------------------------------------+
//| Returns the MetaTrader integer value for the string versions of the object types.
//+------------------------------------------------------------------+
int draw_object_string_to_int(string name)
{      

   // Initialize result holder with the error code incase a match is not found.
   int drawing_type_result = -1;
   
   // Initialize array of all of the drawing types for MQL4.
   // NOTE: They are in numerical order. I.E. OBJ_VLINE has
   //       a value of '0' and therefore is array element '0'.
   string drawing_types[24] = {
      "OBJ_VLINE", 
      "OBJ_HLINE", 
      "OBJ_TREND", 
      "OBJ_TRENDBYANGLE", 
      "OBJ_REGRESSION", 
      "OBJ_CHANNEL", 
      "OBJ_STDDEVCHANNEL", 
      "OBJ_GANNLINE", 
      "OBJ_GANNFAN",
      "OBJ_GANNGRID",
      "OBJ_FIBO",
      "OBJ_FIBOTIMES",
      "OBJ_FIBOFAN",
      "OBJ_FIBOARC",
      "OBJ_EXPANSION",
      "OBJ_FIBOCHANNEL",
      "OBJ_RECTANGLE",
      "OBJ_TRIANGLE",
      "OBJ_ELLIPSE",
      "OBJ_PITCHFORK",
      "OBJ_CYCLES",
      "OBJ_TEXT",
      "OBJ_ARROW",
      "OBJ_LABEL"
    };
   
    // Cycle throught the array to find a match to the specified 'name' value.
    // Once a match is found, store it's location within the array. This location
    // corresponds to the int value it should have.
    for(int i = 0; i < ArraySize(drawing_types); i++)
    {
      if(name == drawing_types[i])
      {
         drawing_type_result = i;
         break;
      }
    }
   
    // Return the int value the string would have had if it was a pointer of type int.
    switch(drawing_type_result)                                  
    {           
      case 0 : return(0);          break;               //	   Vertical line. Uses time part of first coordinate.
      case 1 : return(1);          break;               //	   Horizontal line. Uses price part of first coordinate.
      case 2 : return(2);          break;               //		Trend line. Uses 2 coordinates.
      case 3 : return(3);          break;               //		Trend by angle. Uses 1 coordinate. To set angle of line use ObjectSet() function.
      case 4 : return(4);          break;               //		Regression. Uses time parts of first two coordinates.
      case 5 : return(5);          break;               //		Channel. Uses 3 coordinates.
      case 6 : return(6);          break;               //		Standard deviation channel. Uses time parts of first two coordinates.
      case 7 : return(7);          break;               //		Gann line. Uses 2 coordinate, but price part of second coordinate ignored.
      case 8 : return(8);          break;               //		Gann fan. Uses 2 coordinate, but price part of second coordinate ignored.
      case 9 : return(9);          break;               //		Gann grid. Uses 2 coordinate, but price part of second coordinate ignored.
      case 10 : return(10);        break;               //		Fibonacci retracement. Uses 2 coordinates.
      case 11 : return(11);        break;               //		Fibonacci time zones. Uses 2 coordinates.
      case 12 : return(12);        break;               //		Fibonacci fan. Uses 2 coordinates.
      case 13 : return(13);        break;               //		Fibonacci arcs. Uses 2 coordinates.
      case 14 : return(14);        break;               //		Fibonacci expansions. Uses 3 coordinates.
      case 15 : return(15);        break;               //		Fibonacci channel. Uses 3 coordinates.
      case 16 : return(16);        break;               //		Rectangle. Uses 2 coordinates.
      case 17 : return(17);        break;               //		Triangle. Uses 3 coordinates.
      case 18 : return(18);        break;               //		Ellipse. Uses 2 coordinates.
      case 19 : return(19);        break;               //		Andrews pitchfork. Uses 3 coordinates.
      case 20 : return(20);        break;               //		Cycles. Uses 2 coordinates.
      case 21 : return(21);        break;               //		Text. Uses 1 coordinate.
      case 22 : return(22);        break;               //		Arrows. Uses 1 coordinate.
      case 23 : return(23);        break;               //	   Labels.
      default : return(-1);                             //     ERROR. NO MATCH FOUND.
   }
}
  
//+------------------------------------------------------------------+