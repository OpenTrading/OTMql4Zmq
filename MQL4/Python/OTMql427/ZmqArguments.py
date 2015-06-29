# -*-mode: python; py-indent-offset: 4; indent-tabs-mode: nil; encoding: utf-8-dos; coding: utf-8 -*-

"""
This file declares oParseOptions in a separate file so that the
arguments parsing can be uniform between applications that use it.

"""

from argparse import ArgumentParser
from optparse import OptionParser

def oParseOptions(sUsage):
    """
    Look at the bottom of ZmqChart.py for iMain
    functions that use the oParseOptions that is returned here.
    This function returns an ArgumentParser instance, so that you
    can override it before you call it to parse_args.
    """
    oArgParser = ArgumentParser(description=sUsage)
    oArgParser.add_argument("-a", "--address", action="store",
                            dest="sIpAddress",
                            default="127.0.0.1",
                            help="the TCP address to subscribe on (default 127.0.0.1)")
    oArgParser.add_argument("-s", "--subport", action="store",
                            dest="sSubPubPort",
                            default="2027",
                            help="the TCP port number to subscribe to (default 2027)")
    oArgParser.add_argument("-r", "--reqport", action="store",
                            dest="sReqRepPort",
                            default="2028",
                            help="the TCP port number to request to (default 2028)")
    oArgParser.add_argument("-v", "--verbose", action="store",
                            dest="iVerbose",
                            type=int,
                            default=1,
                            help="the verbosity, 0 for silent 4 max (default 1)")
    return(oArgParser)
