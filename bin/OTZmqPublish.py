# -*-mode: python; fill-column: 75; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-

# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/

"""
Usage: OTZmqPublish.py [options] commands...
Publish request commands to OTMql4Zmq. Give options on the commnd line,
and then it will enter a loop reading from the standard input to take
commands to send to an PyZmq enabled Mt4 (or anything else).

Arguments on the command line are the list of Topics to subscribe to on a listener at
the same time. By default everything ('') is subscribed to, but you could add
one or more of {{{timer, tick, retval, bar}}}  to the command line to see only
those topics.

The script subscribes on the subscribe port and then sends requests to the requests
port. In both cases, the Mt4 binds the sockets, and this script connects.
The commands on stdin are sent to the Zmq enabled Mt4.

There are 2 types of requests that we can send:
    exec - the request is sent, and a reply is waited for on the requests port (REQ/REP)
    cmd  - the request is sent, and a reply is waited for on the subscibe port,
           where the reply is by put in the return subscription as a 'retval' topic.

The theory is that exec commands should be quick and not block the tick, and
the cmd requests are for longer running commands. In practice, the async cmd
doesn't always see the retval - it's sent and Mt4 sends the answer, but
we are not always seeing it. So the code is hardwired to exec for the moment.

We'll straighten this out later.

MAYBE: do NOT run this until the expert has been loaded onto a chart.
It may (but shouldn't) prevent the expert from binding to the ports.
Also be sure to not keave it running between restarting Metatrader.
"""
import sys
import os
import json
import time
from optparse import OptionParser

import zmq

from ZmqListener import ZmqMixin
from OTLibLog import *

# should do something better if there are multiple clients
def sMakeMark():
    return "%15.5f" % time.time()

class MqlError(RuntimeError):
    pass


dPENDING=dict()
def sPushToPending(sMark, sRequest, oReqRepSocket, sType, oOptions):
    """
    We push our requests onto a queue because some of them will be
    answered immediately (exec) and some of them will have the answer
    come back on a retval topic in the subcription.
    """
    global dPENDING

    dPENDING[sMark] = sRequest
    #
    #
    sRequest = sType +"|" +oOptions.sChartId +"|" +"0" +"|" +sMark +"|" +sRequest
    # , zmq.NOBLOCK
    oReqRepSocket.send(sRequest)
    i = 1
    if oOptions and oOptions.iDebugLevel >= 1:
        iLen = len(sRequest)
        vDebug("%d Sent request of length %d: %s" % (i, iLen, sRequest))
    return ""

def sDefaultExecType(sRequest):
    if sRequest.startswith("Account") or \
        sRequest.startswith("Terminal") or \
        sRequest.startswith("Window") or \
        sRequest.startswith("Zmq") or \
        sRequest in ["Period","RefreshRates", "Symbol"]:
            return "exec"
    return "cmd"

def gRetvalToPython(sString, lElts):
    # raises MqlError
    global dPENDING

    sType = lElts[4]
    sVal = lElts[5]
    if sVal == "":
        return ""
    if sType == 'string':
        gRetval = sVal
    elif sType == 'error':
        #? should I raise an error?
        raise MqlError(sVal)
    elif sType == 'datetime':
        #? how do I convert this
        # I think it's epoch seconds as an int
        # but what TZ? TZ of the server?
        # I'll treat it as a float like time.time()
        # but probably better to convert it to datetime
        gRetval = float(sVal)
    elif sType == 'int':
        gRetval = int(sVal)
    elif sType == 'json':
        gRetval = json.loads(sVal)
    elif sType == 'double':
        gRetval = float(sVal)
    elif sType == 'none':
        gRetval = None
    elif sType == 'void':
        gRetval = None
    else:
        print "WARN: unknown type i=%s in %r" % (sType, lElts,)
        return None
    return gRetval

def oOptionParser():
    parser = OptionParser(usage=__doc__.strip())
    parser.add_option("-s", "--subport", action="store",
                      dest="iSubPubPort", type="int",
                      default=2027,
                      help="the TCP port number to subscribe to")
    parser.add_option("-r", "--reqport", action="store", dest="iReqRepPort", type="int",
                      default=2028,
                      help="the TCP port number to request to")
    parser.add_option("-a", "--address", action="store", dest="sHostaddress", type="string",
                      default="127.0.0.1",
                      help="the TCP address to subscribe on")
    parser.add_option("-C", "--chart", action="store", dest="sChartId", type="string",
                      default="ANY",
                      help="the chart ID")
    parser.add_option("-t", "--timeout", action="store", dest="iTimeout", type="int",
                      default=60,
                      help="timeout in seconds to wait for a reply (60)")
    parser.add_option("-e", "--exectype", action="store", dest="sExecType", type="string",
                      default="exec",
                      # FixMe:
                      help="exectype: one of cmd or exec or default (only exec works for now)")
    parser.add_option("-v", "--verbose", action="store", dest="iDebugLevel", type="int",
                      default=2,
                      help="the verbosity, 0 for silent, up to 4 (1)")
    return parser

def lGetOptionsArgs():
    parser = oOptionParser()
    (oOptions, lArgs,) = parser.parse_args()

    assert int(oOptions.iSubPubPort) > 0 and int(oOptions.iSubPubPort) < 66000
    # if iReqRepPort is > 0 then request a Zmq version query
    assert int(oOptions.iReqRepPort) >= 0 and int(oOptions.iReqRepPort) < 66000
    oOptions.iDebugLevel = int(oOptions.iDebugLevel)
    assert 0 <= oOptions.iDebugLevel <= 5
    assert oOptions.sHostaddress

    return (oOptions, lArgs,)

def iMain():
    global dPENDING

    (oOptions, lArgs,) = lGetOptionsArgs()
    
    if not lArgs:
        # subscribe to everything
        lArgs = ['']
    lTopics = lArgs
    
    oMixin = None
    try:
        # sChartId is in oOptions
        oMixin = ZmqMixin(**oOptions.__dict__)
        (oSubPubSocket, oReqRepSocket,) = oMixin.lCreateConnectSockets(lTopics)

        i = 0
        while True:

            i += 1
            sys.stderr.write("Command: ")
            sRequest = sys.stdin.readline().strip()
            if not sRequest: break

            if oOptions.sExecType == "default":
                sType = sDefaultExecType(sRequest)
            elif oOptions.sExecType == "exec":
                # execs are executed immediately and return a result on the wire
                # They're things that take less than a tick to evaluate
                sType = "exec"
            else:
                sType = "cmd"
            # only exec really works right now - cmd misses the retval sometimes
            sType = "exec"

            sMarkIn = sMakeMark()
            sRetval = sPushToPending(sMarkIn, sRequest, oReqRepSocket, sType, oOptions)
            iSec = 0
            # really need to fire this of in a thread
            # and block waiting for it to appear on
            # the retval queue
            while len(dPENDING.keys()) > 0 and iSec < oOptions.iTimeout:
                # zmq.NOBLOCK gives zmq.error.Again: Resource temporarily unavailable
                sTopic = ""
                time.sleep(10.0)
                iSec += 10

                if sType == "cmd":
                    # sent as a ReqRep but comes back on SubPub
                    try:
                        sString = oSubPubSocket.recv(zmq.NOBLOCK)
                    except zmq.error.Again:
                        continue
                    if not sString: continue
                else:
                    sString = ""
                    # sent as a ReqRep but messages come on SubPub anyway
                    try:
                        sString = oReqRepSocket.recv(zmq.NOBLOCK)
                    except zmq.error.Again:
                        try:
                            sString = oSubPubSocket.recv(zmq.NOBLOCK)
                        except zmq.error.Again:
                            continue
                        # sent as a ReqRep and comes back on comes back on ReqRep
                        # I think this is blocking
                if not sString: continue
                
                lElts = sString.split('|')
                if len(lElts) <= 4:
                    vWarn("not enough | found in: %s" % (sString,))
                if sString.startswith('tick'):
                    print sString
                elif sString.startswith('timer'):
                    print sString
                elif sString.startswith('retval'):
                    sMarkOut = lElts[3]
                    if sMarkOut not in dPENDING.keys():
                        print "WARN: %s not found in: %r" % (sMarkOut, dPENDING.keys())
                    else:
                        del dPENDING[sMarkOut]
                    
                    print "INFO: ", sType, sMarkOut, sString
                    if sType == "cmd":
                        # there's still a null that comes back on ReqRep
                        sNull = oReqRepSocket.recv()
                        # zmq.error.ZMQError
                        
                    try:
                        gRetval = gRetvalToPython(sString, lElts)
                    except MqlError, e:
                        vError(sRequest, e)
                    else:
                        print gRetval
                else:
                    vWarn("Unrecognized message: " + sString)

                #? cleanup for timeout
                if len(dPENDING.keys()) == 0: break

    except KeyboardInterrupt:
       if oOptions and oOptions.iDebugLevel >= 1:
           vInfo("exiting")

    except Exception, e:
        vError(str(e) +"\n" + \
               traceback.format_exc(10) +"\n")
        sys.stdout.flush()
        sys.exc_clear()

    finally:
       if oMixin:
           oMixin.bCloseContextSockets()

    return 0


if __name__ == '__main__':
    sys.exit(iMain())
