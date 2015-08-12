# -*-mode: python; py-indent-offset: 4; indent-tabs-mode: nil; encoding: utf-8-dos; coding: utf-8 -*-

"""
A ZmqChart object is a simple abstraction to encapsulate a Mt4 chart
that has a ZeroMQ context on it. There should be only one context for
the whole application, so it is set as the module variable oCONTEXT.

"""

import sys, logging
import time
import traceback

oLOG = logging


from Mq4Chart import Mq4Chart
from ZmqListener import ZmqMixin

# There's only one context in zmq
oCONTEXT = None

class ZmqChart(Mq4Chart, ZmqMixin):

    def __init__(self, sChartId, **dParams):
        global oCONTEXT

        self.sChartId = sChartId
        Mq4Chart.__init__(self, sChartId, **dParams)
        ZmqMixin.__init__(self, sChartId, **dParams)
        oCONTEXT = self.oContext
        assert oCONTEXT

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
            sBody = self.sRecvOnReqRep()
        except Exception as e:
            print "Error eHeartBeat on the listener " +str(e)
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


def iMain():
    # OTZmqPublish is in OTMql4Zmq/bin
    from OTZmqPublish import iMain as iOTZmqPublishMain
    return iOTZmqPublishMain()
