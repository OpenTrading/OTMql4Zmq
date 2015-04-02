// -*-mode: c++; fill-column: 75; tab-width: 8; coding: utf-8-dos -*-
//+------------------------------------------------------------------+
//|                                                  was mql4zmq.mq4 |
//|                                  Copyright © 2012, Austen Conrad |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012 Austen Conrad"
#property link      "https://github.com/OpenTrading/"

#import "ZmqSendReceive.ex4"

bool bZmqSend(int iSpeaker, string sMess);
string uZmqReceive (int iListener);
