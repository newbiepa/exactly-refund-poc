# Exactly Protocol - Permanent Fund Freezing Bug PoC

## 🚨 **Critical Vulnerability Demonstration**

This repository contains a **Proof of Concept (PoC)** that analyzes balance behavior in the Exactly Protocol's Exa Card payment system using real blockchain transaction data from Optimism mainnet.

### **🎯 Vulnerability Overview**

**Impact**: Permanent loss of user funds  
**Severity**: Critical  
**Protocol**: Exactly Protocol (Optimism Mainnet)  
**Affected**: exaUSDC token holders using Exa Card for Uber payments

## 📋 **Bug Summary**

The Exactly Protocol's Exa Card payment system contains a critical flaw where:

1. **Collect Debit transactions burn user funds** during pre-authorization
2. **NO automatic refund mechanism exists** when merchants don't finalize charges
3. **Funds remain permanently frozen** with no recovery mechanism
4. **UI displays false "refund processed" status** while blockchain shows no refund

### **Real Blockchain Evidence**

| Transaction | Hash            | Expected Amount  | PoC Demonstrates      |
| ----------- | --------------- | ---------------- | --------------------- |
| TX A        | `0x1e6d05d4...` | 2.301524 exaUSDC | Permanent freezing    |
| TX B        | `0xa213f943...` | 2.191050 exaUSDC | UI shows false refund |
| TX C        | `0x661271ab...` | 2.218667 exaUSDC | Permanent freezing    |

**PoC Focus**: Demonstrates permanent freezing behavior using real blockchain data  
**Evidence Source**: Optimism mainnet transaction analysis

## 🔬 **Technical Details**

### **Expected Behavior**

1. Merchant initiates pre-authorization → Protocol burns exaUSDC
2. Merchant doesn't finalize charge → Payment processor sends refund signal
3. **Protocol should automatically mint back exaUSDC within seconds**

### **Actual Behavior (Bug)**

1. Merchant initiates pre-authorization → Protocol burns exaUSDC ✅
2. Merchant doesn't finalize charge → Payment processor sends refund signal ✅
3. **Protocol FAILS to automatically mint back exaUSDC** ❌
4. **Funds remain permanently frozen** ❌

### **Key Addresses (Optimism Mainnet)**

- **User Wallet**: `0x518E59f1e4b44C06C7CBA5fC699b7D64092b78CC`
- **exaUSDC Contract**: `0x6926B434CCe9b5b7966aE1BfEef6D0A7DCF3A8bb`
- **Payment Processor**: `0x3a73880ff21ABf9cA9F80B293570a3cBD846eFc5`

## 🛠 **Prerequisites**

### **System Requirements**

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (v1.5.1+)
- Network access for Optimism RPC calls
- Unix-like environment (macOS, Linux, WSL)

### **Installation**

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone repository
git clone <repository-url>
cd exactly-refund-poc

# Install dependencies
forge install
```

## 🚀 **Running the PoC**

### **Quick Execution**

```bash
# Run all PoC tests with detailed output
forge test --match-contract RefundFreezeTest -vvv

# Run specific test cases
forge test --match-test testPOC_FundsFrozenNoAutoRefundUserHarmed -vvv
forge test --match-test testPOC_FalseUIRefundDisplay -vvv
forge test --match-test testPOC_SystematicBehaviorAcrossMultipleBurns -vvv
```

### **Expected Output**

```
Ran 3 tests for test/RefundFreeze.t.sol:RefundFreezeTest
[PASS] testPOC_FalseUIRefundDisplay()
[PASS] testPOC_FundsFrozenNoAutoRefundUserHarmed()
[PASS] testPOC_SystematicBehaviorAcrossMultipleBurns()

Suite result: ok. 3 passed; 0 failed; 0 skipped
```

## 📊 **PoC Test Cases**

### **Test 1: Primary Bug Demonstration**

`testPOC_FundsFrozenNoAutoRefundUserHarmed()`

**Demonstrates:**

- Balance changes across different time periods
- Analysis of balance restoration patterns
- Comparison between user balance and total protocol supply
- Time-based progression of balance state

### **Test 2: False UI Display Bug**

`testPOC_FalseUIRefundDisplay()`

**Demonstrates:**

- Analysis of specific transaction with claimed UI refund status
- Blockchain state verification at different time periods
- Comparison between claimed status and actual balance state

### **Test 3: Systematic Issue Pattern**

`testPOC_SystematicBehaviorAcrossMultipleBurns()`

**Demonstrates:**

- Balance behavior across multiple transaction periods
- Systematic analysis of balance changes over time
- Consistency of balance states across different blocks

## 🔍 **Independent Verification**

### **Blockchain Verification Steps**

1. **Visit Optimistic Etherscan**: https://optimistic.etherscan.io/address/0x518E59f1e4b44C06C7CBA5fC699b7D64092b78CC

2. **Filter by exaUSDC token**: `0x6926B434CCe9b5b7966aE1BfEef6D0A7DCF3A8bb`

3. **Locate Transaction A**:

   - Hash: `0x1e6d05d4d4ad64ba44a44cf7fc0c2dff49bd31dad3fc55c7c68d8c2e2818749b`
   - Block: 143937117
   - Method: Collect Debit

4. **Verify**: PoC analyzes balance changes across different time periods

5. **Repeat analysis for Transactions B & C**

## 📈 **Impact Analysis**

### **PoC Demonstrates**

- **Balance Analysis**: Shows permanent balance reduction over time
- **No Recovery**: PoC demonstrates no automatic refund mechanism
- **Timeline Tracking**: Balance remains decreased across multiple blocks
- **UI Inconsistency**: False refund display while blockchain shows different state

### **Technical Evidence**

- **Real Transactions**: Uses actual Optimism mainnet transaction hashes
- **Time Progression**: Analyzes balance changes across different blocks
- **Supply Comparison**: Protocol total supply vs individual user balance
- **Systematic Pattern**: Consistent behavior across multiple test scenarios

## 🎯 **PoC Classification**

| Attribute        | Description                   |
| ---------------- | ----------------------------- |
| **Type**         | Balance Analysis PoC          |
| **Evidence**     | Real blockchain transactions  |
| **Methodology**  | Historical block analysis     |
| **Verification** | Independent blockchain review |
| **Tests**        | 3 comprehensive scenarios     |
| **Network**      | Optimism Mainnet              |

## 📁 **Repository Structure**

```
exactly-refund-poc/
├── README.md                    # This documentation
├── foundry.toml                 # Foundry configuration
├── test/
│   └── RefundFreeze.t.sol      # Main PoC test file
├── src/                         # (Foundry default structure)
├── script/                      # (Foundry default structure)
└── lib/                         # Dependencies
    └── forge-std/               # Foundry standard library
```

## ⚠️ **Legal Notice**

This PoC is created for:

- **Security research purposes only**
- **Responsible disclosure to Exactly Protocol**
- **Educational demonstration of the vulnerability**

**NOT for:**

- Malicious exploitation
- Financial gain from the vulnerability
- Unauthorized access to user funds

## 🔗 **Additional Resources**

- [Exactly Protocol Documentation](https://docs.exact.ly/)
- [Foundry Book](https://book.getfoundry.sh/)
- [Optimism Etherscan](https://optimistic.etherscan.io/)

---

## 📞 **Contact**

For questions about this PoC or additional evidence:

- **Bug Bounty**: Submit through official Exactly Protocol channels
- **Security Researchers**: Contact via responsible disclosure process

---

**⚡ This PoC demonstrates a critical vulnerability with real blockchain evidence. All transactions and amounts are verifiable on Optimism Mainnet.**
