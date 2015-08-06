# -*-mode: python; py-indent-offset: 4; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-
# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/

import sys
import traceback
import time

import zmq

from OTLibLog import vError, vWarn, vInfo, vDebug, vTrace
from OTLibUtils import gRetvalToPython

dPENDING = dict()

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
            
    def eConnectToSubPub(self, lTopics):
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

    def eConnectToReqRep(self):
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
    
    def sRecvOnSubPub(self, iFlags=zmq.NOBLOCK):
        if self.oSubPubSocket is None:
            # was self.eBindListener()
            # needs lTopics: self.eConnectToSubPub(lTopics)
            pass
        assert self.oSubPubSocket, "sRecvOnSubPub: oSubPubSocket is null"
        try:
            sRetval = self.oSubPubSocket.recv(flags=iFlags)
        except zmq.ZMQError as e:
            # zmq4: iError = zmq.zmq_errno()
            iError = e.errno
            if iError == zmq.EAGAIN:
                #? This should only occur if iFlags are zmq.NOBLOCK
                time.sleep(1.0)
            else:
                vWarn("sRecvOnSubPub: ZMQError in Recv listener: %d %s" % (
                    iError, zmq.strerror(iError),))
                sys.stdout.flush()
            sRetval = ""
        except Exception as e:
            vError("sRecvOnSubPub: Failed Recv listener: " +str(e))
            sys.stdout.flush()
            sRetval = ""
        return sRetval

    def sPushToPending(self, sMark, sRequest, sType, oOptions):
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
        self.oReqRepSocket.send(sRequest)
        i = 1
        if oOptions and oOptions.iDebugLevel >= 1:
            iLen = len(sRequest)
            vDebug("%d Sent request of length %d: %s" % (i, iLen, sRequest))
        return ""

    def vPopFromPending(self, sString):
        global dPENDING
        
        lElts = sString.split('|')
        if len(lElts) <= 4:
            vWarn("not enough | found in: %s" % (sString,))
        if sString.startswith('tick'):
            print sString
        elif sString.startswith('timer'):
            print sString
        elif sString.startswith('retval'):
            sMarkOut = lElts[3]
            if sMarkOut not in dPENDING.keys():
                print "WARN: %s not found in: %r" % (sMarkOut, dPENDING.keys())
            else:
                del dPENDING[sMarkOut]
            sType = lElts[4]
            sVal = lElts[5]

            print "INFO: " +sMarkOut +" "+ sString
            if sType == "cmd":
                # there's still a null that comes back on ReqRep
                sNull = self.oReqRepSocket.recv()
                # zmq.error.ZMQError
            try:
                gRetval = gRetvalToPython(sString, lElts)
            except Exception as e:
                vError("gRetvalToPython " +sString +str(e))
            else:
                print gRetval
        else:
            vWarn("Unrecognized message: " + sString)

    def bCloseContextSockets(self):
        """
        same
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

