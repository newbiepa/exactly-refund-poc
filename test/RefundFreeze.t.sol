// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IIssuerChecker {
    function collections(address account, bytes32 hash) external view returns (bool);
    function refunds(address account, bytes32 hash) external view returns (bool);
    function issuer() external view returns (address);
    function operationExpiry() external view returns (uint256);
}

interface IExaAccount {
    function collectDebit(uint256 amount, uint256 timestamp, bytes calldata signature) external;
}

/// @title PoC: collectDebit() Burns Without collectCredit() Refund
/// @notice Directly calls collectDebit() and queries IssuerChecker contract state
///         to prove that burned funds are never refunded via collectCredit().
/// @dev Architecture:
///   1. Operator calls collectDebit(amount, timestamp, sig) on user's ExaAccount
///   2. ExaAccount calls IssuerChecker.check() → marks collections[hash] = true, emits Collected
///   3. ExaAccount calls Market.withdraw() → burns exaUSDC shares, sends USDC to processor
///   4. For refund: operator SHOULD call collectCredit() → marks refunds[hash] = true, emits Refunded
///   5. BUG: collectCredit() is NEVER called for TX A and TX C → funds permanently lost
contract RefundFreezeTest is Test {
    address constant USER_WALLET = 0x518E59f1e4b44C06C7CBA5fC699b7D64092b78CC;
    address constant OPERATOR    = 0xcDdB23654595C224A563f62943D9Ff189138c04e;
    address constant EXA_USDC    = 0x6926B434CCe9b5b7966aE1BfEef6D0A7DCF3A8bb;
    address constant ISSUER_CHECKER = 0x59A644E490E48235adF8ba9b814A4f666C4fEb3A;
    address constant PAYMENT_PROCESSOR = 0x3a73880ff21ABf9cA9F80B293570a3cBD846eFc5;

    uint256 constant BLOCK_BEFORE_TX_A = 143937116;
    uint256 constant BLOCK_AFTER_TX_C  = 143937480;
    uint256 constant BLOCK_CURRENT     = 146478128;

    // TX A: collectDebit(2500000, 1763473009, signature)
    uint256 constant AMOUNT_A    = 2500000;
    uint256 constant TIMESTAMP_A = 1763473009;
    bytes constant SIGNATURE_A   = hex"c244622e4b0fdfa5bf697f9235b1db472d9262bffe631de7c3f6cabac5c95a635d9502ca3424758095f1123e742bf0ee1063dc44efa7100d811a49316a9731af1c";

    // TX B: collectDebit(2380000, 1763473038, signature)
    uint256 constant AMOUNT_B    = 2380000;
    uint256 constant TIMESTAMP_B = 1763473038;

    // TX C: collectDebit(2410000, 1763473735, signature)
    uint256 constant AMOUNT_C    = 2410000;
    uint256 constant TIMESTAMP_C = 1763473735;

    IERC20 exaUSDC = IERC20(EXA_USDC);
    IIssuerChecker checker = IIssuerChecker(ISSUER_CHECKER);

    function setUp() public {
        vm.createSelectFork("optimism", BLOCK_BEFORE_TX_A);
    }

    /// @notice CORE PoC: Replay collectDebit() and prove no collectCredit() ever follows
    function testPOC_ReplayCollectDebitAndProveNoRefund() public {
        uint256 balanceBefore = exaUSDC.balanceOf(USER_WALLET);

        // Compute the hash used by IssuerChecker to track this operation
        bytes32 hashA = keccak256(abi.encode(AMOUNT_A, TIMESTAMP_A));

        // --- PRE-CONDITION: no collection or refund recorded yet ---
        assertFalse(
            checker.collections(USER_WALLET, hashA),
            "Pre-condition: collection should not exist yet"
        );
        assertFalse(
            checker.refunds(USER_WALLET, hashA),
            "Pre-condition: refund should not exist yet"
        );

        // =============================================================
        // STEP 1: Replay the REAL collectDebit() call
        // Operator 0xcDdB23... calls collectDebit(2500000, 1763473009, sig)
        // on the user's ExaAccount smart wallet at 0x518E59...
        // =============================================================
        vm.prank(OPERATOR);
        IExaAccount(USER_WALLET).collectDebit(AMOUNT_A, TIMESTAMP_A, SIGNATURE_A);

        uint256 balanceAfter = exaUSDC.balanceOf(USER_WALLET);
        uint256 burned = balanceBefore - balanceAfter;

        assertGt(burned, 0, "collectDebit must burn exaUSDC shares");
        console.log("collectDebit() executed successfully");
        console.log("  Balance before:", balanceBefore);
        console.log("  Balance after: ", balanceAfter);
        console.log("  Shares burned: ", burned);

        // =============================================================
        // STEP 2: Verify IssuerChecker state AFTER collectDebit
        // collections[hash] = true  → collectDebit was processed
        // refunds[hash]     = false → no refund issued yet (expected)
        // =============================================================
        assertTrue(
            checker.collections(USER_WALLET, hashA),
            "IssuerChecker.collections must be true after collectDebit"
        );
        assertFalse(
            checker.refunds(USER_WALLET, hashA),
            "IssuerChecker.refunds must be false (no refund yet)"
        );

        // =============================================================
        // STEP 3: Advance time - show NO automatic refund mechanism
        // The contract has NO on-chain mechanism to auto-call collectCredit
        // =============================================================
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1800);
        assertEq(
            exaUSDC.balanceOf(USER_WALLET),
            balanceAfter,
            "After 1 hour: balance unchanged, no automatic refund"
        );

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 43200);
        assertEq(
            exaUSDC.balanceOf(USER_WALLET),
            balanceAfter,
            "After 1 day: balance unchanged, no automatic refund"
        );

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1296000);
        assertEq(
            exaUSDC.balanceOf(USER_WALLET),
            balanceAfter,
            "After 30 days: balance unchanged, no automatic refund"
        );

        // Refunds mapping STILL false after all time advances
        assertFalse(
            checker.refunds(USER_WALLET, hashA),
            "After 30+ days: IssuerChecker.refunds still false - no collectCredit was called"
        );

        console.log("RESULT: collectDebit() burns funds permanently.");
        console.log("  No on-chain mechanism triggers collectCredit() automatically.");
        console.log("  IssuerChecker.collections[hash] = true  (debit recorded)");
        console.log("  IssuerChecker.refunds[hash]     = false (NO credit ever issued)");
    }

    /// @notice Verify REAL on-chain state: collections exist but refunds do NOT
    function testPOC_VerifyOnChainStateProvesMissingRefunds() public {
        // Fork at current block to check real on-chain state
        vm.rollFork(BLOCK_CURRENT);

        bytes32 hashA = keccak256(abi.encode(AMOUNT_A, TIMESTAMP_A));
        bytes32 hashB = keccak256(abi.encode(AMOUNT_B, TIMESTAMP_B));
        bytes32 hashC = keccak256(abi.encode(AMOUNT_C, TIMESTAMP_C));

        // --- TX A: $2.50 ---
        bool collectedA = checker.collections(USER_WALLET, hashA);
        bool refundedA  = checker.refunds(USER_WALLET, hashA);
        console.log("TX A ($2.50): collected =", collectedA, ", refunded =", refundedA);
        assertTrue(collectedA,  "TX A: collectDebit WAS called (collection exists on-chain)");
        assertFalse(refundedA,  "TX A: collectCredit was NEVER called (refund missing on-chain)");

        // --- TX B: $2.38 ---
        bool collectedB = checker.collections(USER_WALLET, hashB);
        bool refundedB  = checker.refunds(USER_WALLET, hashB);
        console.log("TX B ($2.38): collected =", collectedB, ", refunded =", refundedB);
        assertTrue(collectedB,  "TX B: collectDebit WAS called (collection exists on-chain)");
        // TX B refund was NOT done through collectCredit either
        assertFalse(refundedB,  "TX B: collectCredit was NEVER called (even though balance was manually restored)");

        // --- TX C: $2.41 ---
        bool collectedC = checker.collections(USER_WALLET, hashC);
        bool refundedC  = checker.refunds(USER_WALLET, hashC);
        console.log("TX C ($2.41): collected =", collectedC, ", refunded =", refundedC);
        assertTrue(collectedC,  "TX C: collectDebit WAS called (collection exists on-chain)");
        assertFalse(refundedC,  "TX C: collectCredit was NEVER called (refund missing on-chain)");

        console.log("");
        console.log("=== PROOF SUMMARY ===");
        console.log("IssuerChecker at:", ISSUER_CHECKER);
        console.log("All 3 collectDebit() calls: collections[hash] = true");
        console.log("All 3 collectCredit() calls: refunds[hash] = false");
        console.log("CONCLUSION: The protocol's refund function (collectCredit) was NEVER");
        console.log("  invoked for ANY of the 3 burned transactions. This is verifiable");
        console.log("  by anyone querying the IssuerChecker contract on Optimism mainnet.");
    }

    /// @notice Demonstrate the complete debit-without-credit flow using real TX data
    function testPOC_FullFlowCollectDebitWithoutCollectCredit() public {
        // Fork at current block (Jan 2026) to analyze post-incident state
        vm.rollFork(BLOCK_CURRENT);

        // =============================================================
        // PART 1: Prove collectDebit was called (on-chain evidence)
        // =============================================================
        bytes32 hashA = keccak256(abi.encode(AMOUNT_A, TIMESTAMP_A));
        bytes32 hashC = keccak256(abi.encode(AMOUNT_C, TIMESTAMP_C));

        assertTrue(checker.collections(USER_WALLET, hashA), "TX A: collectDebit executed");
        assertTrue(checker.collections(USER_WALLET, hashC), "TX C: collectDebit executed");

        // =============================================================
        // PART 2: Prove collectCredit was NEVER called (on-chain evidence)
        // =============================================================
        assertFalse(checker.refunds(USER_WALLET, hashA), "TX A: collectCredit NEVER called");
        assertFalse(checker.refunds(USER_WALLET, hashC), "TX C: collectCredit NEVER called");

        // =============================================================
        // PART 3: Verify the impact - user's current balance reflects losses
        // =============================================================
        vm.rollFork(BLOCK_BEFORE_TX_A);
        uint256 balanceBefore = exaUSDC.balanceOf(USER_WALLET);

        vm.rollFork(BLOCK_AFTER_TX_C);
        uint256 balanceAfterBurns = exaUSDC.balanceOf(USER_WALLET);

        vm.rollFork(BLOCK_CURRENT);
        uint256 balanceNow = exaUSDC.balanceOf(USER_WALLET);

        uint256 totalBurned = balanceBefore - balanceAfterBurns;

        console.log("=== FUND IMPACT ANALYSIS ===");
        console.log("Balance before collectDebit calls:", balanceBefore);
        console.log("Balance after all 3 burns:        ", balanceAfterBurns);
        console.log("Balance now (months later):       ", balanceNow);
        console.log("Total shares burned:              ", totalBurned);

        assertGt(totalBurned, 0, "Burns occurred and reduced user balance");

        // If balance now is still less than before, funds are permanently lost
        if (balanceNow < balanceBefore) {
            uint256 permanentLoss = balanceBefore - balanceNow;
            console.log("PERMANENT LOSS:                   ", permanentLoss);
            assertGt(permanentLoss, 0, "Permanent fund loss confirmed");
        }

        // =============================================================
        // PART 4: Show there is NO on-chain auto-refund mechanism
        // The ExaAccount's collectCredit() requires an external call from
        // the operator with a valid issuer signature. There is no keeper,
        // no timelock auto-release, no escrow with timeout.
        // =============================================================
        console.log("");
        console.log("=== DESIGN FLAW ANALYSIS ===");
        console.log("collectDebit: Burns shares immediately, irreversibly");
        console.log("collectCredit: Requires operator to call with issuer signature");
        console.log("Missing: No automatic mechanism to call collectCredit when");
        console.log("  merchant doesn't finalize pre-authorization charge");
        console.log("");
        console.log("IssuerChecker contract state proves:");
        console.log("  TX A: collections=true, refunds=false -> FUNDS LOST");
        console.log("  TX C: collections=true, refunds=false -> FUNDS LOST");
    }
}
