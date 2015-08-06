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
import traceback
from optparse import OptionParser

import zmq

from ZmqBinListener import ZmqMixin, dPENDING

from OTLibLog import vError, vWarn, vInfo, vDebug, vTrace

# should do something better if there are multiple clients
def sMakeMark():
    return "%15.5f" % time.time()

def sDefaultExecType(sRequest):
    if sRequest.startswith("Account") or \
        sRequest.startswith("Terminal") or \
        sRequest.startswith("Window") or \
        sRequest.startswith("Zmq") or \
        sRequest in ["Period","RefreshRates", "Symbol"]:
            return "exec"
    return "cmd"

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
    (oOptions, lArgs,) = lGetOptionsArgs()
    
    if not lArgs:
        # subscribe to everything
        lArgs = ['']
    lTopics = lArgs
    
    oMixin = None
    try:
        # sChartId is in oOptions
        oMixin = ZmqMixin(**oOptions.__dict__)
        oMixin.eConnectToSubPub(lTopics)
        oMixin.eConnectToReqRep()

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
            sRetval = oMixin.sPushToPending(sMarkIn, sRequest, sType, oOptions)
            iSec = 0
            # really need to fire this off in a thread
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
                        sString = oMixin.oSubPubSocket.recv(zmq.NOBLOCK)
                    except zmq.ZMQError as e:
                        # iError = zmq.zmq_errno()
                        iError = e.errno
                        if iError == zmq.EAGAIN:
                            time.sleep(1.0)
                            continue
                        if not sString: continue
                else:
                    sString = ""
                    # sent as a ReqRep but messages come on SubPub anyway
                    try:
                        sString = oMixin.oReqRepSocket.recv(zmq.NOBLOCK)
                    except zmq.error.Again:
                        try:
                            sString = oMixin.oSubPubSocket.recv(zmq.NOBLOCK)
                        except zmq.ZMQError as e:
                            # iError = zmq.zmq_errno()
                            iError = e.errno
                            if iError == zmq.EAGAIN:
                                time.sleep(1.0)
                                continue
                        # sent as a ReqRep and comes back on comes back on ReqRep
                        # I think this is blocking
                if not sString: continue
                oMixin.vPopFromPending(sString)
                #? cleanup for timeout
                if len(dPENDING.keys()) == 0: break

    except KeyboardInterrupt:
       if oOptions and oOptions.iDebugLevel >= 1:
           vInfo("exiting")

    except Exception as e:
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
