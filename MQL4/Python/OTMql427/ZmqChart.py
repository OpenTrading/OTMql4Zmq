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
        self.oListenerRepSocket = None
        self.iReqRepPort = int(dParams.get('sSubPubPort', 2027))
        self.iSubPubPort = int(dParams.get('sReqRepPort', 2028))
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
        print "receiving on the listener "
        sys.stdout.flush()
        try:
            sBody = self.sRecvOnListener()
        except Exception , e:
            print "Error eHeartBeat on the listener "+str(e)
            print traceback.format_exc()
            sys.stdout.flush()
            raise
        if sBody:
            print "pushing eHeartBeat on the queue " + sBody
            self.eMq4PushQueue(sBody)
        elif self.oQueue.empty():
            sTopic = 'ignore'
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
            assert self.iReqRepPort, "eBindSpeaker: iReqRepPort is null"
            oSpeakerPubSocket.bind('tcp://%s:%d' % (self.sIpAddress, self.iReqRepPort,))
            time.sleep(0.1)
            self.oSpeakerPubSocket = oSpeakerPubSocket

    def eBindListener(self, lTopics=None):
        """
        We bind on our Metatrader end, and connect from the scripts.
        """
        if self.oListenerRepSocket is None:
            sys.stdout.flush()
            oListenerRepSocket = oCONTEXT.socket(zmq.REP)
            assert self.iSubPubPort, "eBindListener: iSubPubPort is null"
            sUrl = 'tcp://%s:%d' % (self.sIpAddress, self.iSubPubPort,)
            print "eBindListener: Binding REP to " +sUrl
            sys.stdout.flush()
            oListenerRepSocket.bind(sUrl)
            self.oListenerRepSocket = oListenerRepSocket

    # unused - unwired
    def eBindSubscribeListener(self, lTopics=None):
        """
        We bind on our Metatrader end, and connect from the scripts.
        """
        if self.oListenerSubSocket is None:
            print "creating a listener SUB socket " 
            sys.stdout.flush()
            oListenerSubSocket = oCONTEXT.socket(zmq.SUB)
            assert self.iSubPubPort, "eBindListener: iSubPubPort is null"
            sUrl = 'tcp://%s:%d' % (self.sIpAddress, self.iSubPubPort,)
            print "Binding SUB to " + sUrl
            sys.stdout.flush()
            oListenerSubSocket.bind(sUrl)
            time.sleep(0.1)
            if lTopics is None:
                lTopics = ['']
            for sElt in lTopics:
                oListenerSubSocket.setsockopt(zmq.SUBSCRIBE, sElt)
            self.oListenerSubSocket = oListenerSubSocket

    def eReturnOnSpeaker(self, sTopic, sMsg, sOrigin=None):
        return self.eSendOnSpeaker(sTopic, sMsg, sOrigin)
    
    def eSendOnSpeaker(self, sTopic, sMsg, sOrigin=None):
        if sOrigin:
	    # This message is a reply in a cmd
            lOrigin = sOrigin.split("|")
            assert lOrigin[0] in ['exec', 'cmd'], "eSendOnSpeaker: lOrigin[0] in ['exec', 'cmd'] " +repr(lOrigin)
            sMark = lOrigin[3]
            lMsg = sMsg.split("|")
            assert lMsg[0] == 'retval', "eSendOnSpeaker: lMsg[0] in ['retval'] " +repr(lMsg)
            lMsg[3] = sMark
	    # Replace the mark in the reply with the mark in the cmd
            sMsg = '|'.join(lMsg)
            
        if self.oSpeakerPubSocket is None:
            self.eBindSpeaker()
        assert self.oSpeakerPubSocket, "eSendOnSpeaker: oSpeakerPubSocket is null"
        self.oSpeakerPubSocket.send(sMsg)
        return ""

    def sRecvOnListener(self):
        if self.oListenerRepSocket is None:
            self.eBindListener()
        assert self.oListenerRepSocket, "sRecvOnListener: oListenerRepSocket is null"
        try:
            sRetval = self.oListenerRepSocket.recv(flags=zmq.NOBLOCK)
        except zmq.ZMQError:
            # zmq.error.Again
            iError = zmq.zmq_errno()
            if iError == zmq.EAGAIN:
                time.sleep(1.0)
            else:
                print "sRecvOnListener: ZMQError in Recv listener", iError, zmq.strerror(iError)
                sys.stdout.flush()
            sRetval = ""
        except Exception, e:
            print "sRecvOnListener: Failed Recv listener: " +str(e)
            sys.stdout.flush()
            sRetval = ""
        return sRetval

    def eReturnOnListener(self, sTopic, sMsg, sOrigin=None):
        return self.eSendOnListener(sTopic, sMsg, sOrigin=None)

    def eSendOnListener(self, sTopic, sMsg, sOrigin=None):
        # we may send back null strings
        if sOrigin and sMsg and sMsg != "null":
	    # This message is a reply in a cmd
            lOrigin = sOrigin.split("|")
            assert lOrigin[0] in ['exec', 'cmd'], "eSendOnSpeaker: lOrigin[0] in ['exec', 'cmd'] " +repr(lOrigin)
            sMark = lOrigin[3]
            lMsg = sMsg.split("|")
            assert lMsg[0] == 'retval', "eSendOnSpeaker: lMsg[0] in ['retval'] " +repr(lMsg)
            lMsg[3] = sMark
	    # Replace the mark in the reply with the mark in the cmd
            sMsg = '|'.join(lMsg)
            
        assert self.oListenerRepSocket, "eSendOnSpeaker: oListenerRepSocket is null"
        self.oListenerRepSocket.send(sMsg)
        return ""

    def bCloseContextSockets(self, oOptions):
        global oCONTEXT
        if self.oListenerRepSocket:
            self.oListenerRepSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oListenerRepSocket.close()
        if self.oSpeakerPubSocket:
            self.oSpeakerPubSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oSpeakerPubSocket.close()
        if oOptions and oOptions.iVerbose >= 1:
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

    assert lArgs, "comand line arguments are required"
    iReqRepPort = int(oOptions.sReqRepPort)
    assert iReqRepPort > 0 and iReqRepPort < 66000
    sIpAddress = oOptions.sIpAddress
    assert sIpAddress

    try:
        if oOptions.iVerbose >= 1:
            print "Publishing to: " +sIpAddress +":" +str(iReqRepPort) + \
                " with topic: " +oOptions.sTopic +" ".join(lArgs)
        o = ZmqChart('oUSDUSD_0_ZMQ_0', **oOptions.__dict__)
        sMsg = 'Hello'
        iMax = 10
        i = 0
        print "Sending: %s %d times " % (sMsg, iMax,)
        while i < iMax:
            # send a burst of 10 copies
            o.eSendOnSpeaker(oOptions.sTopic, lArgs[0])
            i += 1
        # print "Waiting for message queues to flush..."
        time.sleep(1.0)
    except KeyboardInterrupt:
        pass
    finally:
        o.bCloseContextSockets(oOptions)

if __name__ == '__main__':
    iMain()
