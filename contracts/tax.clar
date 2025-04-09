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



;; Add Data Variables
(define-data-var emergency-fund uint u0)
(define-data-var emergency-fund-threshold uint u1000)

;; Add Public Function
(define-public (allocate-to-emergency-fund (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR_INVALID_AMOUNT)
        (var-set emergency-fund (+ (var-get emergency-fund) amount))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok true)
    )
)



;; Add Public Function
(define-public (process-tax-refund (recipient principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? amount (var-get government-address) recipient))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok true)
    )
)




;; Add Data Maps
(define-map department-metrics 
    { department: (string-ascii 64) }
    { spent: uint, projects-completed: uint }
)

;; Add Public Function
(define-public (update-department-metrics (department (string-ascii 64)) (spent uint) (completed uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set department-metrics 
            {department: department}
            {spent: spent, projects-completed: completed}
        )
        (ok true)
    )
)


;; Add Data Variables
(define-data-var penalty-rate uint u50) ;; 5% penalty rate (50/1000)
(define-data-var grace-period uint u144) ;; blocks before penalty (roughly 24 hours)

;; Add Data Maps
(define-map payment-due-dates principal uint)

;; Add Public Function
(define-public (assess-late-penalty (taxpayer principal))
    (let (
        (due-date (default-to u0 (map-get? payment-due-dates taxpayer)))
        (current-height stacks-block-height)
        (tax-amount (get-tax-payment taxpayer))
        (penalty-amount (/ (* tax-amount (var-get penalty-rate)) u1000))
    )
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (> current-height (+ due-date (var-get grace-period))) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? penalty-amount taxpayer (var-get government-address)))
        (ok true)))
)


;; Add Data Maps
(define-map tax-incentives 
    { category: (string-ascii 64) }
    { discount-rate: uint, active: bool }
)

;; Add Public Function
(define-public (create-tax-incentive (category (string-ascii 64)) (discount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set tax-incentives 
            {category: category}
            {discount-rate: discount, active: true}
        )
        (ok true))
)


;; Add Data Maps
(define-map budget-proposals 
    { id: uint }
    { department: (string-ascii 64), amount: uint, approved: bool }
)
(define-data-var proposal-counter uint u0)

;; Add Public Function
(define-public (submit-budget-proposal (department (string-ascii 64)) (amount uint))
    (begin
        (map-set budget-proposals
            {id: (var-get proposal-counter)}
            {department: department, amount: amount, approved: false}
        )
        (var-set proposal-counter (+ (var-get proposal-counter) u1))
        (ok true))
)



;; Add Data Maps
(define-map spending-categories 
    { category: (string-ascii 64) }
    { total-spent: uint, last-updated: uint }
)

;; Add Public Function
(define-public (record-spending (category (string-ascii 64)) (amount uint))
    (let (
        (current-total (default-to u0 (get total-spent (map-get? spending-categories {category: category}))))
    )
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set spending-categories
            {category: category}
            {total-spent: (+ current-total amount), last-updated: stacks-block-height}
        )
        (ok true)))
)

(define-read-only (get-category-spent (category (string-ascii 64)))
    (get total-spent (map-get? spending-categories {category: category}))
)


;; Add Data Maps
(define-map revenue-forecasts
    { period: uint }
    { projected: uint, actual: uint }
)

;; Add Public Function
(define-public (set-revenue-forecast (period uint) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set revenue-forecasts
            {period: period}
            {projected: amount, actual: u0}
        )
        (ok true))
)



;; Add Data Maps
(define-map taxpayer-ratings
    principal
    { rating: uint, last-payment: uint }
)

;; Add Public Function
(define-public (update-taxpayer-rating (taxpayer principal) (new-rating uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= new-rating u100) ERR_INVALID_AMOUNT)
        (map-set taxpayer-ratings
            taxpayer
            {rating: new-rating, last-payment: stacks-block-height}
        )
        (ok true))
)





;; Add Data Maps
(define-map department-performance
    { department: (string-ascii 64) }
    { efficiency-score: uint, budget-utilization: uint }
)

;; Add Public Function
(define-public (update-department-performance (department (string-ascii 64)) (efficiency uint) (utilization uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set department-performance
            {department: department}
            {efficiency-score: efficiency, budget-utilization: utilization}
        )
        (ok true))
)


;; Add Data Maps
(define-map emergency-allocations
    { id: uint }
    { recipient: principal, amount: uint, purpose: (string-ascii 64) }
)
(define-data-var emergency-counter uint u0)

;; Add Public Function
(define-public (distribute-emergency-funds (recipient principal) (amount uint) (purpose (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get emergency-fund)) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? amount (var-get government-address) recipient))
        (map-set emergency-allocations
            {id: (var-get emergency-counter)}
            {recipient: recipient, amount: amount, purpose: purpose}
        )
        (var-set emergency-counter (+ (var-get emergency-counter) u1))
        (var-set emergency-fund (- (var-get emergency-fund) amount))
        (ok true))
)



(define-map installment-plans
    principal
    { total-amount: uint, remaining-amount: uint, installment-size: uint, next-due: uint }
)

(define-public (create-installment-plan (total-amount uint) (number-of-installments uint))
    (let (
        (installment-size (/ total-amount number-of-installments))
        (next-payment-block (+ stacks-block-height u144))
    )
        (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> number-of-installments u0) ERR_INVALID_AMOUNT)
        (map-set installment-plans
            tx-sender
            { 
                total-amount: total-amount,
                remaining-amount: total-amount,
                installment-size: installment-size,
                next-due: next-payment-block
            }
        )
        (ok true))
)

(define-public (pay-installment)
    (let (
        (plan (unwrap! (map-get? installment-plans tx-sender) ERR_UNAUTHORIZED))
        (payment-amount (get installment-size plan))
    )
        (asserts! (> (get remaining-amount plan) u0) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? payment-amount tx-sender (var-get government-address)))
        (map-set installment-plans
            tx-sender
            {
                total-amount: (get total-amount plan),
                remaining-amount: (- (get remaining-amount plan) payment-amount),
                installment-size: payment-amount,
                next-due: (+ (get next-due plan) u144)
            }
        )
        (ok true))
)



(define-map deduction-types
    (string-ascii 64)
    { max-amount: uint, rate: uint }
)

(define-map taxpayer-deductions
    { taxpayer: principal, deduction-type: (string-ascii 64) }
    { amount: uint, approved: bool }
)

(define-public (register-deduction-type (name (string-ascii 64)) (max-amount uint) (rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set deduction-types
            name
            { max-amount: max-amount, rate: rate }
        )
        (ok true))
)

(define-public (claim-deduction (deduction-type (string-ascii 64)) (amount uint))
    (let (
        (deduction-info (unwrap! (map-get? deduction-types deduction-type) ERR_INVALID_AMOUNT))
    )
        (asserts! (<= amount (get max-amount deduction-info)) ERR_INVALID_AMOUNT)
        (map-set taxpayer-deductions
            { taxpayer: tx-sender, deduction-type: deduction-type }
            { amount: amount, approved: false }
        )
        (ok true))
)

(define-public (approve-deduction (taxpayer principal) (deduction-type (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set taxpayer-deductions
            { taxpayer: taxpayer, deduction-type: deduction-type }
            { 
                amount: (get amount (unwrap! (map-get? taxpayer-deductions { taxpayer: taxpayer, deduction-type: deduction-type }) ERR_INVALID_AMOUNT)),
                approved: true 
            }
        )
        (ok true))
)