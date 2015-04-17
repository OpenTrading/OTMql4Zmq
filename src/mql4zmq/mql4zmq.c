// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-
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

// Include the original libzmq header file.
#include "zmq.h"

// Handle DSO symbol visibility. This is already defined in zmq.h, but we set it here again to protect against future changes to Microsoft Visual C++ detection methods.
#define ZMQ_EXPORT __declspec(dllexport)

// Setup the standard call specification keyword for the compiler.
#define WINAPI __stdcall

// Hello World test function.
ZMQ_EXPORT const char* WINAPI ping (const char* pong) {
	return(pong);
}

/******************************************************************************/
/*  0MQ versioning support.                                                   */
/******************************************************************************/
ZMQ_EXPORT void WINAPI mql4zmq_version (int *major, int *minor, int *patch) {
	zmq_version(major, minor, patch);
}

/******************************************************************************/
/*  0MQ errors.                                                               */
/******************************************************************************/
ZMQ_EXPORT int WINAPI mql4zmq_errno (void) {
	return zmq_errno();
}

ZMQ_EXPORT const char* WINAPI mql4zmq_strerror (int errnum) {
	return zmq_strerror(errnum);
}

/******************************************************************************/
/*  0MQ message definition.                                                   */
/******************************************************************************/
ZMQ_EXPORT int WINAPI mql4zmq_msg_init (zmq_msg_t *msg) {
	return zmq_msg_init(msg);
}

ZMQ_EXPORT int WINAPI mql4zmq_msg_init_size (zmq_msg_t *msg, size_t size) {
	return zmq_msg_init_size(msg, size);
}

// Used to satisfy zmq_msg_init_data requirement to have a function passed to it that will free the data buffer 
// provided when it is no longer needed. For more info on the 'free' call see:  http://www.cplusplus.com/reference/clibrary/cstdlib/free/
// 
// NOTICE: We are no longer using this (passing NULL instead) as it was causing windows to close MetaTrader due to 
//		   thinking it was a virus since we were clearing memory that was originally allocated MetaTrader and not mql4zmq.dll 
void release_buffer(void *data, void *hint) 
{ 
	free(data);
}

ZMQ_EXPORT int WINAPI mql4zmq_msg_init_data (zmq_msg_t *msg, void *data, size_t size) {
	return zmq_msg_init_data(msg, data, size, NULL, NULL);
}

ZMQ_EXPORT int WINAPI mql4zmq_msg_close (zmq_msg_t *msg) {
	return zmq_msg_close(msg);
}

ZMQ_EXPORT int WINAPI mql4zmq_msg_move (zmq_msg_t *dest, zmq_msg_t *src) {
	return zmq_msg_move(dest, src);
}

ZMQ_EXPORT int WINAPI mql4zmq_msg_copy (zmq_msg_t *dest, zmq_msg_t *src) {
	return zmq_msg_copy(dest, src);
}

ZMQ_EXPORT void* WINAPI mql4zmq_msg_data (zmq_msg_t *msg) {
	return zmq_msg_data(msg);
}

ZMQ_EXPORT size_t WINAPI mql4zmq_msg_size (zmq_msg_t *msg) {
	return zmq_msg_size(msg);
}

/******************************************************************************/
/*  0MQ infrastructure (a.k.a. context) initialisation & termination.         */
/******************************************************************************/
ZMQ_EXPORT void* WINAPI mql4zmq_init (int io_threads) {
	return zmq_init(io_threads);
}

ZMQ_EXPORT int WINAPI mql4zmq_term (void *context) {
	return zmq_term(context);
}

/******************************************************************************/
/*  0MQ socket definition.                                                    */
/******************************************************************************/
ZMQ_EXPORT void* WINAPI mql4zmq_socket (void *context, int type) {
	return zmq_socket(context, type);
}

ZMQ_EXPORT int WINAPI mql4zmq_close (void *s) {
	return zmq_close(s);
}

ZMQ_EXPORT int WINAPI mql4zmq_setsockopt (void *s, int option, const void *optval, size_t optvallen) {
	return zmq_setsockopt(s, option, optval, optvallen);
}

ZMQ_EXPORT int WINAPI mql4zmq_getsockopt (void *s, int option, void *optval, size_t *optvallen) {
	return zmq_getsockopt(s, option, optval, optvallen);
}

ZMQ_EXPORT int WINAPI mql4zmq_bind (void *s, const char *addr) {
	return zmq_bind(s, addr);
}

ZMQ_EXPORT int WINAPI mql4zmq_connect (void *s, const char *addr) {
	return zmq_connect(s, addr);
}

ZMQ_EXPORT int WINAPI mql4zmq_send (void *s, zmq_msg_t *msg, int flags) {
	return zmq_sendmsg (s, msg, flags);
}

ZMQ_EXPORT int WINAPI mql4zmq_recv (void *s, zmq_msg_t *msg, int flags) {
	return zmq_recvmsg(s, msg, flags);
}

/******************************************************************************/
/*  I/O multiplexing.                                                         */
/******************************************************************************/
ZMQ_EXPORT int WINAPI mql4zmq_poll (zmq_pollitem_t *items, int nitems, long timeout) {
	return zmq_poll(items, nitems, timeout);
}

/******************************************************************************/
/*  Built-in devices                                                          */
/******************************************************************************/
ZMQ_EXPORT int WINAPI mql4zmq_device (int device, void * insocket, void* outsocket) {
	return zmq_device(device, insocket, outsocket);
}

/******************************************************************************/
/*  A Couple Helper Functions For Building Apps More Quickly.		          */
/*  Taken from the Z-Guide file at: https://github.com/imatix/zguide/blob/master/examples/C/zhelpers.h
/******************************************************************************/

// Receive 0MQ string from socket and convert into C string
// Caller must free returned string. Returns NULL if the context
// is being terminated.
ZMQ_EXPORT const char* WINAPI mql4s_recv (void* socket, int flags) 
{
	// Strict "C" spec has to be followed because we outputing the function as 'extern "C"' (see mql4zmq.h).
	// Hence specifing our variables right away instead of inline.
	char* string;
	int size;

	// Initialize message.
    zmq_msg_t message;
    zmq_msg_init(&message);

	// Receive the inbound message.
	if (zmq_recvmsg (socket, &message, flags))
        return (NULL); // No message received

	// Retrive message size.
    size = zmq_msg_size(&message);

	// Initialize variable to hold the message.
	string = (char*) malloc (size + 1);

	// Retrive pointer to message data and store message in variable 'string'
	memcpy (string, zmq_msg_data (&message), size);
    
	// Deallocate message buffer.
	zmq_msg_close (&message);
    
	// Return the message.
	string [size] = 0;
	return (string);
}

// Convert C string to 0MQ string and send to socket
ZMQ_EXPORT int WINAPI mql4s_send (void *socket, char *text) 
{
	// Strict "C" spec has to be followed because we outputing the function as 'extern "C"' (see mql4zmq.h).
	// Hence specifing our variables right away instead of inline.
    int result;

	// Initialize message.
    zmq_msg_t message;

	// Set the message to have a spcified length.
    zmq_msg_init_size (&message, strlen (text));

	// Place the specified value of variable 'string' inside of the message buffer. 
    memcpy (zmq_msg_data (&message), text, strlen (text));

	// Stream the message to the specified socket.
	result = zmq_sendmsg (socket, &message, 0);

	// Deallocate the message.
    zmq_msg_close (&message);

	// Return the response of the zmq_sendmsg call. 0 is success, -1 is error.
    return (result);
}

// Sends string as 0MQ string, as multipart non-terminal
ZMQ_EXPORT int WINAPI mql4s_sendmore (void *socket, char *text) 
{
	// Strict "C" spec has to be followed because we outputing the function as 'extern "C"' (see mql4zmq.h).
	// Hence specifing our variables right away instead of inline.
    int result;

	// Initialize message.
    zmq_msg_t message;

	// Set the message to have a spcified length.
    zmq_msg_init_size (&message, strlen (text));

	// Place the specified value of variable 'string' inside of the message buffer. 
    memcpy (zmq_msg_data (&message), text, strlen (text));

	// Stream the message to the specified socket.
    result = zmq_sendmsg (socket, &message, ZMQ_SNDMORE);

	// Deallocate the message.
    zmq_msg_close (&message);

	// Return the response of the zmq_sendmsg call. 0 is success, -1 is error.
    return (result);
}
