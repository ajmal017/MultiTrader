//+------------------------------------------------------------------+
//|                                     MMT_Helper_OptionsParser.mqh |
//|                                          Copyright 2017, Marco Z |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Marco Z"
#property link      "https://www.mql5.com"
#property strict

#include "MMT_Helper_Library.mqh"
#include "MMT_Helper_Error.mqh"

string KeyValDelimiter = "=";
string PairDelimiter = ";";

class OptionsParser {
    public:
    
    static string GetPairValue(string pair);
    static string GetPairKey(string pair, int indexNum = -1);
    static bool IsPairValid(string pair);
    static int CountPairs(string &optionPairList[]);
    static int CountPairs(string optionPairs);
    static void ParseGeneric(string options,
        DataType valueType, 
        string &stringDestArray[], 
        bool &boolDestArray[], 
        int &intDestArray[],
        double &doubleDestArray[],
        int &idArray[],
        int expectedCount=-1,
        bool addToArray = false
        );
        
    static void Parse(string options, string &destArray[], int expectedCount=-1, bool addToArray = false);
    static void Parse(string options, bool &destArray[], int expectedCount=-1, bool addToArray = false);
    static void Parse(string options, int &destArray[], int expectedCount=-1, bool addToArray = false);
    static void Parse(string options, double &destArray[], int expectedCount=-1, bool addToArray = false);
    static void Parse(string options, string &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false);
    static void Parse(string options, bool &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false);
    static void Parse(string options, int &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false);
    static void Parse(string options, double &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false);
};

// https://docs.mql4.com/convert/chartostr

// 1. Split string by ;
// 2. Eval units
// 2a. If empty, assume provided default or skip
// 2b. If no =, assume A only
// 2c. If proper a=value, convert AddrAbc to AddrInt and record value

string OptionsParser::GetPairValue(string pair) {
    pair = StringTrim(pair);
    int delimiterPos = StringFind(pair, KeyValDelimiter);
    
    if(delimiterPos > 0) { return StringSubstr(pair, delimiterPos+1); }
    else if(delimiterPos < 0) { return pair; }
    else {
        ThrowFatalError(1, ErrorFunctionTrace, "Invalid key=val pair", pair);
        return "";
    }
}

string OptionsParser::GetPairKey(string pair, int indexNum = -1) {
    pair = StringTrim(pair);
    int delimiterPos = StringFind(pair, KeyValDelimiter);
    
    if(delimiterPos > 0) { return StringSubstr(pair, 0, delimiterPos); }
    else if(delimiterPos < 0) {
        if(indexNum < 0) { return ""; } // -1 means to return no key; calling procedure should know how to handle this case.
        else { return AddrIntToAbc(indexNum, true); }
    }
    else {
        ThrowFatalError(1, ErrorFunctionTrace, "Invalid key=val pair", pair);
        return "";
    }
}

bool OptionsParser::IsPairValid(string pair) {
    // We support value-only (25) and key=value (a=25). 
    // Empty values are also supported but I'm undecided on this: key=blank (a=), or blank ().
    // Only invalid pair is =value (=25) or = (=), no key provided.
    // If one pair uses =, all of them must use =.
    
    pair = StringTrim(pair);
    
    int delimiterPos = StringFind(pair, KeyValDelimiter);
    int pairLen = StringLen(pair);
    return (delimiterPos != 0); // todo: check if key is abc valid
        // Add this if empty values should not be supported: && pairLen > 0 && pairLen != delimiterPos
}

int OptionsParser::CountPairs(string &optionPairList[]) {
    int optionPairCount = 0;
    int optionPairListCount = ArraySize(optionPairList);
    
    bool groupHasEquals = false;
    int numPairsWithoutEquals = 0;
    for(int i = 0; i < optionPairListCount; i++) {
        if(OptionsParser::IsPairValid(optionPairList[i])) { optionPairCount++; }
        if(StringFind(optionPairList[i], KeyValDelimiter) > -1) { groupHasEquals = true; }
        else { numPairsWithoutEquals++; }
    }
    
    if(groupHasEquals && numPairsWithoutEquals > 0) {
        optionPairCount = 0;
        ThrowFatalError(1, ErrorFunctionTrace, "All option pairs must be key=val when at least one key=val is present.", ConcatStringFromArray(optionPairList));
    }
    
    return optionPairCount;
}

int OptionsParser::CountPairs(string optionPairs) {
    string pairList[];
    int pairListCount = StringSplit(optionPairs, StringGetCharacter(PairDelimiter, 0), pairList);
    
    return OptionsParser::CountPairs(pairList);
}

void OptionsParser::ParseGeneric(string options,
    DataType valueType, 
    string &stringDestArray[], 
    bool &boolDestArray[], 
    int &intDestArray[],
    double &doubleDestArray[],
    int &idArray[],
    int expectedCount=-1,
    bool addToArray = false
    ) {
    string pairList[];
    int pairListCount = StringSplit(options, StringGetCharacter(PairDelimiter, 0), pairList);

    int pairValidCount = OptionsParser::CountPairs(pairList);
    
    if(pairValidCount < 1 || (expectedCount > -1 ? pairValidCount != expectedCount : false)) {
        ThrowFatalError(1, ErrorFunctionTrace, 
            pairValidCount < 1 ? StringConcatenate("pairValidCount=", pairValidCount, " not >= 1") : StringConcatenate("pairValidCount=", pairValidCount, " does not match expectedCount=", expectedCount, ". options=", options)
            );
        return;
    }
    
    bool fillIdArray = ArrayIsDynamic(idArray);
    if(fillIdArray) { if(!addToArray) { ArrayFree(idArray); } ArrayReserve(idArray, pairValidCount); }
    
    int destArraySize = 0;
    int oldArraySize = 0;
    switch(valueType) {
        case DataString: 
            if(!addToArray) { ArrayFree(stringDestArray); }
            else { oldArraySize = ArraySize(stringDestArray); }
            destArraySize = ArrayResize(stringDestArray, oldArraySize+pairValidCount); 
            break;
        case DataBool: 
            if(!addToArray) { ArrayFree(boolDestArray); }
            else { oldArraySize = ArraySize(boolDestArray); }
            destArraySize = ArrayResize(boolDestArray, oldArraySize+pairValidCount); 
            break;
        case DataInt: 
            if(!addToArray) { ArrayFree(intDestArray); }
            else { oldArraySize = ArraySize(intDestArray); }
            destArraySize = ArrayResize(intDestArray, oldArraySize+pairValidCount); 
            break;
        case DataDouble: 
            if(!addToArray) { ArrayFree(doubleDestArray); }
            else { oldArraySize = ArraySize(doubleDestArray); }
            destArraySize = ArrayResize(doubleDestArray, oldArraySize+pairValidCount); 
            break;
    }
    
    for(int i = 0; i < pairValidCount; i++) {
        string key, value; int keyAddrInt;
        
        if(OptionsParser::IsPairValid(pairList[i])) {
            key = OptionsParser::GetPairKey(pairList[i], i);
            value = OptionsParser::GetPairValue(pairList[i]);
            keyAddrInt = StringLen(key) <= 0 ? i : AddrAbcToInt(key);
            if(addToArray) { keyAddrInt += oldArraySize; }

            if(keyAddrInt < 0 || keyAddrInt >= destArraySize) {
                ThrowFatalError(1, ErrorFunctionTrace, StringConcatenate("key=", key, " keyAddrInt=", keyAddrInt, " is not within destArraySize=", destArraySize), pairList[i]);
                return;
            } else {
                switch(valueType) {
                    case DataString: stringDestArray[keyAddrInt] = value; break;
                    case DataBool: boolDestArray[keyAddrInt] = StrToBool(value); break;
                    case DataInt: intDestArray[keyAddrInt] = StrToInteger(value); break;
                    case DataDouble: doubleDestArray[keyAddrInt] = StrToDouble(value); break;
                }
                
                ArrayPush(idArray, keyAddrInt);
            }
        }
    }
}

void OptionsParser::Parse(string options, string &destArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataString, 
        destArray, BoolZeroArray, IntZeroArray, DoubleZeroArray,
        IntZeroArray, expectedCount, addToArray
        );
}

void OptionsParser::Parse(string options, bool &destArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataBool, 
        StringZeroArray, destArray, IntZeroArray, DoubleZeroArray,
        IntZeroArray, expectedCount, addToArray
        );
}

void OptionsParser::Parse(string options, int &destArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataInt, 
        StringZeroArray, BoolZeroArray, destArray, DoubleZeroArray,
        IntZeroArray, expectedCount, addToArray
        );
}

void OptionsParser::Parse(string options, double &destArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataDouble, 
        StringZeroArray, BoolZeroArray, IntZeroArray, destArray,
        IntZeroArray, expectedCount, addToArray
        );
}

void OptionsParser::Parse(string options, string &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataString, 
        destArray, BoolZeroArray, IntZeroArray, DoubleZeroArray,
        idArray, expectedCount, addToArray
        );
}

void OptionsParser::Parse(string options, bool &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataBool, 
        StringZeroArray, destArray, IntZeroArray, DoubleZeroArray,
        idArray, expectedCount, addToArray
        );
}

void OptionsParser::Parse(string options, int &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataInt, 
        StringZeroArray, BoolZeroArray, destArray, DoubleZeroArray,
        idArray, expectedCount, addToArray
        );
}

void OptionsParser::Parse(string options, double &destArray[], int &idArray[], int expectedCount=-1, bool addToArray = false) {
    OptionsParser::ParseGeneric(options, DataDouble, 
        StringZeroArray, BoolZeroArray, IntZeroArray, destArray,
        idArray, expectedCount, addToArray
        );
}
