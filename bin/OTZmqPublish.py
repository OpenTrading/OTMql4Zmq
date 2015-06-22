# -*-mode: python; fill-column: 75; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-

# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/

"""
Usage: OTZmqPublish.py [options] commands...
Publish request commands to OTMql4Zmq. Give options on the commnd line,
and then it will enter a loop reading from the standard input to take
commands to send to an PyZmq enabled Mt4 (or anything else).

Arguments on the command line are the list of Topics to subscribe to at
the same time. By default 'retval' is subscribed to, but you could add
timer to the command line to see timer topics come back.

The commands on stdin are sent to PyZmq, and it replies by putting the
answer in the return subscription as a 'retval' topic.

IMPORTANT: do NOT run this until the expert has been loaded onto a chart.
It may prevent the expert from binding to the ports.

"""
import sys
import os
import json
import time
from optparse import OptionParser

import zmq

from OTLibLog import *

# should do something better if there are multiple clients
def sMakeMark():
    return "%15.5f" % time.time()

class MqlError(RuntimeError):
    pass

def oOptionParser():
    sUsage = __doc__.strip()
    parser = OptionParser(usage=sUsage)
    parser.add_option("-s", "--subport", action="store", dest="iListenerPort", type="int",
                      default=2027,
                      help="the TCP port number to subscribe to")
    parser.add_option("-p", "--pubport", action="store", dest="iSpeakerPort", type="int",
                      default=2028,
                      help="the TCP port number to publish to")
    parser.add_option("-a", "--address", action="store", dest="sIpAddress", type="string",
                      default="127.0.0.1",
                      help="the TCP address to subscribe on")
    parser.add_option("-C", "--chart", action="store", dest="sChartId", type="string",
                      default="ANY",
                      help="the chart ID")
    parser.add_option("-t", "--timeout", action="store", dest="iTimeout", type="int",
                      default=60,
                      help="timeout in seconds to wait for a reply (60)")
    parser.add_option("-e", "--exectype", action="store", dest="sExecType", type="string",
                      default="default",
                      help="exectype: one of cmd or exec or default (default)")
    parser.add_option("-v", "--verbose", action="store", dest="iVerbose", type="int",
                      default=2,
                      help="the verbosity, 0 for silent, up to 4 (1)")
    return parser

def lGetOptionsArgs():
    parser = oOptionParser()
    (oOptions, lArgs,) = parser.parse_args()

    assert int(oOptions.iListenerPort) > 0 and int(oOptions.iListenerPort) < 66000
    # if iSpeakerPort is > 0 then request a Zmq version query
    assert int(oOptions.iSpeakerPort) >= 0 and int(oOptions.iSpeakerPort) < 66000
    oOptions.iVerbose = int(oOptions.iVerbose)
    assert 0 <= oOptions.iVerbose <= 5
    assert oOptions.sIpAddress

    return (oOptions, lArgs,)

dPENDING=dict()
def sPushToPending(sMark, sRequest, oSenderPubSocket, sType, oOptions):
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
    oSenderPubSocket.send(sRequest)
    i = 1
    if oOptions and oOptions.iVerbose >= 1:
        iLen = len(sRequest)
        vDebug("%d Sent request of length %d: %s" % (i, iLen, sRequest))
    return ""

def bCloseContextSockets(oContext, oReceiverSubSocket, oSenderPubSocket, oOptions):
    oReceiverSubSocket.setsockopt(zmq.LINGER, 0)
    oReceiverSubSocket.close()
    oSenderPubSocket.setsockopt(zmq.LINGER, 0)
    oSenderPubSocket.close()
    if oOptions and oOptions.iVerbose >= 1:
        vDebug("destroying the context")
    sys.stdout.flush()
    oContext.destroy()
    return True

def lCreateContextSockets(oOptions):
    oContext = zmq.Context()
    oReceiverSubSocket = oContext.socket(zmq.SUB)
    s = oOptions.sIpAddress+":"+str(oOptions.iListenerPort)
    if oOptions.iVerbose >= 1:
        vInfo("Subscribing to: " + s)
    oReceiverSubSocket.connect("tcp://"+s)

    for sElt in oOptions.lTopics:
        oReceiverSubSocket.setsockopt(zmq.SUBSCRIBE, sElt)

    s = oOptions.sIpAddress + ":" + str(oOptions.iSpeakerPort)
    oSenderPubSocket = oContext.socket(zmq.PUB)
    if oOptions.iVerbose >= 1:
        vInfo("Requesting to:  " + s)
    oSenderPubSocket.connect("tcp://" + s)
    return (oContext, oReceiverSubSocket, oSenderPubSocket,)

def sDefaultExecType(sRequest):
    return "cmd"
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

def iMain():
    global dPENDING

    (oOptions, lArgs,) = lGetOptionsArgs()
    
    if not lArgs:
        # subscribe to everything
        lArgs = ['']
    oOptions.lTopics = lArgs
    
    oContext = None
    try:
        (oContext, oReceiverSubSocket, oSenderPubSocket,) = lCreateContextSockets(oOptions)

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
            sType = "cmd"

            sMarkIn = sMakeMark()
            sRetval = sPushToPending(sMarkIn, sRequest, oSenderPubSocket, sType, oOptions)
            iSec = 0
            # really need to fire this of in a thread
            # and block waiting for it to appear on
            # the retval queue
            while len(dPENDING.keys()) > 0 and iSec < oOptions.iTimeout:
                # zmq.NOBLOCK gives zmq.error.Again: Resource temporarily unavailable
                sTopic = ""
                time.sleep(10.0)
                iSec += 10
                sString = oReceiverSubSocket.recv()
                if not sString: continue
                
                lElts = sString.split('|')
                if len(lElts) <= 4:
                    vWarn("not enough | found in: %s" % (sString,))
                if sString.startswith('tick'):
                    print sString
                elif sString.startswith('timer'):
                    print sString
                elif sString.startswith('retval'):
                    print sString

                    sMarkOut = lElts[3]
                    if sMarkOut not in dPENDING.keys():
                        print "WARN: %s not found in: %r" % (sMarkOut, dPENDING.keys())
                        continue
                    del dPENDING[sMarkOut]
                        
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
       if oOptions and oOptions.iVerbose >= 1:
           vInfo("exiting")

    finally:
       if oContext:
           bCloseContextSockets(oContext, oReceiverSubSocket, oSenderPubSocket, oOptions)

    return(0)


if __name__ == '__main__':
    sys.exit(iMain())
