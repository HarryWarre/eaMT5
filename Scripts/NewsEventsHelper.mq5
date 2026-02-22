//+------------------------------------------------------------------+
//|                                    NewsEventsHelper.mq5           |
//|                        Helper script to add news events           |
//|                                      https://www.mql5.com         |
//+------------------------------------------------------------------+
#property copyright "QuantumRSI News Helper"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs
#property description "Helper script to generate news events code"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== This Week's Major News ==="
input bool   add_nfp         = true;   // Add NFP (First Friday)
input bool   add_cpi         = true;   // Add US CPI
input bool   add_fomc        = false;  // Add FOMC Meeting
input bool   add_ecb         = false;  // Add ECB Decision
input bool   add_boe         = false;  // Add BOE Decision

input group "=== Custom News Event ==="
input datetime custom_time     = D'2024.11.01 13:30:00';  // News Time (GMT)
input string   custom_currency = "USD";                    // Currency
input string   custom_title    = "Custom Event";           // Event Title
input int      custom_impact   = 3;                        // Impact (1-3)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== News Events Helper ===");
    Print("Copy and paste this code into your EA's OnInit():");
    Print("");
    
    string code = "";
    
    // NFP - First Friday of month at 13:30 GMT
    if(add_nfp)
    {
        datetime nfp = GetFirstFriday(TimeCurrent());
        nfp = nfp + 13*3600 + 30*60;  // 13:30 GMT
        code += GenerateNewsCode(nfp, "USD", "Non-Farm Payrolls", 3);
    }
    
    // CPI - Usually second Tuesday at 13:30 GMT
    if(add_cpi)
    {
        datetime cpi = GetSecondTuesday(TimeCurrent());
        cpi = cpi + 13*3600 + 30*60;  // 13:30 GMT
        code += GenerateNewsCode(cpi, "USD", "CPI", 3);
    }
    
    // FOMC - Check actual schedule (usually Wednesday 18:00 GMT)
    if(add_fomc)
    {
        datetime fomc = D'2024.11.07 18:00:00';  // Example
        code += GenerateNewsCode(fomc, "USD", "FOMC Rate Decision", 3);
    }
    
    // ECB - Usually Thursday 12:45 GMT
    if(add_ecb)
    {
        datetime ecb = D'2024.11.07 12:45:00';  // Example
        code += GenerateNewsCode(ecb, "EUR", "ECB Interest Rate", 3);
    }
    
    // BOE - Usually Thursday 12:00 GMT
    if(add_boe)
    {
        datetime boe = D'2024.11.07 12:00:00';  // Example
        code += GenerateNewsCode(boe, "GBP", "BOE Interest Rate", 3);
    }
    
    // Custom event
    if(custom_impact > 0)
    {
        code += GenerateNewsCode(custom_time, custom_currency, custom_title, custom_impact);
    }
    
    Print(code);
    Print("");
    Print("=== End of Code ===");
    
    // Also save to file
    SaveToFile(code);
}

//+------------------------------------------------------------------+
//| Generate code string for one news event                          |
//+------------------------------------------------------------------+
string GenerateNewsCode(datetime time, string currency, string title, int impact)
{
    string impactStr = "LOW";
    if(impact == 2) impactStr = "MEDIUM";
    if(impact == 3) impactStr = "HIGH";
    
    string code = StringFormat(
        "// %s - %s (%s Impact)\n"
        "AddManualNewsEvent(D'%s', \"%s\", \"%s\", %d);\n\n",
        TimeToString(time, TIME_DATE|TIME_MINUTES),
        title,
        impactStr,
        TimeToString(time, TIME_DATE|TIME_MINUTES),
        currency,
        title,
        impact
    );
    
    return code;
}

//+------------------------------------------------------------------+
//| Get first Friday of current month                                |
//+------------------------------------------------------------------+
datetime GetFirstFriday(datetime dt)
{
    MqlDateTime mdt;
    TimeToStruct(dt, mdt);
    
    mdt.day = 1;
    mdt.hour = 0;
    mdt.min = 0;
    mdt.sec = 0;
    
    datetime firstDay = StructToTime(mdt);
    
    // Find first Friday
    while(TimeDayOfWeek(firstDay) != 5)  // 5 = Friday
    {
        firstDay += 86400;  // Add 1 day
    }
    
    return firstDay;
}

//+------------------------------------------------------------------+
//| Get second Tuesday of current month                              |
//+------------------------------------------------------------------+
datetime GetSecondTuesday(datetime dt)
{
    MqlDateTime mdt;
    TimeToStruct(dt, mdt);
    
    mdt.day = 1;
    mdt.hour = 0;
    mdt.min = 0;
    mdt.sec = 0;
    
    datetime firstDay = StructToTime(mdt);
    int tuesdayCount = 0;
    
    // Find second Tuesday
    while(tuesdayCount < 2)
    {
        if(TimeDayOfWeek(firstDay) == 2)  // 2 = Tuesday
            tuesdayCount++;
        
        if(tuesdayCount < 2)
            firstDay += 86400;
    }
    
    return firstDay;
}

//+------------------------------------------------------------------+
//| Save code to file                                                 |
//+------------------------------------------------------------------+
void SaveToFile(string code)
{
    int fileHandle = FileOpen("news_events_code.txt", FILE_WRITE|FILE_TXT);
    
    if(fileHandle != INVALID_HANDLE)
    {
        FileWriteString(fileHandle, "// ==============================================\n");
        FileWriteString(fileHandle, "// NEWS EVENTS CODE - Copy to EA's OnInit()\n");
        FileWriteString(fileHandle, "// Generated: " + TimeToString(TimeCurrent()) + "\n");
        FileWriteString(fileHandle, "// ==============================================\n\n");
        FileWriteString(fileHandle, code);
        FileClose(fileHandle);
        
        Print("Code saved to: MQL5/Files/news_events_code.txt");
    }
    else
    {
        Print("Failed to save file");
    }
}
//+------------------------------------------------------------------+
