// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-

#property copyright "Copyright 2014 Open Trading"
#property link      "https://github.com/OpenTrading/"

#property show_inputs

#include <OTMql4/OTMql4Zmq.mqh>
#include <OTMql4/ZmqConstants.mqh>
/*
The best way of testing is to call uZmqProcessCmd
which tests Zmq as well as our ProcessCmd wrapper
*/
#include <OTMql4/OTZmqProcessCmd.mqh>

/*
We will put each test as a boolean external input so the user
can select which tests to run.
*/

extern bool bTestErrorMessages=true;

bool bAssertStrerrortEqual(int i, string u) {
  string uRetval = zmq_strerror(i);
  if (u == uRetval) return(true);
  Print(StringFormat("WARN: %d '%s' != '%s'", i, uRetval, zmq_strerror(i)));
  return(false);
}

string eTestErrorMessages() {
    /* returns 0 on success */
    int iErr = 0;
    if (bAssertStrerrortEqual(ZMQ_ENOTSUP, "Not supported") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_EPROTONOSUPPORT, "Protocol not supported") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_ENOBUFS, "No buffer space available") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_ENETDOWN, "Network is down") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_EADDRINUSE, "Address in use") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_EADDRNOTAVAIL, "Address not available") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_ECONNREFUSED, "Connection refused") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_EINPROGRESS, "Operation in progress") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_EFSM, "Operation cannot be accomplished in current state") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_ENOCOMPATPROTO, "The protocol is not compatible with the socket type") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_ETERM, "Context was terminated") == false) { iErr += 1; }
    if (bAssertStrerrortEqual(ZMQ_EMTHREAD, "No thread available") == false) { iErr += 1; }

    if (iErr > 0) return(StringFormat("WARN: TestErrorMessages %d failed", iErr));
    return("");
}

void OnStart() {
    string uRetval = "";
    if (bTestErrorMessages == true) {
       uRetval = eTestErrorMessages();
       if (uRetval == "") {
	 Print("INFO: TestErrorMessages passed");
       } else {
	 Print(uRetval);
       }
    }
}

void OnDeinit(const int reason) {
    return;
}
