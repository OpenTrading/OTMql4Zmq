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
import time
from optparse import OptionParser

import zmq

from OTLibLog import *

# should do something better if there are multiple clients
def sMakeMark():
    # from matplotlib.dates import date2num
    # from datetime import datetime
    # str(date2num(datetime.now()))
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
    parser.add_option("-C", "--chart", action="store", dest="sChart", type="string",
                      default="NULL",
                      help="the chart currency")
    parser.add_option("-P", "--period", action="store", dest="sPeriod", type="string",
                      default="0",
                      help="the chart period (0)")
    parser.add_option("-t", "--timeout", action="store", dest="iTimeout", type="int",
                      default=10,
                      help="timeout in seconds to wait for a reply (10)")
    parser.add_option("-e", "--exectype", action="store", dest="sExecType", type="string",
                      default="default",
                      help="exectype: one of cmd or exec or default (default)")
    parser.add_option("-v", "--verbose", action="store", dest="iVerbose", type="int",
                      default=2,
                      help="the verbosity, 0 for silent, up to 4 (1)")
    return parser

def lGetOptionsArgs():
    parser = oOptionParser()
    (lOptions, lArgs,) = parser.parse_args()

    assert int(lOptions.iListenerPort) > 0 and int(lOptions.iListenerPort) < 66000
    # if iSpeakerPort is > 0 then request a Zmq version query
    assert int(lOptions.iSpeakerPort) >= 0 and int(lOptions.iSpeakerPort) < 66000
    lOptions.iVerbose = int(lOptions.iVerbose)
    assert 0 <= lOptions.iVerbose <= 5
    assert lOptions.sIpAddress

    return (lOptions, lArgs,)

dPENDING=dict()
def sPushToPending(sMark, sRequest, oSenderPubSocket, sType, lOptions):
    """
    We push our requests onto a queue because some of them will be
    answered immediately (exec) and some of them will have the answer
    come back on a retval topic in the subcription.
    """
    global dPENDING

    dPENDING[sMark] = sRequest
    #
    #
    sRequest = sType +"|" +lOptions.sChart +"|" +lOptions.sPeriod +"|" +sMark +"|" +sRequest
    # zmq.error.ZMQError
    oSenderPubSocket.send_multipart([sType, sRequest])
    i = 1
    if lOptions and lOptions.iVerbose >= 1:
        iLen = len(sRequest)
        vDebug("%d Sent request %d %s" % (i, iLen, sRequest))
    time.sleep(1.0)
    return ""

def bCloseContextSockets(oContext, oReceiverSubSocket, oSenderPubSocket, lOptions):
    oReceiverSubSocket.setsockopt(zmq.LINGER, 0)
    oReceiverSubSocket.close()
    oSenderPubSocket.setsockopt(zmq.LINGER, 0)
    oSenderPubSocket.close()
    if lOptions and lOptions.iVerbose >= 1:
        vDebug("destroying the context")
    sys.stdout.flush()
    oContext.destroy()
    return True

def lCreateContextSockets(lOptions):
    oContext = zmq.Context()
    oReceiverSubSocket = oContext.socket(zmq.SUB)
    s = lOptions.sIpAddress+":"+str(lOptions.iListenerPort)
    if lOptions.iVerbose >= 1:
        vInfo("Subscribing to: " + s)
    oReceiverSubSocket.connect("tcp://"+s)

    for sElt in lOptions.lTopics:
        oReceiverSubSocket.setsockopt(zmq.SUBSCRIBE, sElt)

    s = lOptions.sIpAddress + ":" + str(lOptions.iSpeakerPort)
    oSenderPubSocket = oContext.socket(zmq.PUB)
    if lOptions.iVerbose >= 1:
        vInfo("Requesting to:  " + s)
    oSenderPubSocket.connect("tcp://" + s)
    return (oContext, oReceiverSubSocket, oSenderPubSocket,)

def sDefaultExecType(sRequest):
    if sRequest.startswith("Account") or \
        sRequest.startswith("Terminal") or \
        sRequest.startswith("Window") or \
        sRequest.startswith("Zmq") or \
        sRequest in ["Period","RefreshRates", "Symbol"]:
            return "exec"
    return "cmd"

def gRetvalToPython(sString, sMarkIn):
    # raises MqlError
    global dPENDING

    lElts = sString.split('|')
    if len(lElts) <= 3:
        # probably just for testing
        vWarn("not enough | found in: %s" % (sString,))
        return None
    
    sMarkOut = lElts[1]
    assert sMarkOut, "[1] not found in: %s" % (sString,)

    assert sMarkIn == sMarkOut, "%s marker not found in: %s" % (sMarkIn, sString,)
    if sMarkIn not in dPENDING:
        print("WARN: %s not in dPENDING" % (sMarkIn,))
    else:
        del dPENDING[sMarkIn]

    sType = lElts[2]
    sVal = lElts[3]
    if sType == 'string':
        sRetval = sVal
    elif sType == 'error':
        #? should I raise an error?
        raise MqlError(sVal)
    elif sType == 'datetime':
        #? how do I convert this
        # I think it's epoch seconds as an int
        # but what TZ? TZ of the server?
        # I'll treat it as a float like time.time()
        # but probably better to convert it to datetime
        sRetval = float(sVal)
    elif sType == 'int':
        sRetval = int(sVal)
    elif sType == 'double':
        sRetval = float(sVal)
    elif sType == 'none':
        sRetval = None
    elif sType == 'void':
        sRetval = None
    return sRetval

def iMain():
    global dPENDING

    (lOptions, lArgs,) = lGetOptionsArgs()
    
    if 'retval' not in lArgs:
        # always subscribe to retval
        lArgs.append('retval')
    lOptions.lTopics = lArgs
    
    oContext = None
    try:
        (oContext, oReceiverSubSocket, oSenderPubSocket,) = lCreateContextSockets(lOptions)

        i = 0
        while True:

            i += 1
            sys.stderr.write("Command: ")
            sRequest = sys.stdin.readline().strip()
            if not sRequest: break

            if lOptions.sExecType == "default":
                sType = sDefaultExecType(sRequest)
            elif lOptions.sExecType == "exec":
                # execs are executed immediately and return a result on the wire
                # They're things that take less than a tick to evaluate
                sType = "exec"
            else:
                sType = "cmd"

            sMarkIn = sMakeMark()
            sRetval = sPushToPending(sMarkIn, sRequest, oSenderPubSocket, sType, lOptions)
            if sRetval:
                # we got an immediate answer without having to wait for it on the SUB
                try:
                    gRetval = gRetvalToPython(sRetval, sMarkIn)
                except MqlError, e:
                    vError(sRequest, e)
                else:
                    vInfo(sRequest, gRetval)
                continue

            # really need to fire this of in a thread
            # and block waiting for it to appear on
            # the retval queue
            while len(dPENDING.keys()) > 0:
                # zmq.NOBLOCK gives zmq.error.Again: Resource temporarily unavailable
                sString = oReceiverSubSocket.recv()
                if not sString: continue
                if lOptions and lOptions.iVerbose >= 2:
                    vDebug("" + sString + "|" + sMakeMark())
                
                if sString.startswith('tick'):
                    print sString
                elif sString.startswith('timer'):
                    print sString
                elif sString.startswith('retval'):
                    try:
                        gRetval = gRetvalToPython(sString, sMarkIn)
                    except MqlError, e:
                        vError(sRequest, e)
                    else:
                        vInfo(sRequest, gRetval)
                else:
                    vWarn("Unrecognized message: " + sString)

                #? cleanup for timeout
                if len(dPENDING.keys()) == 0: break

    except KeyboardInterrupt:
       if lOptions and lOptions.iVerbose >= 1:
           vInfo("exiting")

    finally:
       if oContext:
           bCloseContextSockets(oContext, oReceiverSubSocket, oSenderPubSocket, lOptions)

    return(0)


if __name__ == '__main__':
    sys.exit(iMain())
