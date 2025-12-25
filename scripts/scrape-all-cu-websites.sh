#!/bin/bash
#
# Robust batch scraper for Credit Union websites from NCUA
#
# Features:
# - Resumable: Can be interrupted and restarted without data loss
# - Rate-limited: Respects NCUA servers with configurable delays
# - Auto-commits: Periodically saves progress to GitHub
# - Error handling: Logs failures and continues processing
#
# Usage: ./scrape-all-cu-websites.sh [options]
#
# Options:
#   --rate-limit SECONDS    Seconds to sleep between requests (default: 3)
#   --commit-interval NUM   Number of records between git commits (default: 100)
#   --dry-run              Show what would be done without scraping
#   --resume               Resume from last checkpoint (default: auto-detect)
#   --start-from NUMBER    Start from specific charter number
#

# Bash strict mode, but allow arithmetic expressions to return 0
set -eo pipefail

# Configuration
RATE_LIMIT_SECONDS=3
COMMIT_INTERVAL=100
LOG_PROGRESS=10
DRY_RUN=false
START_FROM=""

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHARTER_FILE="$PROJECT_DIR/data/processed/charter-numbers"
OUTPUT_FILE="$PROJECT_DIR/data/processed/scraped-websites.csv"
ERROR_LOG="$PROJECT_DIR/data/processed/scraping-errors.log"
PROGRESS_FILE="$PROJECT_DIR/data/processed/scraping-progress.txt"
SCRAPER_SCRIPT="$SCRIPT_DIR/get-cu-website.sh"

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --rate-limit)
            RATE_LIMIT_SECONDS="$2"
            shift 2
            ;;
        --commit-interval)
            COMMIT_INTERVAL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --start-from)
            START_FROM="$2"
            shift 2
            ;;
        --resume)
            # Auto-detect is default, this is a no-op for compatibility
            shift
            ;;
        -h|--help)
            head -n 20 "$0" | grep "^#" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required files
if [[ ! -f "$CHARTER_FILE" ]]; then
    echo "Error: Charter numbers file not found: $CHARTER_FILE"
    exit 1
fi

if [[ ! -f "$SCRAPER_SCRIPT" ]]; then
    echo "Error: Scraper script not found: $SCRAPER_SCRIPT"
    exit 1
fi

if [[ ! -x "$SCRAPER_SCRIPT" ]]; then
    echo "Error: Scraper script is not executable: $SCRAPER_SCRIPT"
    echo "Run: chmod +x $SCRAPER_SCRIPT"
    exit 1
fi

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Initialize output file with header if it doesn't exist
if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "charter_number,website,scraped_timestamp" > "$OUTPUT_FILE"
    echo "Initialized output file: $OUTPUT_FILE"
fi

# Initialize error log if it doesn't exist
if [[ ! -f "$ERROR_LOG" ]]; then
    touch "$ERROR_LOG"
    echo "Initialized error log: $ERROR_LOG"
fi

# Load already processed charter numbers
declare -A processed_charters
if [[ -f "$OUTPUT_FILE" ]]; then
    # Skip header, read charter numbers from first column
    tail -n +2 "$OUTPUT_FILE" | cut -d',' -f1 | while read -r charter; do
        processed_charters["$charter"]=1
    done
    # Re-read into the associative array (subshell workaround)
    while IFS=',' read -r charter _; do
        if [[ "$charter" != "charter_number" ]]; then
            processed_charters["$charter"]=1
        fi
    done < "$OUTPUT_FILE"
fi

# Count total and already processed
total_charters=$(wc -l < "$CHARTER_FILE")
already_processed=$(tail -n +2 "$OUTPUT_FILE" 2>/dev/null | wc -l || echo 0)

echo "=================================="
echo "CU Website Scraper"
echo "=================================="
echo "Total charter numbers: $total_charters"
echo "Already processed: $already_processed"
echo "Remaining: $((total_charters - already_processed))"
echo "Rate limit: ${RATE_LIMIT_SECONDS}s between requests"
echo "Auto-commit every: $COMMIT_INTERVAL records"
echo "Dry run: $DRY_RUN"
echo "=================================="
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN MODE - No actual scraping will occur"
    echo ""
fi

# Counters
count_processed=0
count_success=0
count_error=0
count_skipped=0
records_since_commit=0

# Function to commit and push
commit_and_push() {
    local message="$1"
    echo ""
    echo "Committing progress to GitHub..."
    cd "$PROJECT_DIR"
    git add "$OUTPUT_FILE" "$ERROR_LOG" "$PROGRESS_FILE" 2>/dev/null || true
    if git diff --staged --quiet; then
        echo "No changes to commit"
    else
        git commit -m "$message"
        echo "Pushing to remote..."
        # Retry logic for network failures
        local max_retries=4
        local retry_delay=2
        for ((i=1; i<=max_retries; i++)); do
            if git push -u origin claude/scrape-cu-websites-NwPa2; then
                echo "Successfully pushed to GitHub"
                break
            else
                if [[ $i -lt $max_retries ]]; then
                    echo "Push failed, retrying in ${retry_delay}s... (attempt $i/$max_retries)"
                    sleep $retry_delay
                    retry_delay=$((retry_delay * 2))
                else
                    echo "Warning: Failed to push after $max_retries attempts"
                    echo "You may need to push manually later"
                fi
            fi
        done
    fi
    echo ""
}

# Function to log error
log_error() {
    local charter="$1"
    local error_msg="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$timestamp,charter_$charter,$error_msg" >> "$ERROR_LOG"
}

# Main processing loop
while IFS= read -r charter; do
    # Skip if already processed
    if grep -q "^$charter," "$OUTPUT_FILE" 2>/dev/null; then
        ((count_skipped++)) || true
        continue
    fi

    # Skip if before start point
    if [[ -n "$START_FROM" ]] && [[ "$charter" -lt "$START_FROM" ]]; then
        ((count_skipped++)) || true
        continue
    fi

    ((count_processed++)) || true

    # Show progress
    if (( count_processed % LOG_PROGRESS == 0 )) || (( count_processed == 1 )); then
        remaining=$((total_charters - already_processed - count_processed))
        echo "Progress: $count_processed processed, $count_success success, $count_error errors, $remaining remaining"
    fi

    # Process charter number
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would scrape charter $charter"
        ((count_success++)) || true
    else
        echo -n "Scraping charter $charter... "

        # Call the scraper script
        if website=$("$SCRAPER_SCRIPT" "$charter" 2>&1); then
            # Success
            timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            # Escape any commas in the website URL (shouldn't happen, but be safe)
            website_escaped=$(echo "$website" | sed 's/,/%2C/g')
            echo "$charter,$website_escaped,$timestamp" >> "$OUTPUT_FILE"
            echo "$charter" > "$PROGRESS_FILE"
            echo "✓ $website"
            ((count_success++)) || true
        else
            # Error
            echo "✗ Failed"
            error_msg=$(echo "$website" | tr ',' ';' | tr '\n' ' ')
            log_error "$charter" "$error_msg"
            ((count_error++)) || true
        fi
    fi

    # Auto-commit check
    ((records_since_commit++)) || true
    if (( records_since_commit >= COMMIT_INTERVAL )); then
        progress_pct=$(( (already_processed + count_processed) * 100 / total_charters ))
        commit_and_push "Progress: scraped $((already_processed + count_processed))/$total_charters CU websites (${progress_pct}%)"
        records_since_commit=0
    fi

    # Rate limiting (sleep between requests)
    if [[ "$DRY_RUN" != "true" ]] && [[ $count_processed -lt $((total_charters - already_processed)) ]]; then
        sleep "$RATE_LIMIT_SECONDS"
    fi

done < "$CHARTER_FILE"

# Final summary
echo ""
echo "=================================="
echo "Scraping Complete!"
echo "=================================="
echo "Total processed this run: $count_processed"
echo "Successful: $count_success"
echo "Errors: $count_error"
echo "Skipped (already done): $count_skipped"
echo "Total in database: $((already_processed + count_success))"
echo "=================================="

# Final commit
if [[ "$DRY_RUN" != "true" ]] && (( records_since_commit > 0 )); then
    commit_and_push "Final commit: scraped $((already_processed + count_success))/$total_charters CU websites"
fi

echo ""
echo "Results saved to: $OUTPUT_FILE"
if [[ $count_error -gt 0 ]]; then
    echo "Errors logged to: $ERROR_LOG"
fi
echo ""
