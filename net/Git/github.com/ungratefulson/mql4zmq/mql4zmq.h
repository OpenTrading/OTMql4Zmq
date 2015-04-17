/*
	MQL4ZMQ - MQL4 bindings for ZeroMQ  
	
	(c) 2012 Austen Conrad. Any of this software, or any part thereof, is allowed as long as the use complies with GPL v3.0: http://www.gnu.org/licenses/gpl-3.0-standalone.html
	Additionally, no warrenty of any kind is made. Use software at own risk.

	===================================

	The reason for all of this is that MetaTrader is a visual basic application and therefore is written using the STDCALL calling 
	convention while ZeroMQ dll EXPORT defaults to the standard C calling convention (CDECL). If not changed, a call to 
	libzmq.dll from MetaTrader will result in the trading terminal crashing. 

	Therefore, this file generates mql4zmq.dll which wraps each call the zmq.h exports when compiled as libzmq.dll (i.e. each function
	that has ZMQ_EXPORT preceeding it) as a STDCALL instead (i.e. __stdcall via WINAPI definition).

	Additionally, MetaTrader4 has limitations on datatypes and data structures that we attempt to resolve by having the wrapping funtion
	inputs being of a type and in a manner that will jive with MQL4.

	NOTE: Remember to add a link to the "libzmq.lib" file that is created upon building of libzmq to the mql4zmq project via: Add => Existing Item => ../Debug/libzmq.lib
		  This .lib file exposes all of the exported functions of the libzmq.dll for use with our program as referenced per zmq.h.
		  Also add the "mql4zmq.def" file to the linker input via: Properties => Configuration Properties => Linker => Input => Module Definition File,
		  and to change the linker settings from "Windows" to "Console" via: Properties => Configuration Properties => Linker => System => Subsystem.

	NAMING NOTE: To avoid naming collisions with the original zmq.h definitions we renamed our exported functions with 'mql4' appended to the beginning of the name. 
				 In the mql4zmq.mqh we revert the names back to the original to reduce confusion when writing experts.

	libzmq.dll NOTE: After building the solution, copy ../../../lib/libzmq.dll to c:\Windows\SysWOW64\libzmq.dll so that our bindings and other applications can access ZeroMQ.

*/

//Setup for "C" linkage instead of "C++" linkage.
extern "C" {
	// Hello World test function.
	const char* ping (const char* pong);

	// zhelper functions.
	const char* mql4s_recv (void* socket, int flags);
	int mql4s_send (void *socket, char *text);
	int mql4s_sendmore (void *socket, char *text);
}