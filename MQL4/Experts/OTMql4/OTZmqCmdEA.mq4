// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-

/*
THIS DOES NOT WORK YET: DO NOT USE, unless you can help us find the problem.
See
https://github.com/OpenTrading/OTMql4Zmq/issues/1
and

*/

#property copyright "Copyright 2013 OpenTrading"
#property link      "https://github.com/OpenTrading/"
#property strict

extern int iSUBPUB_PORT=2027;
extern int iREPREQ_PORT=2028;
// can replace this with the IP address of an interface - not lo
extern string sHOST_ADDRESS="127.0.0.1";

#include <OTMql4/OTLibLog.mqh>
#include <OTMql4/OTLibStrings.mqh>
#include <OTMql4/OTLibSimpleFormatCmd.mqh>
#include <OTMql4/OTLibJsonFormat.mqh>
#include <OTMql4/OTZmqProcessCmd.mqh>
#include <OTMql4/OTMql4Zmq.mqh>
#include <OTMql4/ZmqSendReceive.mqh>
#include <OTMql4/ZmqConstants.mqh>

#include <WinUser32.mqh>


int iTIMER_INTERVAL_SEC = 10;

int iSPEAKER=-1;
int iLISTENER=-1;
int iCONTEXT=-1;
double fZMQ_CONTEXT_USERS;

string uSYMBOL = Symbol();
int iTIMEFRAME = Period();

int iTICK=0;
int iBAR=1;

int iIsEA=1;
string uSafeString(string uSymbol) {
    uSymbol = uStringReplace(uSymbol, "!", "");
    uSymbol = uStringReplace(uSymbol, "#", "");
    uSymbol = uStringReplace(uSymbol, "-", "");
    uSymbol = uStringReplace(uSymbol, ".", "");
    return(uSymbol);
}
string uChartName(string uSymbol, int iPeriod, long iWindowId, int iExtra=0) {
    /*
      We will need a unique identifier for each chart
    */
    string uRetval="";

    uRetval = StringFormat("oChart_%s_%i_%X_%i", uSymbol, iPeriod, iWindowId, iExtra);
    return(uRetval);
}
string uCHART_ID = uChartName(uSafeString(uSYMBOL), Period(), ChartID(), iIsEA);

void vPanic(string uReason) {
    "A panic prints an error message and then aborts";
    vError("PANIC: " + uReason);
    MessageBox(uReason, "PANIC!", MB_OK|MB_ICONEXCLAMATION);
    // Does this even work?
    // ExpertRemove();
}

int OnInit() {
    int iErr;
    string uErr, uTopic;

    iTIMEFRAME = Period();

    if (GlobalVariableCheck("fZmqContextUsers") == true) {
        fZMQ_CONTEXT_USERS=GlobalVariableGet("fZmqContextUsers");
    } else {
        fZMQ_CONTEXT_USERS = 0.0;
    }
    if (fZMQ_CONTEXT_USERS > 0.1) {
        iCONTEXT = MathRound(GlobalVariableGet("fZmqContext"));
        iSPEAKER=MathRound(GlobalVariableGet("fZmqSpeaker"));
        iLISTENER=MathRound(GlobalVariableGet("fZmqListener"));
        if (iSPEAKER < 1) {
            vError("OnInit: unallocated speaker");
            return(-1);
        }
        if (iLISTENER < 1) {
            vError("OnInit: unallocated listener");
            return(-1);
        }
        if (iCONTEXT < 1) {
            vError("OnInit: unallocated context");
            return(-1);
        }
    } else {
        iCONTEXT = zmq_init(1);
        if (iCONTEXT < 1) {
            iErr=mql4zmq_errno(); uErr=zmq_strerror(iErr);
            uErr = "OnInit: failed init of zmq, iErr "+IntegerToString(iErr)+" "+uErr;
	    vPanic(uErr);
            return(-1);
        }

        GlobalVariableTemp("fZmqContextUsers");
        GlobalVariableTemp("fZmqSpeaker");
        GlobalVariableTemp("fZmqListener");
        GlobalVariableTemp("fZmqContext");
        iSPEAKER = zmq_socket(iCONTEXT, ZMQ_PUB);
        if (iSPEAKER < 1) {
            iErr=mql4zmq_errno(); uErr=zmq_strerror(iErr);
            vPanic("OnInit: failed allocating the speaker " + ": , iErr "+IntegerToString(iErr)+" "+uErr);
            return(-1);
        }
        if (zmq_bind(iSPEAKER,"tcp://"+sHOST_ADDRESS+":"+iSUBPUB_PORT) == -1) {
            iErr=mql4zmq_errno(); uErr=zmq_strerror(iErr);
            vPanic("OnInit: failed binding the speaker on "+sHOST_ADDRESS+":"+iSUBPUB_PORT +": , iErr "+IntegerToString(iErr)+" "+uErr);
            return(-1);
        }
        vInfo("bound the speaker on "+sHOST_ADDRESS+":"+iSUBPUB_PORT);

	uTopic = "";
        iLISTENER = zmq_socket(iCONTEXT, ZMQ_REP);
        if (iLISTENER < 1) {
            iErr=mql4zmq_errno(); uErr=zmq_strerror(iErr);
            vPanic("OnInit: failed allocating the listener " + ": , iErr "+IntegerToString(iErr)+" "+uErr);
            return(-1);
        }
	// sHOST_ADDRESS = "*";
        if (zmq_bind(iLISTENER,"tcp://"+sHOST_ADDRESS+":"+iREPREQ_PORT) == -1) {
            iErr=mql4zmq_errno(); uErr=zmq_strerror(iErr);
            vPanic("OnInit: failed binding the listener on "+sHOST_ADDRESS+":"+iREPREQ_PORT +": , iErr "+IntegerToString(iErr)+" "+uErr);
            return(-1);
        }
        vInfo("OnInit: bound the listener on "+sHOST_ADDRESS+":"+iREPREQ_PORT);

	// old unused code for sub instead of rep
	/*
	if (zmq_setsockopt(iLISTENER, ZMQ_SUBSCRIBE, uTopic) == -1) {
            iErr=mql4zmq_errno(); uErr=zmq_strerror(iErr);
            vPanic("OnInit: failed subscribing the listener to topic: "+uTopic+", iErr "+IntegerToString(iErr)+" "+uErr);
            return(-1);
        }
	*/
        GlobalVariableSet("fZmqSpeaker", iSPEAKER);
        GlobalVariableSet("fZmqListener", iLISTENER);
        GlobalVariableSet("fZmqContext", iCONTEXT);
    }

    fZMQ_CONTEXT_USERS += 1.0;
    GlobalVariableSet("fZmqContextUsers", fZMQ_CONTEXT_USERS);
    vInfo("OnInit: Incremented fZmqContextUsers to "+ MathRound(fZMQ_CONTEXT_USERS) + " with iCONTEXT: " + iCONTEXT);

    EventSetTimer(iTIMER_INTERVAL_SEC);
    
    int major[1];int minor[1];int patch[1];
    zmq_version(major,minor,patch);
    vInfo("OnInit: Using zeromq version " + major[0] + "." + minor[0] + "." + patch[0]);
    return(0);
}

void OnDeinit(const int iReason) {
    //? if (iReason == INIT_FAILED) { return ; }
    string uZero="0";
    EventKillTimer();

    fZMQ_CONTEXT_USERS=GlobalVariableGet("fZmqContextUsers");
    if (fZMQ_CONTEXT_USERS < 1.5) {
        iSPEAKER=MathRound(GlobalVariableGet("fZmqSpeaker"));
        iLISTENER=MathRound(GlobalVariableGet("fZmqListener"));

        //? set linger?
        if (iSPEAKER < 1) {
            vWarn("OnDeOnInit: unallocated speaker");
        } else {
            zmq_setsockopt(iSPEAKER, ZMQ_LINGER, uZero);
            zmq_close(iSPEAKER); iSPEAKER=0;
        }
        GlobalVariableDel("fZmqSpeaker");

        if (iLISTENER < 1) {
            vWarn("OnDeOnInit: unallocated listener");
        } else {
            zmq_setsockopt(iLISTENER, ZMQ_LINGER, uZero);
            zmq_close(iLISTENER); iLISTENER=0;
        }
        GlobalVariableDel("fZmqListener");

        if (iCONTEXT < 1) {
            vWarn("OnDeOnInit: unallocated context");
        } else {
            zmq_term(iCONTEXT); iCONTEXT=0;
        }
        GlobalVariableDel("fZmqContext");

        GlobalVariableDel("fZmqContextUsers");
        vDebug("OnDeOnInit: zmq_close, deleted fZmqContextUsers");
    } else {
        fZMQ_CONTEXT_USERS -= 1.0;
        GlobalVariableSet("fZmqContextUsers", fZMQ_CONTEXT_USERS);
        vDebug("OnDeOnInit: decreased, value of fZmqContextUsers to: " + fZMQ_CONTEXT_USERS);
    }

}

/*
OnTimer is called every iTIMER_INTERVAL_SEC (10 sec.)
which allows us to use Python to look for Zmq inbound messages,
or execute a stack of calls from Python to us in Metatrader.
*/
void OnTimer() {
    string uRetval="";
    string uMessage;
    bool bRetval;
    string uType = "timer";
    string uMess, uInfo;
    // FixMe: could use GetTickCount but we may not be logged in
    // but maybe TimeCurrent requires us to be logged in?
    string uTime = IntegerToString(TimeCurrent());
    // same as Time[0]
    datetime tTime = iTime(uSYMBOL, Period(), 0);

    /* timer events can be called before we are ready */
    if (GlobalVariableCheck("fZmqContextUsers") == false) {
      return;
    }
    
    iSPEAKER=MathRound(GlobalVariableGet("fZmqSpeaker"));
    if (iSPEAKER < 1) {
        vWarn("OnTimer: unallocated speaker");
    } else {
	uInfo = "json|" + jOTTimerInformation();
	uMess  = zOTLibSimpleFormatTimer(uType, uCHART_ID, 0, uTime, uInfo);
	bRetval = bZmqSend(iSPEAKER, uMess);
	if (bRetval == false) {
	    vWarn("OnTimer: failed bZmqSend");
	} else {
	    vTrace("OnTimer: bZmqSend sent " +uMess);
	}
    }
    
    uMessage = zReqRepListen();
    // its non-blocking so it will usually be empty
    if ( uMessage == "" ) {return;}
    vDebug("OnTimer: got message: " +uMessage);
    vReqRepReply(uMessage);
}

void vReqRepReply(string uMessage) {
    string uRetval = "";
    string uMess;
    bool bRetval;
    
    //vTrace("vReqRepReply:: got message: " +uMessage);

    if (StringFind(uMessage, "exec", 0) == 0) {
        //vTrace("vReqRepReply:: got exec message: " + uMessage);
        // execs are executed immediately and return a result on the wire
        // They're things that take less than a tick to evaluate
        //vTrace("Processing immediate exec message: " + uMessage);
        uRetval = zOTZmqProcessCmd(uMessage);
	// WE INCLUDED THE SMARK
	uMess  = zOTLibSimpleFormatRetval("retval", uCHART_ID, 0, "", uRetval);
        vDebug("vReqRepReply:: Sending message back through iLISTENER: " + uMess);
        bRetval = bZmqSend(iLISTENER, uMess);
    } else if (StringFind(uMessage, "cmd", 0) == 0) {

        vDebug("Sending NULL message to: " + iLISTENER);
        bZmqSend(iLISTENER, "null");

        //vTrace("Processing defered cmd message: " + uMessage);
        uRetval = zOTZmqProcessCmd(uMessage);
        if (StringLen(uRetval) > 0) {
	    // WE INCLUDED THE SMARK
	    uMess  = zOTLibSimpleFormatRetval("retval", uCHART_ID, 0, "", uRetval);
            vDebug("Publishing message: " + uMess);
            bRetval = bZmqSend(iSPEAKER, uMess);
        } else {
            vWarn("Unprocessed message: " + uMessage);
        }
    } else {
        vError("Internal error, not cmd or exec: " + uMessage);
    }
}

string zReqRepListen() {
    string uMessage;
    
    iLISTENER=MathRound(GlobalVariableGet("fZmqListener"));
    if (iLISTENER < 1) {
        vError("zReqRepListen: unallocated listener");
        return("");
    }
    
    // vTrace("vListen: looking for messages");
    uMessage = uZmqReceive(iLISTENER);
    if (StringLen(uMessage) == 0) {
        // we will always get null messages if nothing is on the wire
        // as we are not blocking, which would block the tick processing
        // but we seem to also get garbage - empty CR or LF perhaps?
        // FixMe - investigate
        return("");
    }
    //vTrace("zReqRepListen: found message: " + uMessage);
    return(uMessage);
}

void OnTick() {
    static datetime tNextbartime;
    bool bNewBar=false;
    string uType;
    bool bRetval;
    string s;
    string uInfo;
    string uMessage;

    iSPEAKER=MathRound(GlobalVariableGet("fZmqSpeaker"));
    if (iSPEAKER < 1) {
        vPanic("OnTick: unallocated speaker");
        return;
    }

    // FixMe: could use GetTickCount but we may not be logged in
    // but maybe TimeCurrent requires us to be logged in?
    string uTime = IntegerToString(TimeCurrent());
    // same as Time[0]
    datetime tTime = iTime(uSYMBOL, Period(), 0);

    if (tTime != tNextbartime) {
        iBAR += 1; // = Bars - 100
        iTICK = 0;
        tNextbartime = tTime;
	uInfo = "json|" + jOTBarInformation(uSYMBOL, Period(), 0) ;
        uType = "bar";
        uMessage  = zOTLibSimpleFormatBar(uType, uCHART_ID, 0, uTime, uInfo);
    } else {
        iTICK += 1;
	uInfo = "json|" + jOTTickInformation(uSYMBOL, Period()) ;
        uType = "tick";
        uMessage  = zOTLibSimpleFormatTick(uType, uCHART_ID, 0, uTime, uInfo);
    }
    
    bRetval = bZmqSend(iSPEAKER, uMessage);
    if (bRetval == false) {
	vWarn("OnTick: failed bZmqSend");
    }

    //vTrace("OnTick: listening: ");
    uMessage = zReqRepListen();
    // its non-blocking so it will usually be empty
    if ( uMessage == "" ) {return;}
    vDebug("OnTick: got message: " +uMessage);
    vReqRepReply(uMessage);

}
