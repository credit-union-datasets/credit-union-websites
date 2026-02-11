# Credit Union Website Addresses

## About this dataset

Contains website addresses scraped from the United States National Credit Union Association (NCUA)

- The data source is: http://ncua.gov/
- Scraped on: 24 Dec 2025
- Disclaimer: authors not affiliated with NCUA

## Methodology

1. Run [scripts/scrape-all-cu-websites.sh](scripts/scrape-all-cu-websites.sh) which:
    - automatically downloads the charter numbers CSV from the [credit-union-ncua](https://github.com/credit-union-datasets/credit-union-ncua) repo if not already present locally
    - loops over the credit union charter numbers and for each number:
      - runs [scripts/get-cu-website.sh](scripts/get-cu-website.sh) to look up the credit union detail using the NCUA "Research a Credit Union" tool API and extracts the website address
    - saves website addresses to [data/processed/scraped-websites.csv](data/processed/scraped-websites.csv)
      - if the website address was not available, notes it as UNKNOWN

## Inventory

```
.
├── data
│   └── processed
│       └── scraped-websites.csv  <-- website addresses
└── scripts
    ├── get-cu-website.sh
    └── scrape-all-cu-websites.sh
```

The website addresses in scraped-websites.csv are keyed by the NCUA charter number.

## See also

- [NCUA Data for Federally Insured Credit Unions](https://github.com/credit-union-datasets/credit-union-ncua) - NCUA listing data (charter numbers, raw data). This is a dependency of the scraping workflow: the scraper auto-downloads charter numbers from this repo.
- [Credit Union Membership Data](https://github.com/credit-union-datasets/credit-union-membership) - membership data scraped from credit union websites, keyed by charter number.
