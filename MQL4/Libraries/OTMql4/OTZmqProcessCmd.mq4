// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-

#property copyright "Copyright 2013 OpenTrading"
#property link      "https://github.com/OpenTrading/"
#property library

//  This is the replacement for what should be Eval in Mt4:
//  take a string expression and valuate it.
//  
//  I know this is verbose and could be done more compactly,
//  but it's clean and robust so I'll leave it like this for now.
//  
//  If you want to extend this for your own functions you have declared in Mql4,
//  look at how zOTZmqProcessCmd calls zOTLibProcessCmd and then
//  goes on and handles it if zOTLibProcessCmd didn't.
//  

#include <stdlib.mqh>
#include <stderror.mqh>
#include <OTMql4/OTLibLog.mqh>
#include <OTMql4/OTLibStrings.mqh>
#include <OTMql4/OTLibSimpleFormatCmd.mqh>
#include <OTMql4/OTLibMt4ProcessCmd.mqh>
#include <OTMql4/OTLibProcessCmd.mqh>
#include <OTMql4/OTMql4Zmq.mqh>

string zOTZmqProcessCmd(string uMess) {
    //  This is the replacement for what should be Eval in Mt4:
    //  take a string expression and evaluate it.
    //  zMt4LibProcessCmd handles base Mt4 expressions, and
    //  zOTLibProcessCmd also handles base OpenTrading expressions.
    //  and zOTZmqProcessCmd also handles base OTMql4Zmq expressions.

    //  Returns the result of processing the command.
    //  Returns "" if there is an error.

    string uType, uChartId, uIgnore, uMark, uCmd;
    string uArg1="";
    string uArg2="";
    string uArg3="";
    string uArg4="";
    string uArg5="";
    string aArrayAsList[];
    int iLen;
    string uRetval, uKey, uMsg;

    iLen =  StringLen(uMess);
    if (iLen <= 0) {return("");}

    uRetval = zOTLibProcessCmd(uMess);
    if (uRetval != "") {
        return(uRetval);
    }

    vStringToArray(uMess, aArrayAsList, "|");

    iLen = ArraySize(aArrayAsList);
    vDebug("zOTZmqProcessCmd: " +uMess +" ArrayLen " +iLen);

    uRetval = eOTLibSimpleUnformatCmd(aArrayAsList);
    if (uRetval != "") {
        vError("eOTLibProcessCmd: preprocess failed with error: " +uRetval);
        return("");
    }

    uType   = aArrayAsList[0];
    uChartId  = aArrayAsList[1];
    uIgnore = aArrayAsList[2];
    uMark   = aArrayAsList[3];
    uCmd    = aArrayAsList[4];
    uArg1   = aArrayAsList[5];
    uArg2   = aArrayAsList[6];
    uArg3   = aArrayAsList[7];
    uArg4   = aArrayAsList[8];
    uArg5   = aArrayAsList[9];
    uArg5   = aArrayAsList[10];
    uArg5   = aArrayAsList[11];

    uKey = StringSubstr(uCmd, 0, 3);
    // vTrace("zOTZmqProcessCmd uKey: " +uKey +" uCmd: " +uCmd+ " uMark: " +uMark);

    if (uKey == "Zmq") {
        uRetval = uProcessCmdZmq(uCmd, uChartId, uIgnore, uArg1, uArg2, uArg3, uArg4, uArg5);
    } else {
        uMsg="Unrecognized action: ";
	vWarn(uMsg + uMess);
        uRetval="error|" +uMsg;
    }

    // WE INCLUDE THE SMARK
    uRetval = uMark + "|" + uRetval;
    return(uRetval);
}

string uProcessCmdZmq (string uCmd, string uChartId, string uIgnore, string uArg1, string uArg2, string uArg3, string uArg4, string uArg5) {
    string uMsg;
    string uRetval="none|";

    vDebug("uProcessCmdZmq: " + uCmd + ", " + uChartId + ", " + uIgnore);
    if (uCmd == "ZmqVersion") {
        int major[1]; int minor[1]; int patch[1];
        zmq_version(major, minor, patch);
        uRetval = "string|" + major[0] + "." + minor[0] + "." + patch[0];
    } else if (uCmd == "ZmqPing") {
        uRetval = "string|" + zmq_ping(uArg1);
    } else {
        uMsg="Unrecognized action: " + uCmd; vWarn(uMsg);
        uRetval="error|"+uMsg;
    }

    return(uRetval);
}
