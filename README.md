# BitBridge - Secure Bitcoin-to-Stacks Bridge Contract

## Overview

**BitBridge** is a robust and secure cross-chain protocol that enables the seamless deposit of Bitcoin on the Bitcoin blockchain and its representation as wrapped tokens (`Bitcoin-btc`) on the Stacks blockchain. Designed with strong security controls, oracle-based transaction validation, and compliance-focused mechanisms, BitBridge facilitates compliant Layer 2 operations by safely bridging BTC into the Stacks ecosystem.

## Features

* **Secure Oracle Validation**: Multi-oracle architecture to validate Bitcoin transactions before minting wrapped tokens on Stacks.
* **Whitelisted Recipient Control**: Only approved recipients can receive wrapped BTC, allowing regulatory compliance.
* **Deposit Limits and Fees**: Configurable bridge fee percentage and maximum deposit thresholds.
* **Emergency Controls**: Owner-controlled pause/unpause mechanisms for rapid incident response.
* **Duplicate Protection**: Prevents replay or re-processing of the same Bitcoin transaction.

## Token

The bridge mints a fungible token called `Bitcoin-btc` on the Stacks blockchain to represent the locked BTC on Bitcoin.

## Contract Structure

### State Variables

* `bridge-owner`: Principal with administrative control over the bridge.
* `is-bridge-paused`: Boolean flag to halt deposits in emergencies.
* `total-locked-bitcoin`: Tracks the total amount of BTC deposited.
* `bridge-fee-percentage`: Fee taken from each deposit (default: 1%).
* `max-deposit-amount`: Upper limit for BTC deposited per transaction.
* `authorized-oracles`: Map of principals allowed to validate BTC transactions.
* `processed-transactions`: Prevents double-processing of BTC transactions.
* `recipient-whitelist`: Restricts eligible deposit recipients.
* `user-balances`: Tracks user balances (future extensibility).

## Public Functions

### Administration

* `add-oracle(principal)`: Add a new oracle.
* `remove-oracle(principal)`: Revoke an oracle's validation rights.
* `add-to-whitelist(principal)`: Add recipient to the whitelist.
* `remove-from-whitelist(principal)`: Remove recipient from the whitelist.
* `pause-bridge() / unpause-bridge()`: Toggle bridge operations.
* `update-bridge-fee(uint)`: Set the bridge fee percentage.
* `update-max-deposit(uint)`: Set the max BTC deposit per transaction.

### Core Functionality

* `deposit-bitcoin(string-ascii 64, uint, principal)`: Called by an authorized oracle to mint `Bitcoin-btc` on Stacks based on a validated BTC transaction.

## Security & Validation

* **Oracle Verification**: Only addresses in `authorized-oracles` can validate and trigger deposits.
* **Recipient Whitelist**: Ensures only approved accounts can receive wrapped BTC.
* **Transaction Hash Tracking**: All BTC tx hashes are recorded to prevent duplicates.
* **Emergency Stop**: Bridge can be paused if abnormal behavior is detected.
* **Input Validation**: Strict checks on tx hashes, amounts, principals, and limits.

## Errors

| Code | Error Constant                      | Description                              |
| ---- | ----------------------------------- | ---------------------------------------- |
| `u1` | `ERR-NOT-AUTHORIZED`                | Caller lacks necessary permissions       |
| `u2` | `ERR-INVALID-AMOUNT`                | Amount provided is invalid or zero       |
| `u3` | `ERR-INSUFFICIENT-BALANCE`          | Used in future token transfers           |
| `u4` | `ERR-BRIDGE-PAUSED`                 | Bridge is temporarily paused             |
| `u5` | `ERR-TRANSACTION-ALREADY-PROCESSED` | BTC tx hash already processed            |
| `u6` | `ERR-ORACLE-VALIDATION-FAILED`      | Oracle check failed                      |
| `u7` | `ERR-INVALID-RECIPIENT`             | Recipient is invalid or not whitelisted  |
| `u8` | `ERR-MAX-DEPOSIT-EXCEEDED`          | Deposit exceeds the allowed maximum      |
| `u9` | `ERR-INVALID-TX-HASH`               | Invalid format or empty transaction hash |

## How to Use

1. **Bridge Setup**:

   * Deploy the contract.
   * Set the initial bridge owner.
   * Add authorized oracles and whitelist recipient addresses.

2. **Deposit Workflow**:

   * A user sends BTC to a monitored BTC address.
   * An authorized oracle verifies the transaction off-chain.
   * Oracle calls `deposit-bitcoin(...)` with tx hash, amount, and recipient.
   * Contract mints `Bitcoin-btc` tokens minus the fee.

3. **Managing the Bridge**:

   * Bridge owner can pause the bridge during incidents.
   * Fees and limits can be adjusted dynamically.

## Read-Only Functions

* `get-total-locked-bitcoin()`: Returns total BTC locked via the bridge.
* `get-user-balance(principal)`: View balance of `Bitcoin-btc` (future extensibility).
* `is-oracle-authorized(principal)`: Check if address is an authorized oracle.

## Development Notes

* Contract is written in **Clarity**, the smart contract language for the Stacks blockchain.
* Intended for use with off-chain oracle infrastructure capable of validating Bitcoin transactions.
* Proper deployment should include rigorous oracle selection and monitoring practices.
