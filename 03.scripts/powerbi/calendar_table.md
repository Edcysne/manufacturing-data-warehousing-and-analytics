calendar = 
VAR _StartDate = DATE(2022, 1, 1)
VAR _EndDate = DATE(2026, 12, 31)
RETURN
ADDCOLUMNS(
    CALENDAR(_StartDate, _EndDate),
    
    // ---- Sort ----
    "Date ID", DATEDIFF(_StartDate, [Date], DAY) + 1,

    // ---- Year ----
    "Year", YEAR([Date]),
    
    // ---- Quarter ----
    "Quarter Number", QUARTER([Date]),
    "Quarter Name", "Q" & QUARTER([Date]),
    "Year Quarter", YEAR([Date]) & "-Q" & QUARTER([Date]),
    
    // ---- Month ----
    "Month Number", MONTH([Date]),
    "Month Name", FORMAT([Date], "mmmm"),
    "Month Short", FORMAT([Date], "mmm"),
    "Year Month", FORMAT([Date], "YYYY-MM"),
    "Year Month Name", FORMAT([Date], "mmm YYYY"),
    "Days In Month", DAY(EOMONTH([Date], 0)),
    
    // ---- Week ----
    "Week Number", WEEKNUM([Date], 2),
    "Week Name", "W" & WEEKNUM([Date], 2),
    "Year Week", YEAR([Date]) & "-W" & FORMAT(WEEKNUM([Date], 2), "00"),
    
    // ---- Day ----
    "Day", DAY([Date]),
    "Day Name", FORMAT([Date], "dddd"),
    "Day Short", FORMAT([Date], "ddd"),
    "Day Of Week", WEEKDAY([Date], 2)
)