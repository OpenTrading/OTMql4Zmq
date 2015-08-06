# -*-mode: python; py-indent-offset: 4; indent-tabs-mode: nil; encoding: utf-8-dos; coding: utf-8 -*-

"""
This module can be run from the command line to test ZeroMQ
by listening to the broker for messages sent by a speaker
such as ZmqChart.py. For example, to see bars and timer topics do:
  python ZmqListener.py -v 4 bar timer
The known topics are: bar tick timer retval, and no options means listen for all.

Give  --help to see the options.
"""

import sys, logging
import time
import traceback

import zmq

from OTLibLog import vError, vWarn, vInfo, vDebug, vTrace
oLOG = logging

class ZmqMixin(object):
    oContext = None
    
    def __init__(self, sChartId, **dParams):
        self.dParams = dParams
        self.sChartId = sChartId
        if self.oContext is None:
            self.oContext = zmq.Context()
        self.oSubPubSocket = None
        self.oReqRepSocket = None
        self.iDebugLevel = dParams.get('iDebugLevel', 4)
        self.iSubPubPort = int(dParams.get('iSubPubPort', 2027))
        self.iReqRepPort = int(dParams.get('iReqRepPort', 2028))
        self.sHostAddress = dParams.get('sHostAddress', '127.0.0.1')

    def eBindSpeaker(self):
        """
        We bind on this Metatrader end, and connect from the scripts.
        This is called by Metatrader.
        """
        if self.oSubPubSocket is None:
            oSubPubSocket = self.oContext.socket(zmq.PUB)
            assert oSubPubSocket, "eBindSpeaker: oSubPubSocket is null"
            assert self.iSubPubPort, "eBindSpeaker: iSubPubPort is null"
            sUrl = 'tcp://%s:%d' % (self.sHostAddress, self.iSubPubPort,)
            vInfo("eBindListener: Binding REP to " +sUrl)
            sys.stdout.flush()
            oSubPubSocket.bind(sUrl)
            time.sleep(0.1)
            self.oSubPubSocket = oSubPubSocket

    def eBindListener(self, lTopics=None):
        """
        We bind on our Metatrader end, and connect from the scripts.
        """
        if self.oReqRepSocket is None:
            oReqRepSocket = self.oContext.socket(zmq.REP)
            assert oReqRepSocket, "eBindListener: oReqRepSocket is null"
            assert self.iReqRepPort, "eBindListener: iReqRepPort is null"
            sUrl = 'tcp://%s:%d' % (self.sHostAddress, self.iReqRepPort,)
            vInfo("eBindListener: Binding REP to " +sUrl)
            sys.stdout.flush()
            oReqRepSocket.bind(sUrl)
            self.oReqRepSocket = oReqRepSocket

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
            
        if self.oSubPubSocket is None:
            self.eBindSpeaker()
        assert self.oSubPubSocket, "eSendOnSpeaker: oSubPubSocket is null"
        self.oSubPubSocket.send(sMsg)
        return ""

    def sRecvOnListener(self):
        if self.oReqRepSocket is None:
            self.eBindListener()
        assert self.oReqRepSocket, "sRecvOnListener: oReqRepSocket is null"
        try:
            sRetval = self.oReqRepSocket.recv(flags=zmq.NOBLOCK)
        except zmq.ZMQError as e:
            # iError = zmq.zmq_errno()
            iError = e.errno
            if iError == zmq.EAGAIN:
                time.sleep(1.0)
            else:
                vWarn("sRecvOnListener: ZMQError in Recv listener: %d %s" % (
                    iError, zmq.strerror(iError),))
                sys.stdout.flush()
            sRetval = ""
        except Exception as e:
            vError("sRecvOnListener: Failed Recv listener: " +str(e))
            sys.stdout.flush()
            sRetval = ""
        return sRetval

    def eReturnOnReqRep(self, sTopic, sMsg, sOrigin=None):
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
            
        assert self.oReqRepSocket, "eSendOnSpeaker: oReqRepSocket is null"
        self.oReqRepSocket.send(sMsg)
        return ""

    def bCloseContextSockets(self):
        """
        same
        """
        if self.oReqRepSocket:
            self.oReqRepSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oReqRepSocket.close()
        if self.oSubPubSocket:
            self.oSubPubSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oSubPubSocket.close()
        if self.iDebugLevel >= 1:
            vInfo("destroying the context")
        sys.stdout.flush()
        time.sleep(0.1)
        self.oContext.destroy()
        self.oContext = None
        return True

if __name__ == '__main__':
    # OTZmqSubscribe is in OTMql4Zmq/bin
    from OTZmqSubscribe import iMain as iOTZmqSubscribeMain
    sys.exit(iOTZmqSubscribeMain())
    
