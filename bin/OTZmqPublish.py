# -*-mode: python; fill-column: 75; tab-width: 8; coding: utf-8-dos -*-


"""
Usage: OTZmqPublish.py [options] commands...

Publish commands to OTMql4Zmq

IMPORTANT: do NOT run this until the expert has been loaded onto a chart
and has received its first tick. It will prevent the expert from binding
to the Pub.Sub ports.

"""
import sys
import time
from optparse import OptionParser

# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/
# It MAY depend on the version of pyzmq AND
# the version of zmq that it is compiled against.

# For the moment we are compiling against zeromq-2.1.11
# because that is what Austen Conrad's code used.

import zmq

from OTLibLog import *

# should do something better if there are multiple clients
def sMakeMark():
    # from matplotlib.dates import date2num
    # from datetime import datetime
    # str(date2num(datetime.now()))
    return str(time.time())

class MqlError(RuntimeError):
    pass

def oOptionParser():
    sUsage = __doc__.strip()
    parser = OptionParser(usage=sUsage)
    parser.add_option("-s", "--subport", action="store", dest="iSubPort", type="int",
                      default=2027,
                      help="the TCP port number to subscribe to")
    parser.add_option("-p", "--pubport", action="store", dest="iPubPort", type="int",
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
    if lArgs:
       parser.error("You supply the message you want to send on stdin.")

    assert int(lOptions.iSubPort) > 0 and int(lOptions.iSubPort) < 66000
    # if iPubPort is > 0 then publish a Zmq version query
    assert int(lOptions.iPubPort) >= 0 and int(lOptions.iPubPort) < 66000
    lOptions.iVerbose = int(lOptions.iVerbose)
    assert 0 <= lOptions.iVerbose <= 5
    assert lOptions.sIpAddress

    return (lOptions, lArgs,)

dPENDING=dict()
def sPushToPending(sMark, sRequest, oPubSocket, sType, lOptions):
    global dPENDING
    
    dPENDING[sMark]=sRequest
    # 
    # 
    sRequest=sType +"|" +lOptions.sChart +"|" +lOptions.sPeriod +"|" +sMark +"|" +sRequest
    # zmq.error.ZMQError
    # Operation cannot be accomplished in current state
    oPubSocket.send(sRequest)
    i=1
    if lOptions and lOptions.iVerbose >= 1:
       vDebug("%d Sent request %s" % (i, sRequest))
    # zmq.NOBLOCK gives zmq.error.Again: Resource temporarily unavailable
    sRetval = oPubSocket.recv()
    return sRetval
 
def bCloseContextSockets(oContext, oSubSocket, oPubSocket, lOptions):
     oSubSocket.setsockopt(zmq.LINGER, 0)
     oSubSocket.close()
     oPubSocket.setsockopt(zmq.LINGER, 0)
     oPubSocket.close()
     if lOptions and lOptions.iVerbose >= 1:
        vDebug("destroying the context")
     sys.stdout.flush()
     oContext.destroy()
     return True

def lCreateContextSockets(lOptions):   
     oContext = zmq.Context()
     oSubSocket = oContext.socket(zmq.SUB)
     if lOptions.iVerbose >= 1:
        vInfo("Subscribing to: " + lOptions.sIpAddress + ":" + str(lOptions.iSubPort))
     oSubSocket.connect("tcp://"+lOptions.sIpAddress+":"+str(lOptions.iSubPort))

     for sElt in ['retval', 'tick']:
        oSubSocket.setsockopt(zmq.SUBSCRIBE, sElt)

     oPubSocket = oContext.socket(zmq.REQ)
     if lOptions.iVerbose >= 1:
        vInfo("Publishing to:  " + lOptions.sIpAddress + ":" + str(lOptions.iPubPort))
     oPubSocket.connect("tcp://" +lOptions.sIpAddress +":" +str(lOptions.iPubPort))
     return (oContext, oSubSocket, oPubSocket,)

def sDefaultExecType(sRequest):
    if sRequest.startswith("Account") or \
       sRequest.startswith("Terminal") or \
       sRequest.startswith("Window"): return "exec"
    if sRequest in ["Period","RefreshRates", "Symbol"]: return "exec"
    return "cmd"

def gRetvalToPython(sString, sMarkIn):
    # raises MqlError
    global dPENDING
    
    lElts=sString.split('|')
    assert len(lElts) > 3, "| not found in: %s" % (sString,)
    sMarkOut=lElts[1]
    assert sMarkOut, "[1] not found in: %s" % (sString,)
    
    assert sMarkIn == sMarkOut, "%s marker not found in: %s" % (sMarkIn, sString,)
    if sMarkIn not in dPENDING:
       print("WARN: %s not in dPENDING" % (sMarkIn,))
    else:
       del dPENDING[sMarkIn]
    
    sType=lElts[2]
    sVal=lElts[3]
    if sType == 'string':
       sRetval=sVal
    elif sType == 'error':
       #? should I raise an error?
       raise MqlError(sVal)
    elif sType == 'datetime':
       #? how do I convert this
       # I think it's epoch seconds as an int
       # but what TZ? TZ of the server?
       # I'll treat it as a float like time.time()
       # but probably better to convert it to datetime
       sRetval=float(sVal)
    elif sType == 'int':
       sRetval=int(sVal)
    elif sType == 'double':
       sRetval=float(sVal)
    elif sType == 'none':
       sRetval=None
    elif sType == 'void':
       sRetval=None
    return sRetval
 
def iMain():
    global dPENDING

    (lOptions, lArgs,) = lGetOptionsArgs()
    oContext=None
    try:
        (oContext, oSubSocket, oPubSocket,) = lCreateContextSockets(lOptions)

        i=0
        while True:
           
            i+=1
            sys.stderr.write("Command: ")
            sRequest = sys.stdin.readline().strip()
            if not sRequest: break
           
            if lOptions.sExecType == "default":
               sType=sDefaultExecType(sRequest)
            elif lOptions.sExecType == "exec":
               # execs are executed immediately and return a result on the wire
               # They're things that take less than a tick to evaluate
               sType="exec"
            else:
               sType="cmd"
            
            sMarkIn=sMakeMark()
            sRetval = sPushToPending(sMarkIn, sRequest, oPubSocket, sType, lOptions)
            if sRetval:
               # we got an immediate answer without having to wait for it on the SUB
               try:
                  gRetval=gRetvalToPython(sRetval, sMarkIn)
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
               sString = oSubSocket.recv()
               if not sString: continue
               if lOptions and lOptions.iVerbose >= 2:
                   vDebug("" + sString + "|" + sMakeMark())

               # otherwise its a tick
               if sString.startswith('tick'):
                  print sString
               elif sString.startswith('retval'):
                  try:
                     gRetval=gRetvalToPython(sString, sMarkIn)
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
            bCloseContextSockets(oContext, oSubSocket, oPubSocket, lOptions)

    return(0)


if __name__ == '__main__':
    sys.exit(iMain())
