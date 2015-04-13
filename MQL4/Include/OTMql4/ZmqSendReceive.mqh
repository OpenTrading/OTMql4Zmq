// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-
//+------------------------------------------------------------------+
//|                                                  was mql4zmq.mq4 |
//|                                  Copyright © 2012, Austen Conrad |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, Austen Conrad and 2014 Open Trading"
#property link      "https://github.com/OpenTrading/"

#import "OTMql4/ZmqSendReceive.ex4"

bool bZmqSend(int iSpeaker, string sMess);
string uZmqReceive (int iListener);
