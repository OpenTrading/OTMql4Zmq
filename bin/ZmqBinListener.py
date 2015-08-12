# -*-mode: python; py-indent-offset: 4; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-
# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/

import sys
import traceback
import time

import zmq

from OTLibLog import vError, vWarn, vInfo, vDebug, vTrace

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
        self.sHostAddress = dParams.get('sHostAddress', '127.0.0.1')

    def eBindToSub(self):
        return self.eBindToSubPub(iDir=zmq.SUB)
    
    def eBindToPub(self):
        return self.eBindToSubPub(iDir=zmq.PUB)
    
    def eBindToSubPub(self, iDir=zmq.PUB):
        """
        We bind on this Metatrader end, and connect from the scripts.
        This is called by Metatrader.
        """
        if self.oSubPubSocket is None:
            assert iDir in [zmq.PUB, zmq.SUB]
            oSubPubSocket = self.oContext.socket(iDir)
            assert oSubPubSocket, "eBindToSub: oSubPubSocket is null"
            assert self.iSubPubPort, "eBindToSub: iSubPubPort is null"
            sUrl = 'tcp://%s:%d' % (self.sHostAddress, self.iSubPubPort,)
            vInfo("eBindToSub: Binding to SUB " +sUrl)
            sys.stdout.flush()
            oSubPubSocket.bind(sUrl)
            time.sleep(0.1)
            self.oSubPubSocket = oSubPubSocket

    def eConnectToSubPub(self, lTopics, iDir=zmq.SUB):
        """
        We bind on this Metatrader end, and connect from the scripts.
        This is called by the scripts.
        """

        if self.oSubPubSocket is None:
            assert iDir in [zmq.PUB, zmq.SUB]
            oSubPubSocket = self.oContext.socket(iDir)
            s = self.sHostAddress +":"+str(self.iSubPubPort)
            oSubPubSocket.connect("tcp://"+s)
            self.oSubPubSocket = oSubPubSocket
            if iDir == zmq.SUB:
                if self.iDebugLevel >= 1:
                    vInfo("Subscribing to: " + s +" with topics " +repr(lTopics))
                for sElt in lTopics:
                    self.oSubPubSocket.setsockopt(zmq.SUBSCRIBE, sElt)
            else:
                if self.iDebugLevel >= 1:
                    vInfo("Publishing to: " + s)

        return ""

    def eConnectToReq(self):
        return self.eConnectToReqRep(iDir=zmq.REQ)

    def eConnectToRep(self):
        return self.eConnectToReqRep(iDir=zmq.REP)

    def eConnectToReqRep(self, iDir):
        """
        We bind on this Metatrader end, and connect from the scripts.
        """
        if self.oReqRepSocket is None:
            assert iDir in [zmq.REQ, zmq.REP]
            oReqRepSocket = self.oContext.socket(iDir)
            assert oReqRepSocket, "eConnectToReqRep: oReqRepSocket is null"
            assert self.iReqRepPort, "eConnectToReqRep: iReqRepPort is null"
            sUrl = 'tcp://%s:%d' % (self.sHostAddress, self.iReqRepPort,)
            vInfo("eConnectToReqRep: Connecting to %d: %s" % (iDir, sUrl,))
            sys.stdout.flush()
            oReqRepSocket.connect(sUrl)
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

    def gCmdExec(self, sMarkIn, sRequest, sType, oOptions, iFlag=zmq.NOBLOCK):
        global dPENDING

        sRetval = self.sPushToPending(sMarkIn, sRequest, sType, oOptions)
        iSec = 0
        gRetval = ""
        # really need to fire this off in a thread
        # and block waiting for it to appear on
        # the retval queue
        while len(dPENDING.keys()) > 0 and iSec < oOptions.iTimeout:
            # zmq.NOBLOCK gives zmq.error.Again: Resource temporarily unavailable
            if iFlag > 0:
                time.sleep(10.0)
                iSec += 10

            sString = ""
            if sType == "cmd":
                # sent as a ReqRep but comes back on SubPub
                try:
                    sString = self.oSubPubSocket.recv(iFlag)
                except zmq.ZMQError as e:
                    # iError = zmq.zmq_errno()
                    iError = e.errno
                    if iError == zmq.EAGAIN:
                        time.sleep(1.0)
                        iSec += 1
                        continue
            else:
                # sent as a ReqRep - why not block if in a thread?
                try:
                    sString = self.oReqRepSocket.recv(iFlag)
                except zmq.error.Again:
                    try:
                        sString = self.oSubPubSocket.recv(iFlag)
                    except zmq.ZMQError as e:
                        # iError = zmq.zmq_errno()
                        iError = e.errno
                        if iError == zmq.EAGAIN:
                            time.sleep(1.0)
                            iSec += 1
                            continue
                    # sent as a ReqRep and comes back on comes back on ReqRep
                    # I think this is blocking
            if not sString: continue
            gRetval = self.zPopFromPending(sString)
            #? cleanup for timeout
            if len(dPENDING.keys()) == 0: break
        return gRetval

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

    def zPopFromPending(self, sString):
        from OTMql427.SimpleFormat import gRetvalToPython
        global dPENDING

        lElts = sString.split('|')
        if len(lElts) <= 4:
            vWarn("not enough | found in: %s" % (sString,))
            return ""

        if sString.startswith('tick') or sString.startswith('timer'):
            print sString
            return ""

        if sString.startswith('retval'):
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
                gRetval = gRetvalToPython(lElts)
            except Exception as e:
                vError("zPopFromPending: error in gRetvalToPython " +sString +str(e))
            else:
                return gRetval
        else:
            vWarn("Unrecognized message: " + sString)
        return ""

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
    bCloseConnectionSockets = bCloseContextSockets
