# mql4zmq

The goal of this project is to provide [MQL4](http://docs.mql4.com/ "MQL4 documentation homepage.") bindings for the [ZeroMQ](http://zeromq.org/ "ZeroMQ homepage.") networking library. 

Licensed under the MIT License. See [LICENSE](https://github.com/AustenConrad/mql4zmq/blob/master/LICENSE) for more information.

### Version notes:
If you are using MetaTrader build 509 or earlier, use stable [release 1.0.1](https://github.com/AustenConrad/mql4zmq/releases/tag/v1.0.1)

If you are using MetaTrader build 600+, use the latest beta [2.0.0-pre](https://github.com/AustenConrad/mql4zmq/tree/2.0.0-pre) 

### Example Usage:

See Publish/Subscribe example in [examples](https://github.com/AustenConrad/mql4zmq/tree/master/examples "MQL4ZMQ Examples folder at Master.") folder. In general the use is exactly as [documented](http://api.zeromq.org/2-1:_start "ZeroMQ API Documentation.") by ZeroMQ and described in the "C" examples in the [ZGuide](http://zguide.zeromq.org/page:all "ZeroMQ ZGuide.")

### To build:

0. Download and install [Microsoft Visual C++ Express 2010](http://go.microsoft.com/?linkid=9709949 "Microsoft's Visual C++ 2010 Express Download Link.") if you don't already have it. 

1. Download the [ZeroMQ v2.1.11 source](http://download.zeromq.org/zeromq-2.1.11.zip "ZeroMQ v2.1.1 source.")

2. Download or git clone the [MQL4ZMQ source](https://github.com/AustenConrad/mql4zmq/ "mql4zmq github.")

3. Copy the downloaded 'mql4zmq' source folder to: downloaded_zeromq_source_folder\builds\msvc\

4. Open the ZMQ build solution at: downloaded_zeromq_source_folder\builds\msvc\msvc
    * You may need to right click on it and select: "open with" => "Microsfot Visual C++ 2010 Express"
    * It may need to be converted. In which case, select 'next' => 'no' then 'next' => 'finish'

5. Now that we have the solution open we need to add the mqlzmq project to the solution. To do this:
    1. Right-click on "Solution 'msvc'" then select "add" => "existing project"
    2. A file browser opens up. Go into the 'msvc' folder then the 'mql4zmq' folder and select the 'mql4zmq' project file.
        - You should now see the mql4zmq listed as project within the solution.
    3. Right-click on the 'mql4zmq' project and select 'Project Dependencies'. Make sure the drop-down 'Projects' menu is set to 'mql4zmq' and then select 'libzmq' in the 'Depends on' list. Select "OK" to complete.
    4. Make sure the build is set to 'Release' and not 'Debug'. See drop-down in middle of top Visual C++ application menu. 
    5. You are now ready to build the solution which will produce the ZeroMQ library (libzmq.dll) and the MQL4ZMQ bindings library (mql4zmq.dll). To do this right-click on the solution and select 'Build Solution'.
    6. Once all 8 projects within the solution have completed building, we need to copy the files the MetaTrader needs to the location it needs them as follows:

		<pre><code>
		[downloaded_zeromq_source_folder]\builds\msvc\Release\mql4zmq.dll
		=> c:\Program Files (x86)\[metatrader directory]\experts\libraries\mql4zmq.dll
	
		[downloaded_zeromq_source_folder]\lib\libzmq.dll
		=> c:\Windows\SysWOW64\libzmq.dll
	
		[downloaded_zeromq_source_folder]\builds\msvc\mql4zmq\mql4zmq.mqh 
		=> c:\Program Files (x86)\[metatrader directory]\experts\include\mql4zmq.mqh	
	
		[downloaded_zeromq_source_folder]\builds\msvc\mql4zmq\examples\mql4zmq.mq4 
		=> c:\Program Files (x86)\[metatrader directory]\experts\mql4zmq.mq4

		</code></pre>

6. You are now ready to open up metatrader, attach the example mql4zmq expert to the chart, and be off and running.
    * NOTE: when attaching to the chart make sure to select "Allow DLL Imports" and de-select "Confirm DLL Function Calls".


### To use the pre-compiled libraries:

0. Download and install the [Microsoft Visual C++ 2010 Redistributable Package](http://www.microsoft.com/download/en/details.aspx?id=5555 "Microsoft Visual C++ 2010 Redistributable Package Download.") if you don't already have it.

1. Download or git clone the [MQL4ZMQ source](https://github.com/AustenConrad/mql4zmq/ "mql4zmq github.")

2. Copy the following files to the following locations for MetaTrader:

	<pre><code>
	[downloaded_mql4zmq_source_folder]\pre-compiled\mql4zmq.dll 
	=> c:\Program Files (x86)\[metatrader directory]\experts\libraries\mql4zmq.dll

	[downloaded_mql4zmq_source_folder]\pre-compiled\libzmq.dll 
	=> c:\Windows\SysWOW64\libzmq.dll

	[downloaded_mql4zmq_source_folder]\mql4zmq.mqh 
	=> c:\Program Files (x86)\[metatrader directory]\experts\include\mql4zmq.mqh

	[downloaded_mql4zmq_source_folder]\examples\mql4zmq.mq4 
	=> c:\Program Files (x86)\[metatrader directory]\experts\mql4zmq.mq4

	</code></pre>

3. You are now ready to open up metatrader, attach the example mql4zmq expert to the chart, and be off and running.
    * NOTE: when attaching to the chart make sure to select "Allow DLL Imports" and de-select "Confirm DLL Function Calls".
