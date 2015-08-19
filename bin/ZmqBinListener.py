# -*-mode: python; py-indent-offset: 4; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-
# This Python script requires pyzmq
# http://pypi.python.org/packages/source/p/pyzmq/

import sys
import traceback
import time

import zmq

from OTMql427.ZmqListener import ZmqMixin

from OTLibLog import vError, vWarn, vInfo, vDebug, vTrace

dPENDING = dict()

class ZmqBinMixin(ZmqMixin):
    oContext = None

    def __init__(self, sChartId, **dParams):
        ZmqMixin.__init__(self, sChartId, **dParams)
    
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
                # FixMe: still need to read the null off self.oReqRepSocket?
                
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
