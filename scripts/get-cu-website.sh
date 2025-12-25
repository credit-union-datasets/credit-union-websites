#!/bin/bash
#
# Script to scrape the website address of a Credit Union from NCUA
# "Research a Credit Union" tool.
#
# The script extracts the website address of a Credit Union from
# NCUA's "Research a Credit Union" tool using their API endpoint:
#  - https://mapping.ncua.gov/api/CreditUnionDetails/GetCreditUnionDetails/{charter}
#
# Usage: ./get-cu-website.sh <charter_number>
#
# Example: ./get-cu-website.sh 7
#          ./get-cu-website.sh 971
#
# Requires: curl, and either jq or ggrep (GNU grep)
#
# Features:
# - Uses the NCUA JSON API (found by parsing the JavaScript bundle)
# - Prefers jq for JSON parsing if available, falls back to ggrep/grep
# - Input validation (requires positive integer)
# - Error handling for API failures and missing data

set -e

# Check if charter number is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <charter_number>" >&2
    echo "Example: $0 7" >&2
    exit 1
fi

CHARTER_NUMBER="$1"

# Validate charter number is numeric
if ! [[ "$CHARTER_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Charter number must be a positive integer" >&2
    exit 1
fi

# API endpoint
API_URL="https://mapping.ncua.gov/api/CreditUnionDetails/GetCreditUnionDetails/${CHARTER_NUMBER}"

# Fetch the JSON data from the API
RESPONSE=$(curl -sL "$API_URL" 2>/dev/null)

# Check if the response is valid
if [ -z "$RESPONSE" ]; then
    echo "Error: Failed to fetch data from NCUA API" >&2
    exit 1
fi

# Check for error in response
if echo "$RESPONSE" | grep -q '"isError":true'; then
    ERROR_MSG=$(echo "$RESPONSE" | grep -o '"errorMessage":"[^"]*"' | cut -d'"' -f4)
    echo "Error: $ERROR_MSG" >&2
    exit 1
fi

# Extract website URL using jq if available, otherwise use grep
if command -v jq &> /dev/null; then
    WEBSITE=$(echo "$RESPONSE" | jq -r '.creditUnionWebsite // empty')
else
    # Use GNU grep (ggrep on macOS, grep on Linux)
    if command -v ggrep &> /dev/null; then
        GREP="ggrep"
    else
        GREP="grep"
    fi
    WEBSITE=$(echo "$RESPONSE" | $GREP -oP '"creditUnionWebsite"\s*:\s*"[^"]*"' | $GREP -oP 'https?://[^"]+' || true)
fi

# Handle missing or unknown websites
if [ -z "$WEBSITE" ] || [ "$WEBSITE" = "null" ]; then
    # Website is unknown - record as UNKNOWN so we don't retry
    echo "UNKNOWN"
    exit 0
fi

# Convert to lowercase (DNS is case-insensitive)
WEBSITE=$(echo "$WEBSITE" | tr '[:upper:]' '[:lower:]')

echo "$WEBSITE"
