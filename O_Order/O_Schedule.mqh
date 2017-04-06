//+------------------------------------------------------------------+
//|                                                 MMT_Schedule.mqh |
//|                                          Copyright 2017, Marco Z |
//|                                       https://github.com/mazmazz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Marco Z"
#property link      "https://github.com/mazmazz"
#property strict
//+------------------------------------------------------------------+

#include "../MC_Common/MC_Common.mqh"
#include "../MC_Common/MC_Error.mqh"
#include "../D_Data/D_Data.mqh"
#include "../S_Symbol.mqh"
//#include "../depends/OrderReliable.mqh"
#include "../depends/PipFactor.mqh"

#include "O_Defines.mqh"

bool OrderManager::checkDoExitSchedule(int symIdx, int ticket, bool isPosition) {
    if(getCloseByMarketSchedule(symIdx, ticket, isPosition)) {
        Error::PrintInfo("Closing order " + ticket + ": Broker schedule", NULL, NULL, true);
        return sendClose(ticket, symIdx, isPosition);
    } else { return false; }
}

bool OrderManager::getCloseByMarketSchedule(int symIdx, int ticket = -1, bool isPosition = false) {
    if(!SchedCloseDaily && !SchedCloseSession && !SchedClose3DaySwap && !SchedCloseWeekend) { return false;}
    
    if(ticket > 0) {
        if(!checkDoSelect(ticket, isPosition)) { return false; }
        
        int orderOp = getOrderType(isPosition);
        
        if(!SchedClosePendings && Common::OrderIsPending(orderOp)) { return false; }
        if(SchedCloseOrderOp == OrderOnlyLong && !Common::OrderIsLong(orderOp)) { return false; }
        if(SchedCloseOrderOp == OrderOnlyShort && !Common::OrderIsShort(orderOp)) { return false; }
        if(SchedCloseOrderProfit == OrderOnlyProfitable && getProfitPips(ticket, isPosition) < 0) { return false; } // todo: do this properly: refer to pips? include swaps?
        if(SchedCloseOrderProfit == OrderOnlyLoss && getProfitPips(ticket, isPosition) >= 0) { return false; }
    }
    
    // todo: swap - if minimum swap trigger set, check swap: if it's greater than the negative swap value, return false
    
    if(SchedCloseDaily && getCloseDaily(symIdx)) { return true; }
    else if(SchedClose3DaySwap && getClose3DaySwap(symIdx)) { return true; }
    else if(SchedCloseWeekend && getCloseWeekend(symIdx)) { return true; }
    else if(SchedCloseSession && getCloseOffSessions(symIdx)) { return true; }
    else { return false; }
}

bool OrderManager::getCloseDaily(int symIdx) {
    int sessCount = getSessionCountByWeekday(symIdx, DayOfWeek());
    if(sessCount <= 0) { return false; }

    // if current session is last of the day, check if we're within SchedCloseMinutes of closing
    datetime from, to, dt = Common::StripDateFromDatetime(TimeCurrent());
    int sessCurrent = getCurrentSessionIdx(symIdx, from, to, dt);
    if(sessCurrent == (sessCount-1)) {
        return (dt >= to-(MathMax(1, SchedCloseMinutes)*60)); // todo: what if cycle length does not hit this check?
    } else { return false; }
}

bool OrderManager::getClose3DaySwap(int symIdx) {
    if(DayOfWeek() == SymbolInfoInteger(MainSymbolMan.symbols[symIdx].name, SYMBOL_SWAP_ROLLOVER3DAYS)) { 
        return getCloseDaily(symIdx);
    } else { return false; }
}

bool OrderManager::getCloseWeekend(int symIdx) {
    // weekend: tomorrow has no sessions at all
    
    // if today has sessions and tomorrow has no sessions, do getCloseDaily
    int curDay = DayOfWeek();
    int nextDay = (curDay == SATURDAY) ? SUNDAY : curDay + 1;

    if(getSessionCountByWeekday(symIdx, curDay) > 0 && getSessionCountByWeekday(symIdx, nextDay) <= 0) {
        return getCloseDaily(symIdx);
    } else { return false; }
}

bool OrderManager::getCloseOffSessions(int symIdx) {
    int sessCount = getSessionCountByWeekday(symIdx, DayOfWeek());
    if(sessCount <= 0) { return false; }

    // off session: current day (or midnight) has a session gap exceeding SchedGapIgnoreMinutes
    datetime dt = Common::StripDateFromDatetime(TimeCurrent());
    datetime fromCurrent = 0, toCurrent = 0; 
    int weekdayCurrent = DayOfWeek();
    int sessCurrent = getCurrentSessionIdx(symIdx, fromCurrent, toCurrent, dt, weekdayCurrent);
    if(sessCurrent < 0) { return false; }
    
    datetime fromNext = 0, toNext = 0; 
    int weekdayNext = -1, sessNext = -1;
    if(sessCurrent == (sessCount - 1)) { 
        sessNext = 0;
        weekdayNext = (weekdayCurrent == SATURDAY) ? SUNDAY : weekdayCurrent + 1; 
    }
    else { 
        sessNext = sessCurrent + 1;
        weekdayNext = weekdayCurrent; 
    }
    
    if(SchedGapIgnoreMinutes > 0 && SymbolInfoSessionTrade(MainSymbolMan.symbols[symIdx].name, (ENUM_DAY_OF_WEEK)weekdayNext, sessNext, fromNext, toNext)) {
        int gap = fromNext - toCurrent;
        if(gap <= SchedGapIgnoreMinutes*60) { return false; }
    }
    
    return (dt >= toCurrent-(MathMax(1, SchedCloseMinutes)*60)); // todo: what if cycle length does not hit this check?
}

//+------------------------------------------------------------------+

bool OrderManager::getOpenByMarketSchedule(int symIdx) {
    //extern int SchedOpenMinutesDaily = 0; // are we in first session of today? are we at least X minutes from open?
    //extern int SchedOpenMinutesWeekend = 180; // are we in first session of today AND yesterday had no sessions? are we at least X minutes from open?
    //extern int SchedOpenMinutesOffSessions = 0; // whichever session we are in, are we at least X minutes from open? ignore gaps
    //extern int SchedGapIgnoreMinutes = 15; // SchedGapIgnoreMinutes: Ignore session gaps of X mins
    
    if(getCloseByMarketSchedule(symIdx)) { return false; }
    
    if(SchedOpenMinutesWeekend <= 0 && SchedOpenMinutesDaily <= 0 && SchedOpenMinutesSession <= 0) { return true; }
    
    datetime fromCur = 0, toCur = 0, dt = Common::StripDateFromDatetime(TimeCurrent()); int dayCur = DayOfWeek();
    int sessCount = getSessionCountByWeekday(symIdx, dayCur);
    int sessCur = getCurrentSessionIdx(symIdx, fromCur, toCur, dt, dayCur);
    if(sessCur < 0) { return false; }
    
    
    int dayPrev = 0, sessPrev = 0, sessCountPrev = 0;
    if(sessCur == 0) { 
        if(SchedOpenMinutesWeekend <= 0 && SchedOpenMinutesDaily <= 0) { return true; }
        
        dayPrev = (dayCur == SUNDAY) ? SATURDAY : dayCur - 1;
        sessCountPrev = getSessionCountByWeekday(symIdx, dayPrev); // weekend: are we in first session of today AND yesterday had no sessions?
        
        int minutesOffset = sessCountPrev <= 0 ? SchedOpenMinutesWeekend : SchedOpenMinutesDaily; 
        return (dt >= fromCur + (minutesOffset*60));
    } else { 
        if(SchedOpenMinutesSession <= 0) { return true; }
        sessPrev = sessCur - 1;
        dayPrev = dayCur;
        
        int fromCompare = fromCur;
        datetime fromPrev = 0, toPrev = 0;
        if(SchedGapIgnoreMinutes > 0 && sessCountPrev > 0 && SymbolInfoSessionTrade(MainSymbolMan.symbols[symIdx].name, (ENUM_DAY_OF_WEEK)dayPrev, sessPrev, fromPrev, toPrev)) {
            int gap = fromCur - toPrev;
            if(gap <= SchedGapIgnoreMinutes*60) { return true; } 
                // todo: ideally we set fromCompare = fromPrev so we can compare from last session open, but this doesn't work because of wraparound. we need to compare dates as part of datetime
                // for now, just return true
        }
        
        return (dt >= fromCompare + (SchedOpenMinutesSession*60));
    }
}

//+------------------------------------------------------------------+

int OrderManager::getCurrentSessionIdx(int symIdx, datetime dt = 0, int weekday = -1) {
    datetime from = 0, to = 0;
    return getCurrentSessionIdx(symIdx, from, to, dt, weekday);
}

int OrderManager::getCurrentSessionIdx(int symIdx, datetime &fromOut, datetime &toOut, datetime dt = 0, int weekday = -1) {
    if(dt <= 0) { dt = TimeCurrent(); }
    dt = Common::StripDateFromDatetime(dt);
    if(weekday < 0 || weekday >= 7) { weekday = DayOfWeek(); }
    
    datetime from, to; int sessCount = -1; string symName = MainSymbolMan.symbols[symIdx].name;
    while(SymbolInfoSessionTrade(symName, (ENUM_DAY_OF_WEEK)weekday, ++sessCount, from, to)) { 
        if(dt >= from && dt < to) { 
            fromOut = from;
            toOut = to;
            return sessCount; 
        }
    }
    
    return -1;
}

int OrderManager::getSessionCountByWeekday(int symIdx, int weekday) {
    datetime from, to; int sessCount = -1; string symName = MainSymbolMan.symbols[symIdx].name;
    while(SymbolInfoSessionTrade(symName, (ENUM_DAY_OF_WEEK)weekday, ++sessCount, from, to)) { }
    
    return sessCount;
}