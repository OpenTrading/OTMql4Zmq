# -*-mode: python; py-indent-offset: 4; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-
# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/

"""
Usage: OTZmqSubscribe.py [options] [topics...]

Collect ticks from OTMql4Zmq

Arguments on the command line are the list of Topics to subscribe to on a listener at
the same time. By default everything ('') is subscribed to, but you could add
one or more of {{{timer, tick, retval, bar}}}  to the command line to see only
those topics.

MAYBE: do NOT run this until the expert has been loaded onto a chart.
It may (but shouldn't) prevent the expert from binding to the ports.
Also be sure to not leave it running between restarting Metatrader.

"""
import sys
import os
from datetime import datetime
from optparse import OptionParser
import time

import zmq

lKnownTypes = ['tick', 'cmd', 'retval', 'bar', 'timer']

def oOptionParser(sUsage):

    oParser = OptionParser(usage=sUsage)
    # We need to refactor with threads?
    oParser.add_option("-s", "--subport", action="store",
                       dest="iSubPubPort", type="int",
                       default=2027,
                       help="the TCP port number to subscribe to (default 2027)")
    # if iReqRepPort is > 0 then publish a Zmq version query
    oParser.add_option("-r", "--reqport", action="store",
                       dest="iReqRepPort", type="int",
                       default=2028,
                       help="the TCP port number to publish to (default 2028)")
    oParser.add_option("-a", "--address", action="store", dest="sHostAddress", type="string",
                       default="127.0.0.1",
                       help="the TCP address to subscribe on (default 127.0.0.1)")
    oParser.add_option("-C", "--chart", action="store", dest="sChartId", type="string",
                      default="ANY",
                      help="the chart ID")
    oParser.add_option("-t", "--timeout", action="store", dest="iTimeout", type="int",
                      default=60,
                      help="timeout in seconds to wait for a reply (60)")
    oParser.add_option('-P', "--mt4dir", action="store",
                      dest="sMt4Dir", default=r"/t/Program Files/MetaTrader",
                      help="directory for the installed Metatrader")
    oParser.add_option("-v", "--verbose", action="store", dest="iDebugLevel", type="string",
                       default="1",
                       help="the verbosity, 0 for silent 4 max (default 1)")
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
    from ZmqBinListener import ZmqMixin

    if not lArgs:
        # subscribe to everything
        lArgs = ['']
    elif lKnownTypes:
        for sElt in lArgs:
            assert sElt in lKnownTypes
    lTopics = lArgs

    iSubPubPort = oOptions.iSubPubPort
    assert 0 < int(iSubPubPort) < 66000

    sHostAddress = oOptions.sHostAddress
    assert sHostAddress

    oMixin = None
    try:
        oMixin = ZmqMixin(**oOptions.__dict__)
        #print("INFO: setting linger to 0")
        oMixin.oContext.linger = 0
        oMixin.eConnectToSubPub(lTopics)

        iReqRepPort = oOptions.iReqRepPort
        oReqRepSocket = None

        sTopic = ''
        while True:
            # was: sString = oMixin.oSubPubSocket.recv()
            sString = oMixin.sRecvOnSubPub()
            if not sString: continue
            sTopic = ""
            try:
                lElts = sString.split('|')
                if len(lElts) < 6:
                    print "WARN: somethings a little wrong: expected len>=6 " + \
                          repr(lElts)
                sCmd = lElts[0]
                # the first part of the message is the topic
                if sCmd not in lKnownTypes:
                    print "WARN: unrecognized beginning of message: " + \
                          repr(map(ord, sCmd))
                    # should check for bytes < 32 or > 128
                    for sElt in lKnownTypes:
                        if sCmd.endswith(sElt):
                            sCmd = sElt
                            break
                    if sCmd not in lKnownTypes:
                        continue
                    if sTopic == "":
                        sTopic = sCmd
            except Exception as e:
                print "ERROR: exception in recv: " +str(e)

            # if not sString: continue
            print "INFO: %s at %15.5f" % (sString , time.time())
            sTopic = ''
            # print map(ord, sString[:18])

    except KeyboardInterrupt:
        pass
    finally:
        if oMixin:
            oMixin.bCloseContextSockets()

if __name__ == '__main__':
    iMain()
