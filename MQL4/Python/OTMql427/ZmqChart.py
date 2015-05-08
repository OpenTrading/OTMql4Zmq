# -*-mode: python; py-indent-offset: 4; indent-tabs-mode: nil; encoding: utf-8-dos; coding: utf-8 -*-

"""
A ZmqChart object is a simple abstraction to encapsulate a Mt4 chart
that has a ZeroMQ context on it. There should be only one context for
the whole application, so it is set as the module variable oCONTEXT.

This module can be run from the command line to test Zmq with a listener
such as bin/OTZmqSubscribe.py. Give the message you want to publish
as arguments to this script, or --help to see the options.
"""

import sys, logging
import time
import traceback
import zmq

oLOG = logging

# There's only one context in zmq
oCONTEXT = None

from Mq4Chart import Mq4Chart

class ZmqChart(Mq4Chart):

    def __init__(self, sChartId, **dParams):
        global oCONTEXT

        Mq4Chart.__init__(self, sChartId, dParams)
        if oCONTEXT is None:
            oCONTEXT = zmq.Context()
        self.oSpeakerPubSocket = None
        self.oListenerSubSocket = None
        self.iSpeakerPort = dParams.get('iSpeakerPort', 0)
        self.iListenerPort = dParams.get('iListenerPort', 0)
        self.sIpAddress = dParams.get('sIpAddress', '127.0.0.1')
        self.sChartId = sChartId

    def eHeartBeat(self, iTimeout=0):
        """
        The heartbeat is usually called from the Mt4 OnTimer.
        We push a simple Print exec command onto the queue of things
        for Mt4 to do if there's nothing else happening. This way we get 
        a message in the Mt4 Log,  but with a string made in Python.
        """
        # while we are here flush stdout so we can read the log file
        # whilst the program is running
        print "recving on the listener "
        sys.stdout.flush()
        try:
            sBody = self.sRecvOnListener()
        except Exception , e:
            print "error on the listener "+str(e)
            print traceback.format_exc()
            sys.stdout.flush()
            raise
        if sBody:
            print "pushing on the queue " + sBody
            self.eMq4PushQueue(sBody)
        elif self.oQueue.empty():
            sTopic = 'exec'
            sMark = "%15.5f" % time.time()
            sMess = "%s|%s|0|%s|Print|PY: %s" % (sTopic, self.sChartId, sMark, sMark,)
            print "only pushing on the queue as there is nothing to do"
            sys.stdout.flush()
            self.eMq4PushQueue(sMess)
            
    def eBindSpeaker(self):
        """
        We bind on this Metatrader end, and connect from the scripts.
        """
        if self.oSpeakerPubSocket is None:
            oSpeakerPubSocket = oCONTEXT.socket(zmq.PUB)
            assert self.iSpeakerPort
            oSpeakerPubSocket.bind('tcp://%s:%d' % (self.sIpAddress, self.iSpeakerPort,))
            time.sleep(0.1)
            self.oSpeakerPubSocket = oSpeakerPubSocket

    def eBindListener(self):
        """
        We bind on our Metatrader end, and connect from the scripts.
        """
        if self.oListenerSubSocket is None:
            print "creating a listener SUB socket " 
            sys.stdout.flush()
            oListenerSubSocket = oCONTEXT.socket(zmq.SUB)
            assert self.iListenerPort
            sUrl = 'tcp://%s:%d' % (self.sIpAddress, self.iListenerPort,)
            print "Binding SUB to " + sUrl
            sys.stdout.flush()
            oListenerSubSocket.bind(sUrl)
            time.sleep(0.1)
            for sElt in ['cmd', 'exec']:
                oListenerSubSocket.setsockopt(zmq.SUBSCRIBE, sElt)
            self.oListenerSubSocket = oListenerSubSocket

    def eSendOnSpeaker(self, sTopic, sMsg):
        if self.oSpeakerPubSocket is None:
            self.eBindSpeaker()
        assert self.oSpeakerPubSocket
        self.oSpeakerPubSocket.send_multipart([sTopic, sMsg])
        return ""

    def sRecvOnListener(self):
        if self.oListenerSubSocket is None:
            self.eBindListener()
        assert self.oListenerSubSocket
        print "Recv on non-blocking listener"
        sys.stdout.flush()
        try:
            sTopic, sRetval = self.oListenerSubSocket.recv_multipart(flags=zmq.NOBLOCK)
            # sRetval = self.oListenerSubSocket.recv(flags=zmq.NOBLOCK)
            print "Recved on non-blocking listener: " +sRetval
            sys.stdout.flush()
        except Exception, e:
            # zmq.error.Again in 4.0.5 but not here
            print "Failed Recv listener: " +str(e)
            sys.stdout.flush()
            sRetval = ""
        return sRetval

    def bCloseContextSockets(self, lOptions):
        global oCONTEXT
        if self.oListenerSubSocket:
            self.oListenerSubSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oListenerSubSocket.close()
        if self.oSpeakerPubSocket:
            self.oSpeakerPubSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oSpeakerPubSocket.close()
        if lOptions and lOptions.iVerbose >= 1:
            print("INFO: destroying the context")
        sys.stdout.flush()
        time.sleep(0.1)
        oCONTEXT.destroy()
        oCONTEXT = None
        return True

def iMain():
    from ZmqArguments import oParseOptions 
    sUsage = __doc__.strip()
    oArgParser = oParseOptions(sUsage)
    oOptions = oArgParser.parse_args()
    lArgs = oOptions.lArgs

    assert lArgs
    iSpeakerPort = int(lOptions.sPubPort)
    assert iSpeakerPort > 0 and iSpeakerPort < 66000
    sIpAddress = lOptions.sIpAddress
    assert sIpAddress

    try:
        if lOptions.iVerbose >= 1:
            print "Publishing to: " +sIpAddress +":" +str(iSpeakerPort) + \
                " with topic: " +lOptions.sTopic +" ".join(lArgs)
        o = ZmqChart('oUSDUSD_0_ZMQ_0', **oOptions.__dict__)
        sMsg = 'Hello'
        iMax = 10
        i = 0
        print "Sending: %s %d times " % (sMsg, iMax,)
        while i < iMax:
            # send a burst of 10 copies
            o.eSendOnSpeaker(lOptions.sTopic, lArgs[0])
            i += 1
        # print "Waiting for message queues to flush..."
        time.sleep(1.0)
    except KeyboardInterrupt:
        pass
    finally:
        o.bCloseContextSockets(lOptions)

if __name__ == '__main__':
    iMain()
