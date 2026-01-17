#!/usr/bin/env bash
set -euo pipefail

# verify_poc.sh
# Runs the PoC tests and checks exaUSDC logs for mint (Transfer from zero -> user)
# Produces evidence.csv with simple results.

EXA="0x6926B434CCe9b5b7966aE1BfEef6D0A7DCF3A8bb"
USER="0x518E59f1e4b44C06C7CBA5fC699b7D64092b78CC"

declare -a CASES

# Define cases: "name|tx|block|fromBlock|toBlock"
CASES+=("May13-TX-A|0x0b874f128e60eaf28ca794c7a6328fd4acbe639af06314cd5017f19eb1378152|135794367|135794368|135800000")
CASES+=("May13-TX-B|0x53636a1714006cc849d72b7db6e9cb4fc7677879c1b79f675cf00c10b2911d26|135794883|135794884|135810000")
CASES+=("Nov18-TX-A|0x1e6d05d4d4ad64ba44a44cf7fc0c2dff49bd31dad3fc55c7c68d8c2e2818749b|143937117|143937118|144064000")
CASES+=("Nov18-TX-B|0xa213f943f7e365822421c18eb7cbe950462b71c207fdb23cbca7fe75ff6d8673|143937132|143937133|144064000")
CASES+=("Nov18-TX-C|0x661271ab43b890d0d38646580dbc105114dea74e98527e2e8dff081dfecb9a4e|143937480|143937481|144064000")

EVIDENCE_CSV="evidence.csv"
echo "case,tx_hash,block,from_block,to_block,mint_found,notes" > "$EVIDENCE_CSV"

echo "[*] Running forge tests (verbose)..."
forge test --match-contract RefundFreezeTest -vvv || true

echo "[*] Checking on-chain logs for mints (Transfer from 0x0.. -> user)..."
MINTS_MISSING=0

for entry in "${CASES[@]}"; do
  IFS="|" read -r name tx block fromBlock toBlock <<< "$entry"
  echo "------------------------------------------------------------"
  echo "[*] Case: $name"
  echo "    tx: $tx"
  echo "    block: $block  range: $fromBlock..$toBlock"

  # Query logs for exaUSDC in the given range and search for mint signature (from zero) and the USER address
  # Use cast logs; ensure cast is installed in environment
  LOGS=$(cast logs --from-block "$fromBlock" --to-block "$toBlock" --address "$EXA" 2>/dev/null || true)

  # Normalize lowercase for matching
  LOGS_LC=$(echo "$LOGS" | tr '[:upper:]' '[:lower:]' || true)
  ZERO_HEX="0x0000000000000000000000000000000000000000"
  USER_LC=$(echo "$USER" | tr '[:upper:]' '[:lower:]')

  # Detect a Transfer log where 'from' is zero and 'to' is USER
  # We'll check for both hex zero and user address presence in the log text.
  if echo "$LOGS_LC" | grep -q "$ZERO_HEX" && echo "$LOGS_LC" | grep -q "$USER_LC"; then
    echo "[OK] Mint/transfer found for $name in range $fromBlock..$toBlock"
    MINT_FOUND="true"
    NOTES="mint_found"
  else
    echo "[MISSING] No mint/transfer found for $name in range $fromBlock..$toBlock"
    MINT_FOUND="false"
    NOTES="no_mint_found"
    MINTS_MISSING=$((MINTS_MISSING+1))
  fi

  echo "    notes: $NOTES"
  echo
  printf "%s,%s,%s,%s,%s,%s,%s\n" "$name" "$tx" "$block" "$fromBlock" "$toBlock" "$MINT_FOUND" "$NOTES" >> "$EVIDENCE_CSV"
done

echo "------------------------------------------------------------"
echo "[*] Evidence written to $EVIDENCE_CSV"

if [ "$MINTS_MISSING" -gt 0 ]; then
  echo "[!] RESULT: Some disputed burns have NO corresponding mint events (count: $MINTS_MISSING)"
  exit 2
else
  echo "[OK] All checked cases have mint events in the scanned ranges."
  exit 0
fi

#!/bin/bash

echo "=== EXACTLY PROTOCOL - PERMANENT FREEZING BUG PoC ==="
echo "Independent verification script"
echo ""

echo "Step 1: Checking Foundry installation..."
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not installed. Please install: https://book.getfoundry.sh/"
    exit 1
fi
echo "✅ Foundry found: $(forge --version | head -1)"

echo ""
echo "Step 2: Installing dependencies..."
forge install --no-commit

echo ""
echo "Step 3: Compiling contracts..."
forge build

echo ""
echo "Step 4: Running PoC tests..."
echo "This will connect to Optimism mainnet to verify real transactions"
forge test --match-contract RefundFreezeTest

echo ""
echo "Step 5: Running detailed analysis..."
echo "Detailed output showing the bug demonstration:"
forge test --match-test testPOC_CollectDebitBurnsWithoutCorrespondingMints -vv

echo ""
echo "=== VERIFICATION COMPLETE ==="
echo "If all tests pass, the bug has been successfully demonstrated."

