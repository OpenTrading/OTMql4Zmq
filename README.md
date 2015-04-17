# OTMql4Zmq
## Open Trading Metaquotes4 ZeroMq Bridge

OTMql4Zmq - MQL4 bindings for ZeroMQ, the high-speed messaging protocol
for asynchronous communications between financial and trading applications.
https://github.com/OpenTrading/OTMql4Zmq/

With ZeroMQ http://zeromq.org/ you can:
* Connect your code in any language, on any platform.
* Carries messages across inproc, IPC, TCP, TIPC, multicast.
* Smart patterns like pub-sub, push-pull, and router-dealer.
* High-speed asynchronous I/O engines, in a tiny library.
* Backed by a large and active open source community.
* Supports every modern language and platform.
* Build any architecture: centralized, distributed, small, or large.
* Free software with full commercial support.

These bindings are based on the work by 2012 Austen Conrad:
https:///github.com/AustenConrad/mql4zmq
A copy of the original code, including precompiled dlls is
checked in in the directory `net/Git/github.com/AustenConrad/`.

#### Project History

From net/Git/github.com/AustenConrad/mql4zmq/mql4zmq.c:

    The reason for all of this is that MetaTrader is a visual basic
    application and therefore is written using the STDCALL calling
    convention while ZeroMQ dll EXPORT defaults to the standard C calling
    convention (CDECL). If not changed, a call to libzmq.dll from
    MetaTrader will result in the trading terminal crashing.
    
    Therefore, this file generates mql4zmq.dll which wraps each call the
    zmq.h exports when compiled as libzmq.dll (i.e. each function that has
    ZMQ_EXPORT preceeding it) as a STDCALL instead (i.e. __stdcall via
    WINAPI definition).
    
    Additionally, MetaTrader4 has limitations on datatypes and data
    structures that we attempt to resolve by having the wrapping function
    inputs being of a type and in a manner that will jive with MQL4.
    
    To avoid naming collisions with the original zmq.h definitions we
    renamed our exported functions with 'mql4' appended to the beginning
    of the name.  In the OTMql4Zmq.mqh we revert the names back to the
    original to reduce confusion when writing experts.

The source checked in to the `src/mql4zmq` directory is from:
`git clone -b MQ_610_ZMQ_4 --single-branch https://github.com/ungratefulson/mql4zmq`

This has the very simple changes needed to run against ZeroMQ 4.0.x.

### Pre-Release

**This is a work in progress - a developers' pre-release version.**

It works on builds > 6xx, but the documentation of the changes to the
original code still need writing, as well as more tests and testing on
different versions. ZeroMq 4.x is being tested with this commit now.
There are problems with corrupt messages; see the issue tracker:
https://github.com/OpenTrading/OTMql4Zmq/issues


The project wiki should be open for editing by anyone logged into GitHub:
**Please report any system it works or doesn't work on in the wiki:
include the Metatrader build number, the origin of the metatrader exe,
the Windows version, and the ZeroMq version and version of the Python pyzmq.**
This code in known to run under Linux Wine (1.7.x), so this project
bridges Metatrader to ZeroMq under Linux.

### Installation

For the moment there is no installer: just "git clone" or download the
zip from github.com and unzip into an empty directory. Then recursively copy
the folder MQL4 over the MQL4 folder of your Metatrader installation. It will
not overwrite any system files, and keeps its files in subdirectories
called `OTMql4`.

### Project

Please file any bugs in the issue tracker:
https://github.com/OpenTrading/OTMql4Zmq/issues

Use the Wiki to start topics for discussion:
https://github.com/OpenTrading/OTMql4Zmq/wiki
It's better to use the wiki for knowledge capture, and then we can pull
the important pages back into the documentation in the share/doc directory.
You will need to be signed into github.com to see or edit in the wiki.
## OTMql4Zmq Notes

### Changes

The source checked in to the `src/` directory is from:
`git clone -b MQ_610_ZMQ_4 --single-branch https://github.com/ungratefulson/mql4zmq`

This has the very simple changes needed to run against ZeroMQ 4.0.x.

