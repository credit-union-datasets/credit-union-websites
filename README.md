# Credit Union Website Addresses

## About this dataset

Contains website addresses scraped from the United States National Credit Union Association (NCUA)

- The data source is: http://ncua.gov/
- Scraped on: 24 Dec 2025
- Disclaimer: authors not affiliated with NCUA

## Methodology

1. Download "List of Active Federally Insured Credit Unions" from https://ncua.gov/files/publications/analysis/ to [data/raw/ncua.gov/](data/raw/ncua.gov/).
    - For example, <https://ncua.gov/files/publications/analysis/federally-insured-credit-union-list-september-2025.zip>
2. Unzip it, convert Excel file to csv, and extract the NCUA charter numbers to [data/processed/charter-numbers.csv](data/processed/charter-numbers.csv)
3. Run [scripts/scrape-all-cu-websites.sh](scripts/scrape-all-cu-websites.sh) which:
    - loops over the credit union charter numbers CSV and for each number:
      - runs [scripts/get-cu-website.sh](scripts/get-cu-website.sh) to look up the credit union detail using the NCUA "Research a Credit Union" tool API and extracts the website address
    - saves website addresses to [processed/scraped-websites.csv](processed/scraped-websites.csv)
      - if the website address was not available, notes it as UNKNOWN

## Inventory

```
.
├── data
│   ├── processed
│   │   ├── charter-numbers.csv
│   │   └── scraped-websites.csv  <-- these are the website addresses (keyed by NCUA charter number)
│   └── raw
│       └── ncua.gov
│           ├── federally-insured-credit-union-list-september-2025.zip
│           └── FederallyInsuredCreditUnions_2025q3.csv
└── scripts
    ├── get-cu-website.sh
    └── scrape-all-cu-websites.sh
```
