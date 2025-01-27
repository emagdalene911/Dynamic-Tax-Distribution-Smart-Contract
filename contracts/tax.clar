;; Dynamic Tax Distribution Smart Contract

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))

;; Data Variables
(define-data-var tax-rate uint u100) ;; 10% represented as 100 (for precision)
(define-data-var treasury-balance uint u0)
(define-data-var government-address principal tx-sender)

;; Data Maps
(define-map tax-payments principal uint)
(define-map fund-allocations { department: (string-ascii 64) } uint)

;; Public Functions
(define-public (pay-tax)
    (let (
        (payment-amount (/ (* (stx-get-balance tx-sender) (var-get tax-rate)) u1000))
    )
    (if (> payment-amount u0)
        (begin
            (try! (stx-transfer? payment-amount tx-sender (var-get government-address)))
            (map-set tax-payments tx-sender payment-amount)
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
        (ok amount)
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
