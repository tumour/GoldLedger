# GoldLedger

## [v1.5.0](https://github.com/tumour/GoldLedger/tree/v1.5.0) (2026-03-14)
[Full Changelog](https://github.com/tumour/GoldLedger/commits/v1.5.0)

- v1.5.0: Source Breakdown popup, improved UI, increased entry limit
    - Add "Summary" button next to Recent Transactions — opens Source Breakdown popup
    - Breakdown shows income/expense per source (Vendor, Repair, AH, Mail, Quest, Loot, Trade, Other)
    - Period filter: Today / Week / Month / All
    - Zero values displayed in gray for clarity
    - Gold-styled Summary button for better visibility
    - Increase MAX_ENTRIES from 500 to 2000 for better long-term tracking
    - Localization: all new strings available in English and Russian

## [v1.4.0](https://github.com/tumour/GoldLedger/tree/v1.4.0) (2026-03-12)
[Full Changelog](https://github.com/tumour/GoldLedger/commits/v1.4.0) [Previous Releases](https://github.com/tumour/GoldLedger/releases)

- v1.4.0: Chart periods, bar tooltips, AH mail detection, CurseForge CI/CD  
    - Add chart period buttons (7d / 30d / All) with toggle highlighting  
    - Default chart period changed to 7 days for better readability  
    - 30d chart now shows last 30 calendar days instead of current month only  
    - Add hover tooltips on chart bars showing date, income and expense  
    - Detect AH mail: income from Auction House letters marked as "ah" source  
    - Fix income/expense colors in chart tooltips  
    - Add GitHub Actions workflow for automatic CurseForge packaging  
    - Add X-Curse-Project-ID to TOC  
