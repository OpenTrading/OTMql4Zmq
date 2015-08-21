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

def oOptionParser(sUsage):
    oParser = OptionParser(usage=sUsage)
    oParser.add_option("-s", "--subport", action="store",
                      dest="iSubPubPort", type="int",
                      default=2027,
                      help="the TCP port number to subscribe to")
    oParser.add_option("-r", "--reqport", action="store", dest="iReqRepPort", type="int",
                      default=2028,
                      help="the TCP port number to request to")
    oParser.add_option("-a", "--address", action="store", dest="sHostAddress", type="string",
                      default="127.0.0.1",
                      help="the TCP address to subscribe on")
    oParser.add_option("-C", "--chart", action="store", dest="sChartId", type="string",
                      default="ANY",
                      help="the chart ID")
    oParser.add_option("-t", "--timeout", action="store", dest="iTimeout", type="int",
                      default=60,
                      help="timeout in seconds to wait for a reply (60)")
    oParser.add_option("-e", "--exectype", action="store", dest="sExecType", type="string",
                      default="exec",
                      # FixMe:
                      help="exectype: one of cmd or exec or default (only exec works for now)")
    oParser.add_option('-P', "--mt4dir", action="store",
                      dest="sMt4Dir", default=r"/t/Program Files/MetaTrader",
                      help="directory for the installed Metatrader")
    oParser.add_option("-v", "--verbose", action="store", dest="iDebugLevel", type="int",
                      default=2,
                      help="the verbosity, 0 for silent, up to 4 (1)")
    return oParser

def lGetOptionsArgs():
    oParser = oOptionParser(__doc__.strip())
    (oOptions, lArgs,) = oParser.parse_args()

    assert int(oOptions.iSubPubPort) > 0 and int(oOptions.iSubPubPort) < 66000
    # if iReqRepPort is > 0 then request a Zmq version query
    assert int(oOptions.iReqRepPort) >= 0 and int(oOptions.iReqRepPort) < 66000
    oOptions.iDebugLevel = int(oOptions.iDebugLevel)
    assert 0 <= oOptions.iDebugLevel <= 5
    assert oOptions.sHostAddress

    sMt4Dir = oOptions.sMt4Dir
    if sMt4Dir:
        sMt4Dir = os.path.expanduser(os.path.expandvars(sMt4Dir))
        if not os.path.isdir(sMt4Dir):
            vWarn("sMt4Dir not found: " + sMt4Dir)
        else:
            sMt4Dir = os.path.join(sMt4Dir, 'MQL4', 'Python')
            if not os.path.isdir(os.path.join(sMt4Dir, 'OTMql427')):
                vWarn("sMt4Dir/MQL4/Python/OTMql427 not found: " + sMt4Dir)
            elif sMt4Dir not in sys.path:
                sys.path.insert(0, sMt4Dir)

    return (oOptions, lArgs,)

def iMain():
    # lGetOptionsArgs adds sMt4Dir/MQL4/Python to the sys.path
    (oOptions, lArgs,) = lGetOptionsArgs()
    # so lGetOptionsArgs must be called before this import
    from ZmqBinListener import ZmqBinMixin

    if not lArgs:
        # subscribe to everything
        lArgs = ['']
    lTopics = lArgs

    oMixin = None
    try:
        # sChartId is in oOptions
        oMixin = ZmqBinMixin(**oOptions.__dict__)
        oMixin.eConnectToSubPub(lTopics, iDir=zmq.SUB)
        oMixin.eConnectToReqRep(iDir=zmq.REQ)

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
            gRetval = oMixin.gCmdExec(sMarkIn, sRequest, sType, oOptions)
            print gRetval

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
