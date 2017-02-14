//+------------------------------------------------------------------+
//|                                                     MMT_Data.mqh |
//|                                          Copyright 2017, Marco Z |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Marco Z"
#property link      "https://www.mql5.com"
#property strict

#include "MMT_OptionsParser.mqh"
#include "MMT_Main.mqh"

enum SignalType {
    SignalNone,
    SignalBuy,
    SignalSell,
    SignalHold
};

//+------------------------------------------------------------------+
// DataList and DataUnit
//+------------------------------------------------------------------+

class DataUnit {
    private:
    string rawValueString;
    int rawValueInt;
    double rawValueDouble;
    bool rawValueBool;
    
    double lastChangedTime;
    
    public:
    DataUnit();
    DataUnit(string rawValue, SignalType signalInput = SignalNone, string debugValueInput = "")
        { rawValueString = rawValue; rawValueType = DataString; signal = signalInput; debugValue = debugValueInput; }
    DataUnit(int rawValue, SignalType signalInput = SignalNone, string debugValueInput = "")
        { rawValueInt = rawValue; rawValueType = DataInt; signal = signalInput; debugValue = debugValueInput; }
    DataUnit(double rawValue, SignalType signalInput = SignalNone, string debugValueInput = "")
        { rawValueDouble = rawValue; rawValueType = DataDouble; signal = signalInput; debugValue = debugValueInput; }
    DataUnit(bool rawValue, SignalType signalInput = SignalNone, string debugValueInput = "")
        { rawValueBool = rawValue; rawValueType = DataBool; signal = signalInput; debugValue = debugValueInput; }
    
    DataType rawValueType;
    bool getRawValue(string& value) { if(rawValueType == DataString) { value = rawValueString; return true; } else { return false; } }
    bool getRawValue(int& value) { if(rawValueType == DataInt) { value = rawValueInt; return true; } else { return false; } }
    bool getRawValue(double& value) { if(rawValueType == DataDouble) { value = rawValueDouble; return true; } else { return false; } }
    bool getRawValue(bool& value) { if(rawValueType == DataBool) { value = rawValueBool; return true; } else { return false; } }
    
    string getRawValueString() { if(rawValueType == DataString) { return rawValueString; } else { return NULL; } }
    int getRawValueInt() { if(rawValueType == DataInt) { return rawValueInt; } else { return NULL; } }
    double getRawValueDouble() { if(rawValueType == DataDouble) { return rawValueDouble; } else { return NULL; } }
    bool getRawValueBool() { if(rawValueType == DataBool) { return rawValueBool; } else { return NULL; } };
    
    void setRawValue(string value) { rawValueString = value; rawValueType = DataString; }
    void setRawValue(int value) { rawValueInt = value; rawValueType = DataInt; }
    void setRawValue(double value) { rawValueDouble = value; rawValueType = DataDouble; }
    void setRawValue(bool value) { rawValueBool = value; rawValueType = DataBool; }
    
    string getStringValue();
    
    string debugValue;
    
    SignalType signal;
};

string DataUnit::getStringValue() {
    string result;
    
    switch(rawValueType) {
        case DataString: return rawValueString; break;
        case DataInt: return IntegerToString(rawValueInt); break;
        case DataDouble: return DoubleToString(rawValueDouble); break;
        case DataBool: return rawValueBool ? "True" : "False"; break;
        default: return rawValueString; break;
    }
}

class DataList {
    // We need this to maintain a data history
    private: 
    DataUnit *datums[];
    
    public:
    DataList(int historyCount = -1);
    int historyCount;
    
    void addDataGeneric(
        string stringValue, 
        int intValue, 
        double doubleValue, 
        bool boolValue, 
        DataType valueType, 
        SignalType signal = SignalNone, 
        string debugValue = ""
        );
    void addData(string value, SignalType signal = SignalNone, string debugValue = "");
    void addData(int value, SignalType signal = SignalNone, string debugValue = "");
    void addData(double value, SignalType signal = SignalNone, string debugValue = "");
    void addData(bool value, SignalType signal = SignalNone, string debugValue = "");
    
    DataUnit *getData(int historyIndex = 0) { return datums[MathMax(0,historyIndex)]; }
};

void DataList::DataList(int historyCountIn = -1) {
    historyCount = historyCountIn < 1 ? MathMax(1, HistoryLevel) : historyCountIn;
    
    ArraySetAsSeries(datums, true); 
        // this affects ArrayResize behavior by shifting all values up in index 
        // (i.e., element 0 is copied onto index 1 and then index 0 is freed.)
    ArrayResize(datums, historyCount, 1); // plus 1 is needed to resize an array in excess of 1, then delete last element
}

void DataList::addDataGeneric(
    string stringValue, 
    int intValue, 
    double doubleValue, 
    bool boolValue, 
    DataType valueType, 
    SignalType signal = SignalNone, 
    string debugValue = ""
    ) {
    DataUnit *newData;
    
    switch(valueType) {
        case DataInt: newData = new DataUnit(intValue, signal, debugValue); break;
        case DataDouble: newData = new DataUnit(doubleValue, signal, debugValue); break;
        case DataBool: newData = new DataUnit(boolValue, signal, debugValue); break;
        default: newData = new DataUnit(stringValue, signal, debugValue); break;
    }
    
    // Move to index 0 and pop all elements forward
    //ArraySetAsSeries(datums, false); // we may need to do this to work around behavior
    ArrayResize(datums, historyCount); // if array size is same, does it shift elements, or no?
    // ArrayResize(datums, historyCount+1);
    // datums[0] = newData;
    // ArrayResize(datums, historyCount);
    //ArraySetAsSeries(datums, true); // we may need to do this to work around behavior
    datums[0] = newData;
}

void DataList::addData(string value, SignalType signal = SignalNone, string debugValue = "") {
    addDataGeneric(value, NULL, NULL, NULL, DataString, signal, debugValue);
}

void DataList::addData(int value, SignalType signal = SignalNone, string debugValue = "") {
    addDataGeneric(NULL, value, NULL, NULL, DataInt, signal, debugValue);
}

void DataList::addData(double value, SignalType signal = SignalNone, string debugValue = "") {
    addDataGeneric(NULL, NULL, value, NULL, DataDouble, signal, debugValue);
}

void DataList::addData(bool value, SignalType signal = SignalNone, string debugValue = "") {
    addDataGeneric(NULL, NULL, NULL, value, DataBool, signal, debugValue);
}

//+------------------------------------------------------------------+
// DataManager and members
//+------------------------------------------------------------------+

// Workaround for dynamic multidimensional arrays
// There's really no reason to store the data using classes
// except that multidimensional arrays are fixed
// and we don't know ahead of time how big the array needs to be.

class DataCheck {
    public:
    DataCheck(int historyCount = -1);
    DataList *data;
    
    //void deleteAllDataList();
};

class DataFilter {
    public:
    DataFilter(int totalCheckCount, int historyCount = -1);
    DataCheck *check[];
    
    //void deleteAllCheckData();
};

class DataSymbol {
    public:
    DataSymbol();
    DataSymbol(int filterCount);
    DataFilter *filter[];
    
    // void deleteAllFilterData();
};

class DataManager {
    private:
    DataSymbol *symbol[];
    
    public:
    DataManager(int symbolCount, int filterCount);
    ~DataManager();
    
    DataList *getDataList(string symName, string filterName, int filterCheckId);
    DataList *getDataList(int symbolId, int filterId, int filterCheckId);
    DataList *getDataList(int symbolId, string filterName, int filterCheckId);
    DataList *getDataList(string symbolId, int filterId, int filterCheckId);
    
    // void deleteAllSymbolData();
};

void DataCheck::DataCheck(int historyCount = -1) {
    data = new DataList(historyCount);
}

void DataFilter::DataFilter(int totalCheckCount, int historyCount = -1) {
    ArrayResize(check, totalCheckCount);
    
    //todo: check if disabled?
    
    int i = 0;
    for(i = 0; i < totalCheckCount; i++) {
        check[i] = new DataCheck(historyCount);
    }
}

void DataSymbol::DataSymbol(int filterCount) {
    ArrayResize(filter, filterCount);
    
    for(int i = 0; i < filterCount; i++) {
        filter[i] = new DataFilter(
            Main.filterMan.getFilterCheckCount(i),
            -1 //Main.filterMan.getFilterHistoryCount(i) //, Main.filterMan.getFilterHistoryCount(i, true)
            );
    }
}

void DataManager::DataManager(int symbolCount, int filterCount) {
    ArrayResize(symbol, symbolCount);
    
    for(int i = 0; i < symbolCount; i++) {
        symbol[i] = new DataSymbol(filterCount);
    }
}

DataList *DataManager::getDataList(int symbolId, int filterId, int filterCheckId){
    return symbol[symbolId].filter[filterId].check[filterCheckId].data;
}

DataList *DataManager::getDataList(string symName, string filterName, int filterCheckId){
    return getDataList(Main.symbolMan.getSymbolId(symName), Main.filterMan.getFilterId(filterName), filterCheckId);
}

DataList *DataManager::getDataList(int symbolId, string filterName, int filterCheckId){
    return getDataList(symbolId, Main.filterMan.getFilterId(filterName), filterCheckId);
}

DataList *DataManager::getDataList(string symName, int filterId, int filterCheckId){
    return getDataList(Main.symbolMan.getSymbolId(symName), filterId, filterCheckId);
}

void DataManager::~DataManager() {
    int symbolCount = Main.symbolMan.symbolCount;
    int filterCount = 0; int checkCount = 0; int k = 0;
    
    //void deleteAllSymbolData();
    for(int i = 0; i < symbolCount; i++) {
        filterCount = Main.filterMan.filterCount;
        
        //void deleteAllFilterData();
        for(int j = 0; j < filterCount; j++) {
            checkCount = ArraySize(symbol[i].filter[j].check);
            //void deleteAllCheckData();
            for(k = 0; k < checkCount; k++) {
                delete(symbol[i].filter[j].check[k].data); //void deleteAllDataList();
                delete(symbol[i].filter[j].check[k]); 
            }
            
            delete(symbol[i].filter[j]);
        }
        
        delete(symbol[i]);
    }
}
