# Credit Union Website Scraping Guide

This guide explains how to scrape website addresses for federally insured credit unions from the NCUA (National Credit Union Administration) website.

## Overview

The scraping system is designed to be:
- **Robust**: Handles errors gracefully and continues processing
- **Resumable**: Can be interrupted and restarted without losing progress
- **Polite**: Rate-limited to avoid overwhelming NCUA servers
- **Safe**: Automatically commits progress to GitHub for backup

## Components

### 1. Individual Scraper: `scripts/get-cu-website.sh`
Fetches the website for a single credit union by charter number.

**Usage:**
```bash
./scripts/get-cu-website.sh <charter_number>
```

**Example:**
```bash
./scripts/get-cu-website.sh 7
# Output: https://www.example-cu.org
```

### 2. Batch Scraper: `scripts/scrape-all-cu-websites.sh`
Processes all charter numbers from the input file with progress tracking, error handling, and auto-commits.

**Usage:**
```bash
./scripts/scrape-all-cu-websites.sh [options]
```

**Options:**
- `--rate-limit SECONDS` - Seconds to sleep between requests (default: 3)
- `--commit-interval NUM` - Number of records between git commits (default: 100)
- `--dry-run` - Show what would be done without actually scraping
- `--start-from NUMBER` - Start from a specific charter number
- `-h, --help` - Show help message

## Data Files

### Input
- `data/processed/charter-numbers` - List of charter numbers to scrape (one per line)

### Output
- `data/processed/scraped-websites.csv` - Successfully scraped results
  - Format: `charter_number,website,scraped_timestamp`
  - Example: `7,https://www.example-cu.org,2025-01-15T10:30:00Z`

- `data/processed/scraping-errors.log` - Failed scraping attempts
  - Format: `timestamp,charter_number,error_message`

- `data/processed/scraping-progress.txt` - Last processed charter number (for internal use)

## Usage Examples

### Basic Usage - Scrape All Credit Unions

```bash
cd /home/user/credit_unions
./scripts/scrape-all-cu-websites.sh
```

This will:
1. Process all charter numbers from `data/processed/charter-numbers`
2. Skip any already processed (checks `scraped-websites.csv`)
3. Wait 3 seconds between each request (default rate limit)
4. Commit and push to GitHub every 100 records
5. Continue running until all are processed

### Test Run (Dry Run)

Before starting a full scrape, test the setup:

```bash
./scripts/scrape-all-cu-websites.sh --dry-run
```

This shows what would happen without actually making requests to NCUA.

### Custom Rate Limiting

To be extra polite to NCUA servers, increase the delay:

```bash
./scripts/scrape-all-cu-websites.sh --rate-limit 5
```

This waits 5 seconds between each request instead of the default 3.

### Resume After Interruption

The scraper automatically resumes from where it left off:

```bash
# Start scraping
./scripts/scrape-all-cu-websites.sh

# ... gets interrupted (Ctrl+C, token limit, system crash, etc.) ...

# Simply run again - it will resume automatically
./scripts/scrape-all-cu-websites.sh
```

The script checks `scraped-websites.csv` and skips any charter numbers already processed.

### Start from a Specific Charter Number

If you want to process only charter numbers >= a specific value:

```bash
./scripts/scrape-all-cu-websites.sh --start-from 10000
```

### Commit More/Less Frequently

Adjust how often progress is saved to GitHub:

```bash
# Commit every 50 records (more frequent backups)
./scripts/scrape-all-cu-websites.sh --commit-interval 50

# Commit every 200 records (fewer commits)
./scripts/scrape-all-cu-websites.sh --commit-interval 200
```

## Expected Runtime

With 4,331 charter numbers and default settings:
- Rate limit: 3 seconds between requests
- API call time: ~0.5 seconds average
- **Total time: ~4 hours** (if all succeed)

The scraper shows progress every 10 records, so you can monitor its progress.

## Resumability Features

### Automatic Resume
- The script reads `scraped-websites.csv` on startup
- Skips any charter numbers already present
- Continues with unprocessed charter numbers

### Progress Tracking
- Updates `scraping-progress.txt` after each successful scrape
- Appends to `scraped-websites.csv` after each success
- Logs errors to `scraping-errors.log`

### Auto-Commit to GitHub
- Every 100 records (configurable), the script:
  1. Stages output files
  2. Creates a commit with progress message
  3. Pushes to remote repository
  4. Retries up to 4 times if network fails

This means if your session is interrupted, you'll lose at most 100 records of progress.

## Error Handling

### What Happens on Errors
- Individual failures don't stop the scraper
- Errors are logged to `scraping-errors.log`
- The script continues with the next charter number
- Final summary shows success/error counts

### Common Errors
- **Charter number not found**: Credit union may not exist or be inactive
- **No website found**: Credit union exists but has no website in NCUA database
- **API timeout**: Network issue or NCUA API temporarily unavailable

### Reviewing Errors

After scraping, check the error log:

```bash
cat data/processed/scraping-errors.log
```

You can manually retry failed charter numbers:

```bash
./scripts/get-cu-website.sh <charter_number>
```

## Best Practices

1. **Run in screen/tmux**: For long-running scrapes, use a terminal multiplexer
   ```bash
   screen -S cu-scraper
   ./scripts/scrape-all-cu-websites.sh
   # Ctrl+A, D to detach
   ```

2. **Monitor progress**: Check the output periodically
   ```bash
   tail -f data/processed/scraped-websites.csv
   ```

3. **Check GitHub regularly**: Verify commits are being pushed
   ```bash
   git log --oneline -10
   ```

4. **Be respectful**: Don't decrease the rate limit below 2 seconds

5. **Backup data**: GitHub auto-commits provide backup, but you can also manually backup:
   ```bash
   cp data/processed/scraped-websites.csv data/processed/scraped-websites.backup.csv
   ```

## Troubleshooting

### Script won't run
- Check if it's executable: `ls -l scripts/scrape-all-cu-websites.sh`
- If not: `chmod +x scripts/scrape-all-cu-websites.sh`

### Can't find charter numbers file
- Verify it exists: `ls -l data/processed/charter-numbers`
- Check you're in the project root directory

### Git push fails
- Check network connectivity
- Verify git credentials are set up
- The script retries automatically, but you can manually push later

### Want to start over completely
```bash
# Backup existing data
mv data/processed/scraped-websites.csv data/processed/scraped-websites.backup.csv
mv data/processed/scraping-errors.log data/processed/scraping-errors.backup.log

# Start fresh
./scripts/scrape-all-cu-websites.sh
```

## Data Analysis

After scraping, you can analyze the results:

```bash
# Count total scraped
wc -l data/processed/scraped-websites.csv

# Count errors
wc -l data/processed/scraping-errors.log

# View sample results
head -20 data/processed/scraped-websites.csv

# Find credit unions without websites (if you logged those)
grep "No website found" data/processed/scraping-errors.log | wc -l
```

## Support

For issues or questions about the scraper:
1. Check the error log: `data/processed/scraping-errors.log`
2. Try running with `--dry-run` to diagnose issues
3. Test individual charter numbers with `scripts/get-cu-website.sh`
