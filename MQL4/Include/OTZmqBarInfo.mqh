// -*-mode: c++; fill-column: 75; tab-width: 8; coding: utf-8-dos -*-

/*
This is a stub for the info we want put on the 0MQ wire.
We will probably change the formating to be json.
*/

#property copyright "Copyright 2014 Open Trading"
#property link      "https://github.com/OpenTrading/"

extern int iFastEMA=12;
extern int iSlowEMA=26;
extern int iSignalSMA=9;
extern int iStochKperiod=5;
extern int iStochDperiod=3;
extern int iStochSlowing=3;

string sBarInfo() {
  string sInfo;

  sInfo="iMACD="+iMACD(NULL, 0, iFastEMA, iSlowEMA, iSignalSMA, 
		       PRICE_CLOSE, MODE_MAIN,0);
  sInfo=sInfo+",iMA="+iMA(NULL, 0 , iFastEMA, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  sInfo=sInfo+",iStochasticMain="+iStochastic(NULL, 0, iStochKperiod, iStochDperiod, iStochSlowing,
					      MODE_SMA,0,MODE_MAIN,0);
  sInfo=sInfo+",iStochasticSignal="+iStochastic(NULL, 0, iStochKperiod, iStochDperiod, iStochSlowing,
						MODE_SMA,0,MODE_SIGNAL,0);
  return (sInfo);
}
