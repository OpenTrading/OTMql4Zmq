// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-

#property copyright "Copyright 2015 OpenTrading"
#property link      "https://github.com/OpenTrading/"
#property strict

#define INDICATOR_NAME          "PyTestZmqEA"

extern int iSEND_PORT=2027;
extern int iRECV_PORT=2028;
// can replace this with the IP address of an interface - not lo
extern string uBIND_ADDRESS="127.0.0.1";
extern string uStdOutFile="../../Logs/_test_PyTestZmqEA.txt";

#include <OTMql4/OTBarInfo.mqh>
/*
This provides the function sBarInfo which puts together the
information you want send to a remote client on every bar.
Change to suit your own needs.
*/
#include <OTMql4/OTBarInfo.mqh>

#include <OTMql4/OTLibLog.mqh>
#include <OTMql4/OTLibStrings.mqh>
#include <OTMql4/OTZmqProcessCmd.mqh>
#include <OTMql4/OTLibSimpleFormatCmd.mqh>
#include <OTMql4/OTLibPy27.mqh>
//unused #include <OTMql4/OTPyZmq.mqh>

int iTIMER_INTERVAL_SEC = 10;
int iCONTEXT = -1;
double fPY_ZMQ_CONTEXT_USERS = 0.0;

string uSYMBOL;
int iTIMEFRAME;
int iACCNUM;

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
string uCHART_ID = uChartName(uSafeString(Symbol()), Period(), ChartID(), iIsEA);
double fDebugLevel=0;

#include <WinUser32.mqh>
void vPanic(string uReason) {
    "A panic prints an error message and then aborts";
    vError("PANIC: " + uReason);
    MessageBox(uReason, "PANIC!", MB_OK|MB_ICONEXCLAMATION);
    ExpertRemove();
}

int OnInit() {
    int iRetval;
    string uArg, uRetval;

    if (GlobalVariableCheck("fPyZmqContextUsers") == true) {
        fPY_ZMQ_CONTEXT_USERS=GlobalVariableGet("fPyZmqContextUsers");
    } else {
        fPY_ZMQ_CONTEXT_USERS = 0.0;
    }
    if (fPY_ZMQ_CONTEXT_USERS > 0.1) {
	iCONTEXT = MathRound(GlobalVariableGet("fPyZmqContext"));
	if (iCONTEXT < 1) {
	    vError("OnInit: unallocated context");
	    return(-1);
	}
        fPY_ZMQ_CONTEXT_USERS += 1.0;
    } else {
	iRetval = iPyInit(uStdOutFile);
	if (iRetval != 0) {
	    return(iRetval);
	}
	Print("Called iPyInit successfully");
	
	uSYMBOL=Symbol();
	iTIMEFRAME=Period();
	iACCNUM=AccountNumber();
    
	uArg="import zmq";
	vPyExecuteUnicode(uArg);
	// VERY IMPORTANT: if the import failed we MUST PANIC
	vPyExecuteUnicode("sFoobar = '%s : %s' % (sys.last_type, sys.last_value,)");
	uRetval=uPyEvalUnicode("sFoobar");
	if (StringFind(uRetval, "exceptions.SystemError", 0) >= 0) {
	    // Were seeing this during testing after an uninit 2 reload
	    uRetval = "PANIC: import zmq failed - we MUST restart Mt4:"  + uRetval;
	    vPanic(uRetval);
	    return(-2);
	}
	if (StringFind(uRetval, "Error", 0) >= 0) {
	    uRetval = "PANIC: import pyzmq failed:"  + uRetval;
	    vPanic(uRetval);
	    return(-2);
	}
	vPyExecuteUnicode("from OTMql427 import ZmqChart");
	vPyExecuteUnicode(uCHART_ID+"=ZmqChart.ZmqChart('" +uCHART_ID +"', " +
			  "iSpeakerPort=" + iSEND_PORT + ", " +
			  "iListenerPort=" + iRECV_PORT + ", " +
			  "sIpAddress='" + uBIND_ADDRESS + "', " +
			  "iDebugLevel=" + MathRound(fDebugLevel) + ", " +
			  ")");
	vPyExecuteUnicode("sFoobar = '%s : %s' % (sys.last_type, sys.last_value,)");
	uRetval = uPySafeEval("sFoobar");
	if (StringFind(uRetval, "ERROR:", 0) >= 0) {
	    uRetval = "ERROR: ZmqChart.ZmqChart failed: "  + uRetval;
	    vPanic(uRetval);
	    return(-3);
	}
			  
	iCONTEXT = iPyEvalInt("id(ZmqChart.oCONTEXT)");
	GlobalVariableTemp("fPyZmqContext");
	GlobalVariableSet("fPyZmqContext", iCONTEXT);
	
        fPY_ZMQ_CONTEXT_USERS = 1.0;
	
    }
    GlobalVariableSet("fPyZmqContextUsers", fPY_ZMQ_CONTEXT_USERS);
    
    EventSetTimer(iTIMER_INTERVAL_SEC);
    vDebug("OnInit: fPyZmqContextUsers=" + fPY_ZMQ_CONTEXT_USERS);

    return (0);
}

/*
OnTimer is called every iTIMER_INTERVAL_SEC (10 sec.)
which allows us to use Python to look for Zmq inbound messages,
or execute a stack of calls from Python to us in Metatrader.
*/
void OnTimer() {
    string uRetval="";
    string uMessage;
    string uMess;
    string uInfo;
    string uType = "timer";
    string uMark;

    /* timer events can be called before we are ready */
    if (GlobalVariableCheck("fPyZmqContextUsers") == false) {
      return;
    }
    iCONTEXT = MathRound(GlobalVariableGet("fPyZmqContext"));
    if (iCONTEXT < 1) {
	vWarn("OnTimer: unallocated context");
        return;
    }
    vTrace("OnTimer: iCONTEXT=" +iCONTEXT);
    
    // FixMe: could use GetTickCount but we may not be logged in
    // but maybe TimeCurrent requires us to be logged in?
    string uTime = IntegerToString(TimeCurrent());
    // same as Time[0]
    datetime tTime=iTime(uSYMBOL, iTIMEFRAME, 0);
	
    uInfo = "0";
    uRetval = uPySafeEval(uCHART_ID+".eHeartBeat(0)");
    if (StringFind(uRetval, "ERROR: ", 0) >= 0) {
	uRetval = "ERROR: eHeartBeat failed: "  + uRetval;
	vWarn("OnTimer: " +uRetval);
	return;
    }
    // There may be sleeps for threads here
    // We may want to loop over zMq4PopQueue to pop many commands
    uRetval = uPySafeEval(uCHART_ID+".zMq4PopQueue()");
    if (StringFind(uRetval, "ERROR:", 0) >= 0) {
	uRetval = "ERROR: zMq4PopQueue failed: "  + uRetval;
	vWarn("OnTimer: " +uRetval);
	return;
    }

    // the uRetval will be empty if there is nothing to do.
    if (uRetval == "") {
	//vTrace("OnTimer: " +uRetval);
    } else {
	vDebug("OnTimer: Processing popped exec message: " + uRetval);
	uMess = zOTZmqProcessCmd(uRetval);
	if (uMess == "void|") {
	    // can be "void|" return value
	} else if (StringFind(uRetval, "cmd", 0) == 0) {
	    // if the command is cmd|  - return a value as a retval|
	    // We want the sMark from uRetval instead of uTime
	    // but we will do than in Python
	    uMark = "0";
	    uMess  = zOTLibSimpleFormatRetval("retval", uCHART_ID, 0, uMark, uMess);
	    eSendOnSpeaker("retval", uMess, uRetval);
	    vDebug("OnTimer: retvaled " +uMess);
	} else {
	    // if the command is exec| - dont return a value
	    vDebug("OnTimer: processed " +uMess);
	}
    }
    
    uMess  = zOTLibSimpleFormatTick(uType, uCHART_ID, 0, uTime, uInfo);
    eSendOnSpeaker("timer", uMess);
}

void OnTick() {
    static datetime tNextbartime;
    bool bNewBar=false;
    string uType;
    string uInfo;
    string uMess, uRetval;

    fPY_ZMQ_CONTEXT_USERS=GlobalVariableGet("fPyZmqContextUsers");
    if (fPY_ZMQ_CONTEXT_USERS < 0.5) {
	vWarn("OnTick: no context users");
        return;
    }
    iCONTEXT = MathRound(GlobalVariableGet("fPyZmqContext"));
    if (iCONTEXT < 1) {
	vWarn("OnTick: unallocated context");
        return;
    }

    // FixMe: could use GetTickCount but we may not be logged in
    // but maybe TimeCurrent requires us to be logged in?
    string uTime = IntegerToString(TimeCurrent());
    // same as Time[0]
    datetime tTime = iTime(uSYMBOL, iTIMEFRAME, 0);

    if (tTime != tNextbartime) {
        iBAR += 1; // = Bars - 100
	bNewBar = true;
	iTICK = 0;
	tNextbartime = tTime;
	uInfo = sBarInfo();
	uType = "bar";
    } else {
        bNewBar = false;
	iTICK += 1;
	uInfo = iTICK;
	uType = "tick";
    }

    uMess  = zOTLibSimpleFormatTick(uType, uCHART_ID, 0, uTime, uInfo);
    eSendOnSpeaker(uType, uMess);
    
}

void eSendOnSpeaker(string uType, string uMess, string uOriginCmd="") {
    string uRetval;
    if (uOriginCmd == "") {
	uMess = uCHART_ID +".eSendOnSpeaker('" +uType +"', '" +uMess +"')";
    } else {
	// This message is a reply in a cmd
	uMess = uCHART_ID +".eSendOnSpeaker('" +uType +"', '" +uMess
	    +"', '" +uOriginCmd +"')";
    }
    //vTrace("eSendOnSpeaker:  uMess: " +uMess);
    // the retval should be empty - otherwise its an error
    vPyExecuteUnicode(uMess);
    vPyExecuteUnicode("sFoobar = '%s : %s' % (sys.last_type, sys.last_value,)");
    uRetval=uPyEvalUnicode("sFoobar");
    if (StringFind(uRetval, "exceptions", 0) >= 0) {
	vWarn("eSendOnSpeaker: ERROR: " +uRetval);
	return;
    } else if (uRetval != " : ") {
	vDebug("eSendOnSpeaker:  WTF?" +uMess);
    } else {
	// pass
    }
}

void OnDeinit(const int iReason) {
    //? if (iReason == INIT_FAILED) { return ; }
    vTrace("OnDeinit: killing the timer");
    EventKillTimer();

    fPY_ZMQ_CONTEXT_USERS=GlobalVariableGet("fPyZmqContextUsers");
    if (fPY_ZMQ_CONTEXT_USERS < 1.5) {
	iCONTEXT = MathRound(GlobalVariableGet("fPyZmqContext"));
	if (iCONTEXT < 1) {
	    vWarn("OnDeinit: unallocated context");
	} else {
	    vInfo("OnDeinit: destroying the context");
	    vPyExecuteUnicode("ZmqChart.oCONTEXT.destroy()");
	    vPyExecuteUnicode("ZmqChart.oCONTEXT = None");
	}
	GlobalVariableDel("fPyZmqContext");
	
	GlobalVariableDel("fPyZmqContextUsers");
	vDebug("OnDeinit: deleted fPyZmqContextUsers");
	
	vPyDeInit();
    } else {
	fPY_ZMQ_CONTEXT_USERS -= 1.0;
	GlobalVariableSet("fPyZmqContextUsers", fPY_ZMQ_CONTEXT_USERS);
	vDebug("OnDeinit: decreased, value of fPyZmqContextUsers to: " + fPY_ZMQ_CONTEXT_USERS);
    }
    
    vDebug("OnDeinit: delete of the chart in Python");
    vPyExecuteUnicode(uCHART_ID +".vRemove()");    

}
