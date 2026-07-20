#!/usr/bin/env bash
#
# Weekly updater for the qualification tool's PMMS 30-year rate.
#
# WHY THIS EXISTS
#   The tool is a client-side static page, so the browser cannot fetch the rate directly:
#   Freddie Mac / FRED block cross-origin requests (CORS), and file:// can't fetch at all.
#   So this script fetches the rate server-side and writes it to pmms.json, which the page
#   then reads SAME-ORIGIN (no CORS problem). index.html auto-loads pmms.json on open.
#
# SOURCE
#   FRED series MORTGAGE30US = the Freddie Mac Primary Mortgage Market Survey 30-yr fixed
#   (U.S. average) — the exact number the FHA/VA rules reference. Keyless CSV, no API key.
#
# RUN IT
#   ./update-pmms.sh          # writes/overwrites pmms.json next to index.html
#
# SCHEDULE IT (PMMS releases Thursdays ~noon ET; run Fridays to be safe)
#   • cron (Linux/Mac host):   0 12 * * 5  /path/to/update-pmms.sh
#   • GitHub Actions (if the site lives in a repo — commit pmms.json weekly):
#       # .github/workflows/update-pmms.yml
#       name: update-pmms
#       on:
#         schedule: [{ cron: "0 16 * * 5" }]   # Fridays 16:00 UTC
#         workflow_dispatch:
#       jobs:
#         update:
#           runs-on: ubuntu-latest
#           permissions: { contents: write }
#           steps:
#             - uses: actions/checkout@v4
#             - run: ./update-pmms.sh
#             - run: |
#                 git config user.name  "pmms-bot"
#                 git config user.email "pmms-bot@users.noreply.github.com"
#                 git commit -am "PMMS auto-update" || echo "no change"
#                 git push
#   • Cloudflare/Netlify/Vercel: run this in a scheduled function/cron and deploy pmms.json.
#
set -euo pipefail
cd "$(dirname "$0")"

CSV="$(curl -fsSL 'https://fred.stlouisfed.org/graph/fredgraph.csv?id=MORTGAGE30US')"

# Last row whose 2nd column is numeric (skips the header and any blank "." observations).
read -r DATE RATE < <(printf '%s\n' "$CSV" | awk -F, 'NR>1 && $2 ~ /^[0-9]/ {d=$1; v=$2} END{print d, v}')

if [ -z "${RATE:-}" ]; then
  echo "update-pmms: could not parse a rate from FRED" >&2
  exit 1
fi

printf '{\n  "rate": %s,\n  "date": "%s",\n  "source": "FRED MORTGAGE30US (Freddie Mac PMMS 30-yr fixed, U.S. average)"\n}\n' \
  "$RATE" "$DATE" > pmms.json

echo "update-pmms: wrote pmms.json -> ${RATE}% as of ${DATE}"
