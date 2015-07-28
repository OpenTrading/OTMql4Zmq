# -*-mode: python; py-indent-offset: 4; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-
# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/

import sys
import traceback
import time

import zmq

from OTLibLog import *

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
        self.iSubPubPort = dParams.get('iSubPubPort', 2027)
        self.iReqRepPort = dParams.get('iReqRepPort', 2028)
        self.sHostaddress = dParams.get('sHostaddress', '127.0.0.1')
            
    def eConnectToSpeaker(self, lTopics):
        """
        We bind on this Metatrader end, and connect from the scripts.
        This is called by the scripts.
        """
        if self.oSubPubSocket is None:
            oSubPubSocket = self.oContext.socket(zmq.SUB)
            s = self.sHostaddress +":"+str(self.iSubPubPort)
            if self.iDebugLevel >= 1:
                vInfo("Subscribing to: " + s +" with topics " +repr(lTopics))
            oSubPubSocket.connect("tcp://"+s)
            self.oSubPubSocket = oSubPubSocket
            for sElt in lTopics:
                self.oSubPubSocket.setsockopt(zmq.SUBSCRIBE, sElt)
        return ""

    def eConnectToListener(self, lTopics):
        """
        We bind on this Metatrader end, and connect from the scripts.
        This is called by the scripts.
        """
        if self.oReqRepSocket is None:
            s = self.sHostaddress + ":" + str(self.iReqRepPort)
            oReqRepSocket = self.oContext.socket(zmq.REQ)
            if self.iDebugLevel >= 1:
                vInfo("Requesting to:  " + s)
            oReqRepSocket.connect("tcp://" + s)
            self.oReqRepSocket = oReqRepSocket
        return ""
    
    def lCreateConnectSockets(self, lTopics):
        self.eConnectToSpeaker(lTopics)
        self.eConnectToListener(lTopics)
        return (self.oSubPubSocket, self.oReqRepSocket,)

    def bCloseContextSockets(self):
        """
        """
        if self.oSubPubSocket:
            self.oSubPubSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oSubPubSocket.close()
        if self.oReqRepSocket:
            self.oReqRepSocket.setsockopt(zmq.LINGER, 0)
            time.sleep(0.1)
            self.oReqRepSocket.close()
        if self.iDebugLevel >= 1:
            print "destroying the context"
        sys.stdout.flush()
        self.oContext.destroy()
        self.oContext = None
        return True

