// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-

#property copyright "Copyright 2015 OpenTrading"
#property link      "https://github.com/OpenTrading/"
#property strict

#define INDICATOR_NAME          "PyTestZmqEA"

extern int iSUBPUB_PORT=2027;
extern int iREPREQ_PORT=2028;
// can replace this with the IP address of an interface - not lo
extern string uBIND_ADDRESS="127.0.0.1";
extern string uStdOutFile="../../Logs/_test_PyTestZmqEA.txt";
extern int iTIMER_INTERVAL_SEC = 10;

/*
This provided the function uBarInfo which puts together the
information you want send to a remote client on every bar.
Change to suit your own needs.
// #include <OTMql4/OTBarInfo.mqh>
*/

#include <OTMql4/OTLibLog.mqh>
#include <OTMql4/OTLibStrings.mqh>
#include <OTMql4/OTZmqProcessCmd.mqh>
#include <OTMql4/OTLibSimpleFormatCmd.mqh>
#include <OTMql4/OTLibJsonFormat.mqh>
#include <OTMql4/OTLibPy27.mqh>
#include <OTMql4/OTPyChart.mqh>
#include <OTMql4/ZmqConstants.mqh>

int iCONTEXT = -1;
double fPY_ZMQ_CONTEXT_USERS = 0.0;

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
string uCHART_ID = uChartName(uSafeString(uSYMBOL), Period(), ChartID(), iIsEA);
double fDebugLevel=0;

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

        uArg = "import zmq";
        iRetval = iPySafeExec(uArg);
        if (iRetval <= -2) {
            // VERY IMPORTANT: if the ANYTHING fails with SystemError we MUST PANIC
            ExpertRemove();
            return(-2);
        } else if (iRetval <= -1) {
            return(-1);
        }
        vPyExecuteUnicode("from OTMql427 import ZmqChart");
        vPyExecuteUnicode(uCHART_ID+"=ZmqChart.ZmqChart('" +uCHART_ID +"', " +
                          "iSubPubPort=" + iSUBPUB_PORT + ", " +
                          "iReqRepPort=" + iREPREQ_PORT + ", " +
                          "sHostAddress='" + uBIND_ADDRESS + "', " +
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
        if (iCONTEXT <= 0) {
            uRetval = "ERROR: ZmqChart.oCONTEXT failed: "  +iCONTEXT;
            vPanic(uRetval);
            return(-3);
        }

        GlobalVariableTemp("fPyZmqContext");
        GlobalVariableSet("fPyZmqContext", iCONTEXT);

        fPY_ZMQ_CONTEXT_USERS = 1.0;
        Comment(uCHART_ID);

    }
    GlobalVariableSet("fPyZmqContextUsers", fPY_ZMQ_CONTEXT_USERS);
    vInfo("OnInit: Incremented fZmqContextUsers to "+ MathRound(fPY_ZMQ_CONTEXT_USERS) + " with iCONTEXT: " + iCONTEXT);

    vPyExecuteUnicode("import zmq");
    uRetval = uPySafeEval("zmq.zmq_version()");
    if (StringFind(uRetval, "ERROR:", 0) >= 0) {
	uRetval = "ERROR: zmq.zmq_version failed: "  + uRetval;
	vPanic(uRetval);
	return(-3);
    }
    vDebug("OnInit: zmq_version=" +uRetval);
    
    EventSetTimer(iTIMER_INTERVAL_SEC);

    return (0);
}

string ePyZmqPopQueue(string uChartId) {
    string uIncoming, uOutgoing;

    // There may be sleeps for threads here
    // We may want to loop over zMq4PopQueue to pop many commands
    uIncoming = uPySafeEval(uChartId+".zMq4PopQueue()");
    if (StringFind(uIncoming, "ERROR:", 0) >= 0) {
        uIncoming = "ERROR: zMq4PopQueue failed: "  + uIncoming;
        vWarn("ePyZmqPopQueue: " +uIncoming);
        return(uIncoming);
    }

    // the uIncoming will be empty if there is nothing to do.
    if (uIncoming == "") {
        //vTrace("ePyZmqPopQueue: " +uIncoming);
    } else {
        // vTrace("ePyZmqPopQueue: Processing popped exec message: " + uIncoming);
        uOutgoing = zOTZmqProcessCmd(uIncoming);
        if (StringFind(uOutgoing, "void|", 0) >= 0) {
            // can be "void|" return value
        } else if (StringFind(uIncoming, "ignore|", 0) >= 0) {
            // can be "void|" return value
        } else if (StringFind(uIncoming, "cmd|", 0) >= 0) {
            // if the command is cmd|  - return a value as a retval|
            // FixMe: We want the sMark from uIncoming instead of uTime
            // but we will do than in Python
	    // WE INCLUDED THE SMARK
            uOutgoing  = zOTLibSimpleFormatRetval("retval", uChartId, 0, "", uOutgoing);
            vDebug("ePyZmqPopQueue: eSendOnSpeaker sending: " +uOutgoing);
            eSendOnSpeaker(uChartId, "retval", uOutgoing, uIncoming);
            eReturnOnListener(uChartId, "retval", "null", uIncoming);
        } else {
            // if the command is exec| - return as a REP on the listener
	    // WE INCLUDED THE SMARK
            uOutgoing  = zOTLibSimpleFormatRetval("retval", uChartId, 0, "", uOutgoing);
            vDebug("ePyZmqPopQueue: eReturnOnListener returning " +uOutgoing);
            eReturnOnListener(uChartId, "retval", uOutgoing, uIncoming);
        }
    }
    return("");
}

/*
OnTimer is called every iTIMER_INTERVAL_SEC (10 sec.)
which allows us to use Python to look for Zmq inbound messages,
or execute a stack of calls from Python to us in Metatrader.
*/
void OnTimer() {
    string uRetval="";
    string uMessage;
    string uMess, uInfo;
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

    // eHeartBeat first to see if there are any commands
    uRetval = uPySafeEval(uCHART_ID+".eHeartBeat(0)");
    if (StringFind(uRetval, "ERROR: ", 0) >= 0) {
        uRetval = "ERROR: eHeartBeat failed: "  + uRetval;
        vWarn("OnTimer: " +uRetval);
        return;
    }
    uRetval = ePyZmqPopQueue(uCHART_ID);
    if (uRetval != "") {
        vWarn("OnTimer: " +uRetval);
        // drop through
    }
    //vTrace("OnTimer: iCONTEXT=" +iCONTEXT);

    // FixMe: could use GetTickCount but we may not be logged in
    // but maybe TimeCurrent requires us to be logged in?
    // Add microseconds?
    string uTime = IntegerToString(TimeCurrent());
    // same as Time[0]
    datetime tTime=iTime(uSYMBOL, Period(), 0);

    uInfo = "json|" + jOTTimerInformation();
    uMess  = zOTLibSimpleFormatTimer(uType, uCHART_ID, 0, uTime, uInfo);
    eSendOnSpeaker(uCHART_ID, "timer", uMess, "");
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
    datetime tTime = iTime(uSYMBOL, Period(), 0);

    if (tTime != tNextbartime) {
        iBAR += 1; // = Bars - 100
        iTICK = 0;
        tNextbartime = tTime;
	uInfo = "json|" + jOTBarInformation(uSYMBOL, Period(), 0) ;
        uType = "bar";
        uMess  = zOTLibSimpleFormatBar(uType, uCHART_ID, 0, uTime, uInfo);
    } else {
        iTICK += 1;
	uInfo = "json|" + jOTTickInformation(uSYMBOL, Period()) ;
        uType = "tick";
        uMess  = zOTLibSimpleFormatTick(uType, uCHART_ID, 0, uTime, uInfo);
    }
    eSendOnSpeaker(uCHART_ID, uType, uMess, "");
}

void OnDeinit(const int iReason) {
    //? if (iReason == INIT_FAILED) { return ; }
    //vTrace("OnDeinit: killing the timer");
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
    Comment("");

}
