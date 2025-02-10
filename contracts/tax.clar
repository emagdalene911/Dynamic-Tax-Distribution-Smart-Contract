;; Dynamic Tax Distribution Smart Contract

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))

;; Data Variables
(define-data-var tax-rate uint u100) ;; 10% represented as 100 (for precision)
(define-data-var treasury-balance uint u0)
(define-data-var government-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Set to wallet_1

;; Data Maps
(define-map tax-payments principal uint)
(define-map fund-allocations { department: (string-ascii 64) } uint)


;; Add Data Maps
(define-map payment-history 
    { payer: principal, payment-id: uint } 
    { amount: uint, timestamp: uint }
)
(define-data-var payment-counter uint u0)



;; Public Functions
(define-public (set-government-address (new-address principal))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (var-set government-address new-address)
        (ok true)
    )
)

(define-public (pay-tax)
    (let (
        (payment-amount (/ (* (stx-get-balance tx-sender) (var-get tax-rate)) u1000))
    )
    (if (> payment-amount u0)
        (begin
            (try! (stx-transfer? payment-amount tx-sender (var-get government-address)))
            (map-set tax-payments tx-sender payment-amount)
            (map-set payment-history 
                {payer: tx-sender, payment-id: (var-get payment-counter)}
                {amount: payment-amount, timestamp: stacks-block-height}
            )
            (var-set payment-counter (+ (var-get payment-counter) u1))
            (var-set treasury-balance (+ (var-get treasury-balance) payment-amount))
            (ok true))
        ERR_INVALID_AMOUNT)
    )
)

(define-public (allocate-funds (department (string-ascii 64)) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR_INVALID_AMOUNT)
        (map-set fund-allocations {department: department} amount)
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok true)
    )
)

;; Read Only Functions
(define-read-only (get-tax-payment (taxpayer principal))
    (default-to u0 (map-get? tax-payments taxpayer))
)

(define-read-only (get-department-allocation (department (string-ascii 64)))
    (default-to u0 (map-get? fund-allocations {department: department}))
)

(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)



;; Add to Data Maps
(define-map tax-exempt-status principal bool)

;; Add Public Function
(define-public (set-tax-exempt-status (address principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set tax-exempt-status address status)
        (ok true)
    )
)

;; Add Read Function
(define-read-only (is-tax-exempt (address principal))
    (default-to false (map-get? tax-exempt-status address))
)




;; Add Data Maps
(define-map tax-brackets 
    { threshold: uint }
    { rate: uint }
)

;; Add Public Function
(define-public (set-tax-bracket (threshold uint) (rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set tax-brackets {threshold: threshold} {rate: rate})
        (ok true)
    )
)



;; Add Data Maps
(define-map department-budget-limits (string-ascii 64) uint)

;; Add Public Function
(define-public (set-department-budget (department (string-ascii 64)) (limit uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set department-budget-limits department limit)
        (ok true)
    )
)
