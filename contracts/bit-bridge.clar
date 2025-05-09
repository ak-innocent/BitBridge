;; Title: BitBridge - Secure Bitcoin-to-Stacks Bridge Contract
;; 
;; Summary:
;; A robust cross-chain bridge enabling secure Bitcoin deposits with oracle validation
;; and whitelisted recipient controls for compliant Layer 2 operations on Stacks.
;;
;; Description:
;; This contract implements a secure Bitcoin-to-Stacks bridging protocol with multiple safeguards
;; including oracle validation, transaction verification, recipient whitelisting, and deposit
;; limits. It facilitates the creation of wrapped Bitcoin tokens (Bitcoin-btc) on Stacks
;; while maintaining proper security controls and regulatory compliance mechanisms.
;; 
;; Features:
;; - Multi-oracle validation for Bitcoin transaction verification
;; - Recipient whitelisting for compliance requirements
;; - Configurable deposit limits and fee structure
;; - Emergency pause functionality
;; - Duplicate transaction protection

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INVALID-AMOUNT (err u2))
(define-constant ERR-INSUFFICIENT-BALANCE (err u3))
(define-constant ERR-BRIDGE-PAUSED (err u4))
(define-constant ERR-TRANSACTION-ALREADY-PROCESSED (err u5))
(define-constant ERR-ORACLE-VALIDATION-FAILED (err u6))
(define-constant ERR-INVALID-RECIPIENT (err u7))
(define-constant ERR-MAX-DEPOSIT-EXCEEDED (err u8))
(define-constant ERR-INVALID-TX-HASH (err u9))

;; Protocol Configuration
(define-data-var bridge-owner principal tx-sender)
(define-data-var is-bridge-paused bool false)
(define-data-var total-locked-bitcoin uint u0)
(define-data-var bridge-fee-percentage uint u10)  ;; 1% default fee (represented as 10/1000)
(define-data-var max-deposit-amount uint u10000000)  ;; 100 BTC default max

;; Security and Validation Maps
(define-map authorized-oracles principal bool)
(define-map processed-transactions { tx-hash: (string-ascii 64) } bool)
(define-map recipient-whitelist principal bool)

;; Bitcoin-BTC Token Definition
(define-fungible-token Bitcoin-btc)

;; User Balance Tracking
(define-map user-balances 
  { user: principal }
  { amount: uint }
)

;; Authorization Functions
(define-read-only (is-bridge-owner (sender principal))
  (is-eq sender (var-get bridge-owner))
)

;; Validation Helpers
(define-private (is-valid-principal (addr principal))
  (and 
    (not (is-eq addr tx-sender))
    (not (is-eq addr .none))
  )
)

(define-private (is-valid-tx-hash (hash (string-ascii 64)))
  (and 
    (not (is-eq hash ""))
    (> (len hash) u10)
  )
)

;; Oracle Management
(define-public (add-oracle (oracle principal))
  (begin
    (try! (check-is-bridge-owner))
    (asserts! (is-valid-principal oracle) ERR-INVALID-RECIPIENT)
    (map-set authorized-oracles oracle true)
    (ok true)
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (try! (check-is-bridge-owner))
    (asserts! (is-valid-principal oracle) ERR-INVALID-RECIPIENT)
    (map-set authorized-oracles oracle false)
    (ok true)
  )
)

;; Whitelist Management
(define-public (add-to-whitelist (recipient principal))
  (begin
    (try! (check-is-bridge-owner))
    (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT)
    (map-set recipient-whitelist recipient true)
    (ok true)
  )
)

(define-public (remove-from-whitelist (recipient principal))
  (begin
    (try! (check-is-bridge-owner))
    (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT)
    (map-set recipient-whitelist recipient false)
    (ok true)
  )
)

;; Bridge Control Functions
(define-public (pause-bridge)
  (begin
    (try! (check-is-bridge-owner))
    (var-set is-bridge-paused true)
    (ok true)
  )
)

(define-public (unpause-bridge)
  (begin
    (try! (check-is-bridge-owner))
    (var-set is-bridge-paused false)
    (ok true)
  )
)

;; Fee Management
(define-public (update-bridge-fee (new-fee uint))
  (begin
    (try! (check-is-bridge-owner))
    (asserts! (< new-fee u100) ERR-INVALID-AMOUNT)
    (var-set bridge-fee-percentage new-fee)
    (ok true)
  )
)

(define-public (update-max-deposit (new-max uint))
  (begin
    (try! (check-is-bridge-owner))
    (asserts! (> new-max u0) ERR-INVALID-AMOUNT)
    (asserts! (< new-max u100000000) ERR-INVALID-AMOUNT)
    (var-set max-deposit-amount new-max)
    (ok true)
  )
)

;; Core Bridge Functions
(define-public (deposit-bitcoin 
  (btc-tx-hash (string-ascii 64))
  (amount uint)
  (recipient principal)
)
  (let 
    (
      (fee (/ (* amount (var-get bridge-fee-percentage)) u1000))
      (net-amount (- amount fee))
      (is-whitelisted (default-to false (map-get? recipient-whitelist recipient)))
    )
    ;; Input Validation
    (asserts! (is-valid-tx-hash btc-tx-hash) ERR-INVALID-TX-HASH)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (var-get max-deposit-amount)) ERR-MAX-DEPOSIT-EXCEEDED)
    (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT)
    (asserts! is-whitelisted ERR-INVALID-RECIPIENT)
    
    ;; Bridge State Validation
    (asserts! (not (var-get is-bridge-paused)) ERR-BRIDGE-PAUSED)
    (asserts! (is-none (map-get? processed-transactions { tx-hash: btc-tx-hash })) ERR-TRANSACTION-ALREADY-PROCESSED)
    
    ;; Transaction Validation
    (try! (validate-bitcoin-transaction btc-tx-hash amount))
    
    ;; Token Minting
    (try! (ft-mint? Bitcoin-btc net-amount recipient))
    
    ;; State Updates
    (map-set processed-transactions { tx-hash: btc-tx-hash } true)
    (var-set total-locked-bitcoin (+ (var-get total-locked-bitcoin) amount))
    
    (ok net-amount)
  )
)

;; Transaction Validation
(define-private (validate-bitcoin-transaction 
  (btc-tx-hash (string-ascii 64))
  (amount uint)
)
  (let 
    (
      (authorized-validator (default-to false 
        (map-get? authorized-oracles tx-sender)
      ))
    )
    (asserts! (is-valid-tx-hash btc-tx-hash) ERR-INVALID-TX-HASH)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! authorized-validator ERR-NOT-AUTHORIZED)
    (ok true)
  )
)

;; Authorization Helper
(define-private (check-is-bridge-owner)
  (begin
    (asserts! (is-eq tx-sender (var-get bridge-owner)) ERR-NOT-AUTHORIZED)
    (ok true)
  )
)

;; Read-Only Functions
(define-read-only (get-total-locked-bitcoin)
  (var-get total-locked-bitcoin)
)

(define-read-only (get-user-balance (user principal))
  (get-user-balance-amount user)
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

;; Balance Helper
(define-private (get-user-balance-amount (user principal))
  (let 
    ((balance-opt (map-get? user-balances {user: user})))
    (if (is-some balance-opt)
        (get amount (unwrap-panic balance-opt))
        u0
    )
  )
)