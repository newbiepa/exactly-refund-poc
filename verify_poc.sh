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

