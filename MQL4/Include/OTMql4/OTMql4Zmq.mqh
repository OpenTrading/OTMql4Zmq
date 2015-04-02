// -*-mode: c++; fill-column: 75; tab-width: 8; coding: utf-8-dos -*-

#property copyright "Copyright © 2012, Austen Conrad anf Open Trading"
#property link      "https://github.com/OpenTrading/"

#import "kernel32.dll"
   int lstrlenA(int);
   void RtlMoveMemory(uchar & arr[], int, int);
   int LocalFree(int); // May need to be changed depending on how the DLL allocates memory
#import

#import "mql4zmq.dll"
//+--------------------------------------------------------------------------------+
//| mql4zmq.dll exported functions with datatypes reconfigured for 
//| MetaTrader 4's reduced type set. The intention is to not call these
//| diretly. Please use renamed versions in next section to reduce confusion.     
//|
//| Type Changes: 
//|                zmq_msg_t => int
//|                const char => string
//|                size_t => int
//|                void (if it's a param that's passed) => string    
//|                zmq_free_fn => int                        
//+--------------------------------------------------------------------------------+

// Tests.
int ping(uchar &pong[]);

// Version.
void mql4zmq_version(int &major[],int &minor[],int &patch[]);

// Errors.
int mql4zmq_errno();
int mql4zmq_strerror(int errnum);

// Messages.
int mql4zmq_msg_init(int &msg[]);
int mql4zmq_msg_init_size (int &msg[], int iSize);
int mql4zmq_msg_init_data (int &msg[], uchar &data[], int iSize);
int mql4zmq_msg_close (int &msg[]);
int mql4zmq_msg_move (int dest, int src);
int mql4zmq_msg_copy (int dest, int src);
//? was string
int mql4zmq_msg_data (int &msg[]);
int mql4zmq_msg_size (int &msg[]);

// Infrastructure.
int mql4zmq_init (int io_threads);
int mql4zmq_term (int context);

// Sockets.
int mql4zmq_socket (int context, int type);
int mql4zmq_close (int socket);
int mql4zmq_setsockopt (int socket, int option, uchar & optval[], int optvallen);
int mql4zmq_getsockopt (int socket, int option, uchar & optval[], int optvallen);
int mql4zmq_bind (int socket, uchar & addr[]);

int mql4zmq_connect (int socket, uchar &addr[]);
int mql4zmq_send (int socket, int &msg[], int flags);
int mql4zmq_recv (int socket, int &msg[], int flags);

// I/O multiplexing.
int mql4zmq_poll (int items, int nitems, int timeout);

// Built-in devices.
int mql4zmq_device (int device, int insocket, int outsocket);

// Helper Functions.
// now int - was string
int mql4s_recv (int socket, int flags);
int mql4s_send (int socket, uchar &text[]); 
int mql4s_sendmore (int socket, uchar &text[]); 
#import

void vStringToCharArray0(string uData, uchar&sCharData[]) {
    int ansiLength = StringLen(uData);
    StringToCharArray(uData, sCharData);
}

void vStringToCharArray(string uData, uchar&sCharData[]) {
    int ansiLength = StringLen(uData);
    StringToCharArray(uData, sCharData);
    int iSpos=0;
    uchar sChar;
    //int iChar;
    while (iSpos < ansiLength) {
      sChar = sCharData[iSpos];
      if (sChar < 32 || sChar > 127) {
	  Print("ERROR: Illegal char " + IntegerToString((int)sChar) + " in " + uData);
	  break;
	}
      iSpos=iSpos+1;
    }
}

void vStringToCharArray3(string uData, uchar&sCharData[]) {
    int ansiLength = StringLen(uData);
    StringToCharArray(uData, sCharData);
    int iSpos=0;
    // Unicode to ANSI Method 2: Convert Unicode string to ANSI string
    ArrayResize(sCharData, ansiLength + 1);
    int iUpos=0;
    while (iUpos < ansiLength) {
        //uchar typecasted because each double byte char is actually one byte
        sCharData[iSpos]=uchar(StringGetCharacter(uData, iUpos));
        iUpos=iUpos+2;
        iSpos=iSpos+1;
    }
    sCharData[iSpos + 1] = (uchar)0x00;
}

//+---------------------------------------------------------------------------------+
//| Renaming of functions to original naming structure. Use these when buiding 
//| your Expert Advisors so that we are consistant with ZeroMQ Naming conventions.     
//+---------------------------------------------------------------------------------+

string zmq_ping(string uSource)
{
   uchar sCharData[];
   vStringToCharArray(uSource, sCharData);
   uchar sCharArray[];
   // Call the DLL function and get its block of string memory as an int pointer to the
   // memory rather than as a string    
   int recvPtr = ping(sCharData);
   // Get the length of the string 
   int iMessLen = lstrlenA(recvPtr);   

   // if message length is 0, leave.  
   if (iMessLen < 1) {
	Print("zmq_ping: Warning! Pong Message has zero length.");
 	return("");
   }
 
   // Create a uchar[] array whose size is the string length (plus null terminator)
   ArrayResize(sCharArray, iMessLen);
   
   // Use the Win32 API to copy the string from the block returned by the DLL
   // into the uchar[] array   
   RtlMoveMemory(sCharArray, recvPtr, iMessLen);
   //?ArrayCopy(sCharArray, recvPtr, iMessLen+1);
   // Convert the uchar[] array to a message string
   string uMessage = CharArrayToString(sCharArray);
   
   // Free the string memory returned by the DLL.
   // This step can be removed but, without it,
   // there will be a memory leak.
   // The correct method for freeing the string
   // *depends on how the DLL allocated the memory*
   // The following assumes that the DLL has used LocalAlloc
   // (or an indirect equivalent). If not,
   // then the following line may not fix the leak, and may even cause a crash.   
   LocalFree(recvPtr);
   return(uMessage);
}


// Version.
void zmq_version(int &major[],int &minor[],int &patch[]) 
{
   mql4zmq_version(major,minor,patch);
}

// Errors.
int zmq_errno()
{
   return(mql4zmq_errno());
}

string zmq_strerror(int errnum)
{
   uchar sCharArray[];
   // Call the DLL function and get its block of string memory as an int pointer to the
   // memory rather than as a string    
   int recvPtr = mql4zmq_strerror(errnum);
   // Get the length of the string 
   int iMessLen = lstrlenA(recvPtr);   

   // if message length is 0, leave.  
   if (iMessLen < 1) {
	Print("zmq_strerror: Warning! Error Message has zero length.");
 	return("");
   }
   Print("iMessLen: "+iMessLen);
 
   // Create a uchar[] array whose size is the string length (plus null terminator)
   ArrayResize(sCharArray, iMessLen+1);
   
   // Use the Win32 API to copy the string from the block returned by the DLL
   // into the uchar[] array   
   RtlMoveMemory(sCharArray, recvPtr, iMessLen+1);
   //?ArrayCopy(sCharArray, recvPtr, iMessLen+1);
   // Convert the uchar[] array to a message string
   string uMessage = CharArrayToString(sCharArray);
   
   // Free the string memory returned by the DLL.
   // This step can be removed but, without it,
   // there will be a memory leak.
   // The correct method for freeing the string
   // *depends on how the DLL allocated the memory*
   // The following assumes that the DLL has used LocalAlloc
   // (or an indirect equivalent). If not,
   // then the following line may not fix the leak, and may even cause a crash.   
   //LocalFree(recvPtr);
   return(uMessage);
}

// Messages.
int zmq_msg_init(int &msg[])
{
   return(mql4zmq_msg_init(msg));
}

int zmq_msg_init_size (int &msg[], int iSize)
{
   return(mql4zmq_msg_init_size(msg, iSize));
}

int zmq_msg_init_data (int &msg[], string data, int iSize)
{
   uchar sCharData[];
   vStringToCharArray(data, sCharData);
   return(mql4zmq_msg_init_data(msg, sCharData, iSize));
}

int zmq_msg_close (int &msg[])
{
   return(mql4zmq_msg_close(msg));
}

int zmq_msg_move (int dest, int src)
{
   return(mql4zmq_msg_move(dest, src));
}

int zmq_msg_copy (int dest, int src)
{
   return(mql4zmq_msg_copy (dest, src));
}

string zmq_msg_data (int &msg[])
{
   uchar sCharArray[];
   // Call the DLL function and get its block of string memory as an int pointer to the
   // memory rather than as a string    
   int recvPtr = mql4zmq_msg_data(msg);
   // Get the length of the string 
   int iMessLen = mql4zmq_msg_size(msg);   

   // if message length is 0, leave.  
   if (iMessLen < 1) {
//	Print("zmq_msg_data: Warning! Message has zero length.");
 	return("");
   }
   Print("zmq_msg_data: Message Length mql4zmq_msg_size "+IntegerToString(iMessLen));
 
   // Create a uchar[] array whose size is the string length (plus null terminator)
   ArrayResize(sCharArray, iMessLen+1);
   
   // Use the Win32 API to copy the string from the block returned by the DLL
   // into the uchar[] array   
   RtlMoveMemory(sCharArray, recvPtr, iMessLen);
   //? added just to be sure
   sCharArray[iMessLen+1] = (uchar)0x00;
   // Convert the uchar[] array to a message string
   string uMessage = CharArrayToString(sCharArray);
   
   // Free the string memory returned by the DLL.
   // This step can be removed but, without it,
   // there will be a memory leak.
   // The correct method for freeing the string
   // *depends on how the DLL allocated the memory*
   // The following assumes that the DLL has used LocalAlloc
   // (or an indirect equivalent). If not,
   // then the following line may not fix the leak, and may even cause a crash.   
   //?LocalFree(recvPtr);
   
   return(uMessage);
}

int zmq_msg_size (int &msg[])
{
   return(mql4zmq_msg_size(msg));
}

// Infrastructure.
int zmq_init (int io_threads)
{
   return(mql4zmq_init(io_threads));
}
   
int zmq_term (int context)
{
   return(mql4zmq_term(context));
}

// Sockets.
int zmq_socket (int context, int type)
{
   return(mql4zmq_socket(context, type));
}

int zmq_close (int socket)
{
   return(mql4zmq_close(socket));
}

int zmq_setsockopt (int socket, int option, string optval)
{
   uchar optvalChar[];
   vStringToCharArray(optval, optvalChar);
   return(mql4zmq_setsockopt(socket, option, optvalChar, StringLen(optval)));
}

int zmq_getsockopt (int socket, int option, string optval)
{
   uchar optvalChar[];
   vStringToCharArray(optval, optvalChar);     
   return(mql4zmq_getsockopt(socket, option, optvalChar, StringLen(optval)));
}

int zmq_bind (int socket, string addr)
{
   uchar addrChar[];
   vStringToCharArray(addr, addrChar); 
   return(mql4zmq_bind(socket, addrChar));
}

int zmq_connect (int socket, string addr)
{
   uchar addrChar[];
   vStringToCharArray(addr, addrChar);    
   return(mql4zmq_connect(socket, addrChar));
}

// Defaults to no flags; meaning the flag is an optional paramater. 
// Common flags are: ZMQ_NOBLOCK, ZMQ_SNDMORE
int zmq_send (int socket, int &msg[], int flags=0)
{
    
    return(mql4zmq_send(socket, msg, flags));
}

// Defaults to no flags; meaning the flag is an optional paramater. 
// Common flags are: ZMQ_NOBLOCK, ZMQ_SNDMORE
int zmq_recv (int socket, int &msg[], int flags=0)
{
   return(mql4zmq_recv(socket, msg, flags));
}

// I/O multiplexing.
int zmq_poll (int items, int nitems, int timeout)
{
   return(mql4zmq_poll(items, nitems, timeout));
}

// Built-in devices.
int zmq_device (int device, int insocket, int outsocket)
{
   return(mql4zmq_device(device, insocket, outsocket));
}

// zhelper functions.
string s_recv (int socket, int flags=0)
{
   uchar sCharArray[];
   //vTrace("Call the DLL function and get its block of string memory");
   // as an int pointer to the memory rather than as a string    
   int recvPtr = mql4s_recv(socket, flags);
   //vTrace("Get the length of the string ");
   int iMessLen = lstrlenA(recvPtr);   

   // if message length is 0, leave.  
   if (iMessLen < 1) {
	// vDebug("s_recv: Message has zero length.");
 	return("");
   }
   vDebug("s_recv: iMessLen lstrlenA "+iMessLen);
   
   //vTrace("Create a uchar[] array whose size is the string length (plus terminator)");
   ArrayResize(sCharArray, iMessLen+1);
   
   // Use the Win32 API to
   //vTrace("copy the string from the block returned by the DLL");
   // into the uchar[] array   
   RtlMoveMemory(sCharArray, recvPtr, iMessLen+1);
   //vTrace("Convert the uchar[] array to a message string");
   string uMessage = CharArrayToString(sCharArray);
   
   //vTrace("Free the string memory returned by the DLL");
   // This step can be removed but, without it,
   // there will be a memory leak.
   // The correct method for freeing the string
   // *depends on how the DLL allocated the memory*
   // The following assumes that the DLL has used LocalAlloc
   // (or an indirect equivalent). If not,
   // then the following line may not fix the leak, and may even cause a crash.   
   LocalFree(recvPtr);
   
	//vTrace("Drop excess null's from the pointer.");
	//uMessage = StringSubstr(uMessage, 0, iMessageLen);
   // vDebug("Return message string "+uMessage);
   return(uMessage);
}

int s_send (int socket, string text)
{
   uchar textChar[];
   vStringToCharArray(text, textChar);     
   return(mql4s_send(socket, textChar));
}

int s_sendmore (int socket, string text)
{
   uchar textChar[];
   vStringToCharArray(text, textChar);     
   return(mql4s_sendmore(socket, textChar));
}


//+---------------------------------------------------------------------------------+
//| Types and Options variables. Copied from zmq.h     
//+---------------------------------------------------------------------------------+

// Message Flags.
#define ZMQ_MAX_VSM_SIZE 30
/*  Message types. These integers may be stored in 'content' member of the    */
/*  message instead of regular pointer to the data.                           */
#define ZMQ_DELIMITER 31
#define ZMQ_VSM 32
/*  Message flags. ZMQ_MSG_SHARED is strictly speaking not a message flag     */
/*  (it has no equivalent in the wire format), however, making  it a flag     */
/*  allows us to pack the stucture tigher and thus improve performance.       */
#define ZMQ_MSG_MORE 1
#define ZMQ_MSG_SHARED 128
#define ZMQ_MSG_MASK 129

// Socket types.                                                              
#define ZMQ_PAIR 0
#define ZMQ_PUB 1
#define ZMQ_SUB 2
#define ZMQ_REQ 3
#define ZMQ_REP 4
#define ZMQ_DEALER 5
#define ZMQ_ROUTER 6
#define ZMQ_PULL 7
#define ZMQ_PUSH 8
#define ZMQ_XPUB 9
#define ZMQ_XSUB 10

//  Socket options.                                                           
#define ZMQ_HWM 1
#define ZMQ_SWAP 3
#define ZMQ_AFFINITY 4
#define ZMQ_IDENTITY 5
#define ZMQ_SUBSCRIBE 6
#define ZMQ_UNSUBSCRIBE 7
#define ZMQ_RATE 8
#define ZMQ_RECOVERY_IVL 9
#define ZMQ_MCAST_LOOP 10
#define ZMQ_SNDBUF 11
#define ZMQ_RCVBUF 12
#define ZMQ_RCVMORE 13
#define ZMQ_FD 14
#define ZMQ_EVENTS 15
#define ZMQ_TYPE 16
#define ZMQ_LINGER 17
#define ZMQ_RECONNECT_IVL 18
#define ZMQ_BACKLOG 19
#define ZMQ_RECOVERY_IVL_MSEC 20   /*  opt. recovery time, reconcile in 3.x   */
#define ZMQ_RECONNECT_IVL_MAX 21

//  Send/recv options.                                                        
#define ZMQ_NOBLOCK 1
#define ZMQ_SNDMORE 2

// I/O Multplexing options.
#define ZMQ_POLLIN 1
#define ZMQ_POLLOUT 2
#define ZMQ_POLLERR 4

// Device types.
#define ZMQ_STREAMER 1
#define ZMQ_FORWARDER 2
#define ZMQ_QUEUE 3
