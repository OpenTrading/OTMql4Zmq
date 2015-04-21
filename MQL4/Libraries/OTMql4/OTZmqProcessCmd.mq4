// -*-mode: c; c-style: stroustrup; c-basic-offset: 4; coding: utf-8-dos -*-

/*

I know this is verbose and could be done more compactly,
but it's clean and robust so I'll leave it like this for now.

If you want to extend this for your own functions you have declared in Mql4,
define an unique first 3 letters to your function names, and
look for the comment below:
     // extentions from OpenTrading
and add a similar clause for your key and functions.
Then add a function like sProcessCmdgOT to handle the functions.

 */

#property copyright "Copyright 2013 OpenTrading"
#property link      "https://github.com/OpenTrading/"
#property library

#include <stdlib.mqh>
#include <stderror.mqh>
#include <OTMql4/OTMql4Zmq.mqh>
#include <OTMql4/OTLibLog.mqh>
// extentions from OpenTrading - see sProcessCmdgOT and sProcessCmdOT
#include <OTMql4/OTLibTrading.mqh>

string uOTZmqProcessCmd (string sMess) {
    string sMsg;
    string sRetval="none|";
    string sMark, sChart, sPeriod, sKey;
    int iStart, iLen, iFound, iNth;
    string sSub, sVerb;
    string sArgs1="";
    string sArgs2="";
    string sArgs3="";
    string sArgs4="";
    string sArgs5="";

    iLen=StringLen(sMess);
    if (iLen <= 0) {return("");}
    vDebug("sProcessCmd: " + sMess);

    iStart=0; iFound=0; iNth=0;
    sSub=""; sVerb=""; sArgs1=""; sArgs2=""; sArgs3="";
    while (iFound >= 0) {
	iFound=StringFind(sMess, "|", iStart);
	if (iFound >= 0) {
	    sSub = StringSubstr(sMess, iStart, iFound-iStart);
	} else {
	    sSub = StringSubstr(sMess, iStart, StringLen(sMess)-iStart);
	}
	vTrace("sProcessCmd split: " +sSub +' ' +iNth);
	if (iNth == 0) {
	    if ((StringFind(sSub, "cmd", 0) != 0) && (StringFind(sSub, "exec", 0) != 0)) {
		vError("sProcessCmd split: " +sSub  +' ' +iNth);
		return("");
	    }
	} else if (iNth == 1) {
	    sChart = StringTrimRight(sSub);
	} else if (iNth == 2) {
	    sPeriod = StringTrimRight(sSub);
	} else if (iNth == 3) {
	    sMark = StringTrimRight(sSub);
	} else if (iNth == 4) {
	    sVerb = StringTrimRight(sSub);
	} else if (iNth == 5) {
	    sArgs1 = StringTrimRight(sSub);
	} else if (iNth == 6) {
	    sArgs2 = StringTrimRight(sSub);
	} else if (iNth == 7) {
	    sArgs3 = StringTrimRight(sSub);
	} else if (iNth == 8) {
	    sArgs4 = StringTrimRight(sSub);
	} else if (iNth == 9) {
	    sArgs5 = StringTrimRight(sSub);
	}

	iStart=iFound+1;
	iNth = iNth + 1;
    }

    if (iNth < 1) {
	vError("sProcessCmd iNth=0: split failed on " + iNth);
	return("");
    }

    if (StringLen(sMark) < 6) {
	vError("sProcessCmd sMark: split too short " + sMark);
	return("");
    }

    if (StringLen(sVerb) < 4) {
	vError("sProcessCmd sVerb: split too short " + sVerb);
	return("");
    }

    sKey=StringSubstr(sVerb, 0, 3);
    vDebug("sKey: " + sKey + " sVerb: " + sVerb+ " sMark: " + sMark);

    // FixME: encode as json?
    if (sKey == "Zmq") {
	sRetval = sProcessCmdZmq(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);
    } else if (sKey == "Acc") {
	sRetval = sProcessCmdAcc(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);
    } else if (sKey == "Glo") {
	sRetval = sProcessCmdGlo(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);
    } else if (sKey == "Ter") {
	sRetval = sProcessCmdTer(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);
    } else if (sKey == "gOT") {
	// extentions from OpenTrading
	sRetval = sProcessCmdgOT(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);
    } else if (StringSubstr(sVerb, 1, 2) == "OT") {
	sRetval = sProcessCmdOT(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);

    } else if (sVerb == "OrdersTotal") {
	sRetval = "int|" + OrdersTotal();
    } else if (StringSubstr(sVerb, 0, 1) == "i") {
	sRetval = sProcessCmdi(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);
    } else if (sVerb == "Period") {
	sRetval = "int|" + Period();
    } else if (sVerb == "RefreshRates") {
	sRetval = "bool|" + RefreshRates();
    } else if (sVerb == "Symbol") {
	sRetval = "string|" + Symbol();
    } else if (sKey == "Win") {
	sRetval = sProcessCmdWin(sVerb, sChart, sPeriod, sArgs1, sArgs2, sArgs3, sArgs4, sArgs5);
    } else {
	sMsg="Unrecognized action: " + sMess; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sMark+"|"+sRetval);
}

string sProcessCmdZmq (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sMsg;
    string sRetval="none|";

    vDebug("sProcessCmdZmq: " + sVerb + ", " + sChart + ", " + sPeriod);
    if (sVerb == "ZmqVersion") {
	int major[1]; int minor[1]; int patch[1];
	zmq_version(major, minor, patch);
	sRetval = "string|" + major[0] + "." + minor[0] + "." + patch[0];
    } else if (sVerb == "ZmqPing") {
	sRetval = "string|" + zmq_ping(sArgs1);
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}

string sProcessCmdAcc (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sMsg;
    string sRetval="none|";
    string sSymbol;
    int iCmd;
    double fVolume;

    if (sVerb == "AccountBalance") {
	sRetval = "double|" + AccountBalance();
    } else if (sVerb == "AccountCompany") {
	sRetval = "string|" + AccountCompany();
    } else if (sVerb == "AccountCredit") {
	sRetval = "double|" + AccountCredit();
    } else if (sVerb == "AccountCurrency") {
	sRetval = "string|" + AccountCurrency();
    } else if (sVerb == "AccountEquity") {
	sRetval = "double|" + AccountEquity();
    } else if (sVerb == "AccountFreeMargin") {
	sRetval = "double|" + AccountFreeMargin();
    } else if (sVerb == "AccountFreeMarginCheck") {
	// assert
	sSymbol=sArgs1;
	iCmd=StrToInteger(sArgs2);
	fVolume=StrToDouble(sArgs3);
	sRetval = "double|" + AccountFreeMarginCheck(sSymbol, iCmd, fVolume);
    } else if (sVerb == "AccountFreeMarginMode") {
	sRetval = "double|" + AccountFreeMarginMode();
    } else if (sVerb == "AccountLeverage") {
	sRetval = "int|" + AccountLeverage();
    } else if (sVerb == "AccountMargin") {
	sRetval = "double|" + AccountMargin();
    } else if (sVerb == "AccountName") {
	sRetval = "string|" + AccountName();
    } else if (sVerb == "AccountNumber") {
	sRetval = "int|" + AccountNumber();
    } else if (sVerb == "AccountProfit") {
	sRetval = "double|" + AccountProfit();
    } else if (sVerb == "AccountServer") {
	sRetval = "string|" + AccountServer();
    } else if (sVerb == "AccountStopoutLevel") {
	sRetval = "int|" + AccountStopoutLevel();
    } else if (sVerb == "AccountStopoutMode") {
	sRetval = "int|" + AccountStopoutMode();
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}

string sProcessCmdGlo (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sMsg;
    string sRetval="none|";
    string sName, sSymbol;
    int iCmd;
    double fVolume;
    double fValue;

    if (sVerb == "GlobalVariableCheck") {
	// assert
	sName=sArgs1;
	sRetval = "bool|" + GlobalVariableCheck(sName);
    } else if (sVerb == "GlobalVariableDel") {
	// assert
	sName=sArgs1;
	sRetval = "bool|" + GlobalVariableDel(sName);
    } else if (sVerb == "GlobalVariableGet") {
	// assert
	sName=sArgs1;
	sRetval = "double|" + GlobalVariableGet(sName);
    } else if (sVerb == "GlobalVariableSet") {
	// assert
	sName=sArgs1;
	fValue=StrToDouble(sArgs2);
	sRetval = "double|" + GlobalVariableSet(sName, fValue);
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}

string sProcessCmdTer (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sMsg;
    string sRetval="none|";

    if (sVerb == "TerminalCompany") {
	sRetval = "string|" + TerminalCompany();
    } else if (sVerb == "TerminalName") {
	sRetval = "string|" + TerminalName();
    } else if (sVerb == "TerminalPath") {
	sRetval = "string|" + TerminalPath();
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}

// Wrap all of the functions that depend on an order being selected
// into a generic gOTWithOrderSelectByTicket and gOTWithOrderSelectByPosition
string sProcessCmdgOT (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sRetval="none|";
    string sMsg;
    int iError;

    if (sVerb == "gOTWithOrderSelectByTicket") {
	int iTicket=StrToInteger(sArgs1);

	if (OrderSelect(iTicket, SELECT_BY_TICKET) == false) {
	    iError=GetLastError();
	    sMsg = "OrderSelect returned an error: " + ErrorDescription(iError)+"("+iError+")";
	    vError(sMsg);
	    sRetval="error|"+sMsg;
	    return(sRetval);
	}
	// drop through
    } else if (sVerb == "gOTWithOrderSelectByPosition") {
	int iPos=StrToInteger(sArgs1);

	if (OrderSelect(iPos, SELECT_BY_POS) == false) {
	    iError=GetLastError();
	    sMsg = "OrderSelect returned an error: " + ErrorDescription(iError)+"("+iError+")";
	    vError(sMsg);
	    sRetval="error|"+sMsg;
	    return(sRetval);
	}
	// drop through
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
	return(sRetval);
    }

    string sCommand=sArgs2;
    // have a selected order ...
    if (sCommand == "OrderClosePrice" ) {
	sRetval = "double|" + OrderClosePrice();
    } else if (sCommand == "OrderCloseTime" ) {
	sRetval = "datetime|" + OrderCloseTime();
    } else if (sCommand == "OrderComment" ) {
	sRetval = "string|" + OrderComment();
    } else if (sCommand == "OrderCommission" ) {
	sRetval = "double|" + OrderCommission();
    } else if (sCommand == "OrderExpiration" ) {
	sRetval = "datetime|" + OrderExpiration();
    } else if (sCommand == "OrderLots" ) {
	sRetval = "double|" + OrderLots();
    } else if (sCommand == "OrderMagicNumber" ) {
	sRetval = "int|" + OrderMagicNumber();
    } else if (sCommand == "OrderOpenPrice" ) {
	sRetval = "double|" + OrderOpenPrice();
    } else if (sCommand == "OrderOpenTime" ) {
	sRetval = "datetime|" + OrderOpenTime();
    } else if (sCommand == "OrderProfit" ) {
	sRetval = "double|" + OrderProfit();
    } else if (sCommand == "OrderStopLoss" ) {
	sRetval = "double|" + OrderStopLoss();
    } else if (sCommand == "OrderSwap" ) {
	sRetval = "double|" + OrderSwap();
    } else if (sCommand == "OrderSymbol" ) {
	sRetval = "string|" + OrderSymbol();
    } else if (sCommand == "OrderTakeProfit" ) {
	sRetval = "double|" + OrderTakeProfit();
    } else if (sCommand == "OrderTicket" ) {
	sRetval = "int|" + OrderTicket();
    } else if (sCommand == "OrderType" ) {
	//? convert to a string?
	sRetval = "int|" + OrderType();
    } else {
	sMsg="Unrecognized " + sVerb + " command: " + sCommand; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}

string sProcessCmdi (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sMsg;
    string sRetval="none|";
    string sSymbol;
    int iPeriod, iShift;
    int iType, iCount, iStart;

    sSymbol=sArgs1;
    iPeriod=StrToInteger(sArgs2);

    // iBarShift
    if (sVerb == "iBars") {
	sRetval = "int|" + iBars(sSymbol, iPeriod);
    } else if (sVerb == "iClose") {
	iShift=StrToInteger(sArgs3);
	sRetval = "double|" + iClose(sSymbol, iPeriod, iShift);
    } else if (sVerb == "iHigh") {
	iShift=StrToInteger(sArgs3);
	sRetval = "double|" + iHigh(sSymbol, iPeriod, iShift);
    } else if (sVerb == "iHighest") {
	iType=StrToInteger(sArgs3);
	iCount=StrToInteger(sArgs4);
	iStart=StrToInteger(sArgs5);
	sRetval = "int|" + iHighest(sSymbol, iPeriod, iType, iCount, iStart);
    } else if (sVerb == "iLow") {
	iShift=StrToInteger(sArgs3);
	sRetval = "double|" + iLow(sSymbol, iPeriod, iShift);
    } else if (sVerb == "iLowest") {
	iType=StrToInteger(sArgs3);
	iCount=StrToInteger(sArgs4);
	iStart=StrToInteger(sArgs5);
	sRetval = "int|" + iLowest(sSymbol, iPeriod, iType, iCount, iStart);
    } else if (sVerb == "iOpen") {
	iShift=StrToInteger(sArgs3);
	sRetval = "double|" + iOpen(sSymbol, iPeriod, iShift);
    } else if (sVerb == "iTime") {
	iShift=StrToInteger(sArgs3);
	sRetval = "datetime|" + iTime(sSymbol, iPeriod, iShift);
    } else if (sVerb == "iVolume") {
	iShift=StrToInteger(sArgs3);
	sRetval = "double|" + iVolume(sSymbol, iPeriod, iShift);
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}

string sProcessCmdWin (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sMsg;
    string sRetval="none|";
    int iIndex, iPeriod;

    if (sVerb == "WindowBarsPerChart") {
	sRetval = "int|" + WindowBarsPerChart();
    } else if (sVerb == "WindowFind") {
	sRetval = "string|" + WindowFind(sArgs1);
    } else if (sVerb == "WindowFirstVisibleBar") {
	sRetval = "int|" + WindowFirstVisibleBar();
    } else if (sVerb == "WindowHandle") {
	iPeriod=StrToInteger(sArgs2);
	sRetval = "int|" + WindowHandle(sArgs1, iPeriod);
    } else if (sVerb == "WindowIsVisible") {
	iIndex=StrToInteger(sArgs1);
	sRetval = "bool|" + WindowIsVisible(iIndex);
    } else if (sVerb == "WindowOnDropped") {
	sRetval = "int|" + WindowOnDropped();
    } else if (sVerb == "WindowPriceMax") {
	iIndex=StrToInteger(sArgs1);
	sRetval = "double|" + WindowPriceMax(iIndex);
    } else if (sVerb == "WindowPriceMin") {
	iIndex=StrToInteger(sArgs1);
	sRetval = "double|" + WindowPriceMin(iIndex);
    } else if (sVerb == "WindowPriceOnDropped") {
	sRetval = "double|" + WindowPriceOnDropped();
    } else if (sVerb == "WindowRedraw") {
	WindowRedraw();
	sRetval = "void|";
	// WindowScreenShot
    } else if (sVerb == "WindowTimeOnDropped") {
	sRetval = "datetime|" + WindowTimeOnDropped();
    } else if (sVerb == "WindowXOnDropped") {
	sRetval = "int|" + WindowXOnDropped();
    } else if (sVerb == "WindowYOnDropped") {
	sRetval = "int|" + WindowYOnDropped();
    } else if (sVerb == "WindowsTotal") {
	sRetval = "int|" + WindowsTotal();
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}

// OpenTrading additions
// names start with a lower case letter then OT
string sProcessCmdOT (string sVerb, string sChart, string sPeriod, string sArgs1, string sArgs2, string sArgs3, string sArgs4, string sArgs5) {
    string sMsg;
    string sRetval="none|";
    int iTicket;
    double fLots;
    double fPrice;
    double fStopLoss;
    double fTakeProfit;
    datetime tExpiration;
    int iMaxWaitingSeconds;
    int iOrderEAMagic;
    int iTrailingStopLossPoints;
    int iSlippage;

    if (sVerb == "iOTOrderSelect") {
	sRetval = "int|" + iOTOrderSelect(StrToInteger(sArgs1), StrToInteger(sArgs2), StrToInteger(sArgs3));
    } else if (sVerb == "iOTOrderClose") {
	iTicket=StrToInteger(sArgs1);
	fLots=StrToDouble(sArgs2);
	fPrice=StrToDouble(sArgs3);
	iSlippage=StrToInteger(sArgs4);
	// FixMe:
	color cColor=CLR_NONE;
	sRetval = "int|" + iOTOrderClose(iTicket, fLots, fPrice, iSlippage, cColor);
    } else if (sVerb == "bOTIsTradeAllowed") {
	sRetval = "bool|" + bOTIsTradeAllowed();
    } else if (sVerb == "iOTSetTradeIsBusy") {
	if (StringLen(sArgs1) < 1) {
	    sRetval = "int|" + iOTSetTradeIsBusy(60);
	} else {
	    iMaxWaitingSeconds = StrToInteger(sArgs1);
	    sRetval = "int|" + iOTSetTradeIsBusy(iMaxWaitingSeconds);
	}
    } else if (sVerb == "iOTSetTradeIsNotBusy") {
	sRetval = "int|" + iOTSetTradeIsNotBusy();
    } else if (sVerb == "fOTExposedEcuInMarket") {
	if (StringLen(sArgs1) < 1) {
	    iOrderEAMagic = 0;
	} else {
	    iOrderEAMagic = StrToInteger(sArgs1);
	}
	sRetval = "double|" + fOTExposedEcuInMarket(iOrderEAMagic);
    } else if (sVerb == "bModifyTrailingStopLoss") {
	// this implies a selected order
	iTrailingStopLossPoints = StrToInteger(sArgs1);
	if (StringLen(sArgs2) < 1) {
	    tExpiration = 0;
	} else {
	    // FixMe: StrToDateTime?
	    tExpiration = StrToInteger(sArgs2);
	}
	sRetval = "bool|" + bModifyTrailingStopLoss(iTrailingStopLossPoints, tExpiration);
    } else if (sVerb == "bModifyOrder") {
	// this implies a selected order
	iTicket = StrToInteger(sArgs2);
	fPrice = StrToDouble(sArgs3);
	fStopLoss = StrToDouble(sArgs4);
	fTakeProfit = StrToDouble(sArgs5);
	// ignores datetime tExpiration
	tExpiration = 0;
	// Notes: Open price and expiration time can be changed only for pending orders.
	sRetval = "bool|" + bModifyOrder(sArgs1, iTicket, fPrice,
					 fStopLoss, fTakeProfit, tExpiration);
    } else if (sVerb == "bContinueOnOrderError") {
	iTicket=StrToInteger(sArgs1);
	sRetval = "bool|" + bContinueOnOrderError(iTicket);
    } else {
	sMsg="Unrecognized action: " + sVerb; vWarn(sMsg);
	sRetval="error|"+sMsg;
    }

    return (sRetval);
}
