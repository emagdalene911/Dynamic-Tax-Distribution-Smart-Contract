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


(define-non-fungible-token tax-receipt uint)

(define-map receipt-details 
    uint 
    {
        payment-amount: uint,
        payment-date: uint,
        tax-year: uint,
        category: (string-ascii 64)
    }
)

(define-data-var receipt-counter uint u0)

(define-public (mint-tax-receipt (payment-amount uint) (tax-year uint) (category (string-ascii 64)))
    (let
        (
            (receipt-id (var-get receipt-counter))
        )
        (try! (nft-mint? tax-receipt receipt-id tx-sender))
        (map-set receipt-details
            receipt-id
            {
                payment-amount: payment-amount,
                payment-date: stacks-block-height,
                tax-year: tax-year,
                category: category
            }
        )
        (var-set receipt-counter (+ receipt-id u1))
        (ok receipt-id))
)

(define-read-only (get-receipt-details (receipt-id uint))
    (map-get? receipt-details receipt-id)
)


(define-map distribution-rules
    (string-ascii 64)
    {
        percentage: uint,
        priority: uint,
        min-allocation: uint
    }
)

(define-map distribution-totals
    (string-ascii 64)
    {
        allocated: uint,
        last-distribution: uint
    }
)

(define-public (set-distribution-rule (department (string-ascii 64)) (percentage uint) (priority uint) (min-allocation uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= percentage u1000) ERR_INVALID_AMOUNT)
        (map-set distribution-rules
            department
            {
                percentage: percentage,
                priority: priority,
                min-allocation: min-allocation
            }
        )
        (ok true))
)

(define-public (auto-distribute-tax (amount uint))
    (let
        (
            (health-share (/ (* amount u300) u1000))
            (education-share (/ (* amount u200) u1000))
            (infrastructure-share (/ (* amount u200) u1000))
            (emergency-share (/ (* amount u100) u1000))
            (misc-share (/ (* amount u200) u1000))
        )
        (begin
            (try! (allocate-funds "HEALTH" health-share))
            (try! (allocate-funds "EDUCATION" education-share))
            (try! (allocate-funds "INFRASTRUCTURE" infrastructure-share))
            (try! (allocate-funds "EMERGENCY" emergency-share))
            (try! (allocate-funds "MISCELLANEOUS" misc-share))
            (ok true)))
)


(define-map audit-events
    uint
    {
        event-type: (string-ascii 32),
        actor: principal,
        target: (optional principal),
        amount: uint,
        description: (string-ascii 128),
        timestamp: uint,
        block-height: uint,
        transaction-hash: (buff 32)
    }
)

(define-data-var audit-counter uint u0)

(define-map audit-categories
    (string-ascii 32)
    {
        total-events: uint,
        total-amount: uint,
        last-event: uint
    }
)

(define-map actor-audit-summary
    principal
    {
        total-events: uint,
        total-paid: uint,
        total-received: uint,
        last-activity: uint
    }
)

(define-private (log-audit-event (event-type (string-ascii 32)) (target (optional principal)) (amount uint) (description (string-ascii 128)))
    (let
        (
            (event-id (var-get audit-counter))
            (current-category (default-to {total-events: u0, total-amount: u0, last-event: u0} (map-get? audit-categories event-type)))
            (current-actor-summary (default-to {total-events: u0, total-paid: u0, total-received: u0, last-activity: u0} (map-get? actor-audit-summary tx-sender)))
        )
        (map-set audit-events
            event-id
            {
                event-type: event-type,
                actor: tx-sender,
                target: target,
                amount: amount,
                description: description,
                timestamp: stacks-block-height,
                block-height: stacks-block-height,
                transaction-hash: (unwrap-panic (get-stacks-block-info? header-hash stacks-block-height))
            }
        )
        (map-set audit-categories
            event-type
            {
                total-events: (+ (get total-events current-category) u1),
                total-amount: (+ (get total-amount current-category) amount),
                last-event: event-id
            }
        )
        (map-set actor-audit-summary
            tx-sender
            {
                total-events: (+ (get total-events current-actor-summary) u1),
                total-paid: (if (is-eq event-type "TAX_PAYMENT") (+ (get total-paid current-actor-summary) amount) (get total-paid current-actor-summary)),
                total-received: (if (is-eq event-type "REFUND") (+ (get total-received current-actor-summary) amount) (get total-received current-actor-summary)),
                last-activity: stacks-block-height
            }
        )
        (var-set audit-counter (+ event-id u1))
        (ok event-id))
)

(define-public (pay-tax-with-audit)
    (let
        (
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
                (unwrap! (log-audit-event "TAX_PAYMENT" (some (var-get government-address)) payment-amount "Regular tax payment") (err u102))
                (ok true))
            ERR_INVALID_AMOUNT))
)

(define-public (allocate-funds-with-audit (department (string-ascii 64)) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR_INVALID_AMOUNT)
        (map-set fund-allocations {department: department} amount)
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (unwrap! (log-audit-event "FUND_ALLOCATION" none amount (concat "Funds allocated to department: " department)) (err u102))
        (ok true))
)

(define-public (process-tax-refund-with-audit (recipient principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? amount (var-get government-address) recipient))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (unwrap! (log-audit-event "REFUND" (some recipient) amount "Tax refund processed") (err u102))
        (ok true))
)

(define-read-only (get-audit-event (event-id uint))
    (map-get? audit-events event-id)
)

(define-read-only (get-audit-category-summary (category (string-ascii 32)))
    (map-get? audit-categories category)
)

(define-read-only (get-actor-audit-summary (actor principal))
    (map-get? actor-audit-summary actor)
)

(define-read-only (get-total-audit-events)
    (var-get audit-counter)
)

(define-public (generate-audit-report (start-block uint) (end-block uint))
    (let
        (
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= start-block end-block) ERR_INVALID_AMOUNT)
        (asserts! (<= end-block current-block) ERR_INVALID_AMOUNT)
        (unwrap! (log-audit-event "AUDIT_REPORT" none u0 "Audit report generated") (err u102))
        (ok {start-block: start-block, end-block: end-block, generated-at: current-block}))
)

(define-read-only (verify-transaction-integrity (event-id uint))
    (let
        (
            (event-data (unwrap! (map-get? audit-events event-id) (err u404)))
        )
        (ok {
            event-id: event-id,
            verified: true,
            block-height: (get block-height event-data),
            transaction-hash: (get transaction-hash event-data)
        }))
)

(define-public (flag-suspicious-activity (target-principal principal) (reason (string-ascii 128)))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (unwrap! (log-audit-event "SUSPICIOUS_ACTIVITY" (some target-principal) u0 reason) (err u102))
        (ok true))
)

(define-read-only (get-compliance-status (actor principal))
    (let
        (
            (actor-summary (default-to {total-events: u0, total-paid: u0, total-received: u0, last-activity: u0} (map-get? actor-audit-summary actor)))
            (days-since-activity (- stacks-block-height (get last-activity actor-summary)))
        )
        (ok {
            total-transactions: (get total-events actor-summary),
            total-paid: (get total-paid actor-summary),
            total-received: (get total-received actor-summary),
            days-inactive: days-since-activity,
            compliance-score: (if (> (get total-paid actor-summary) u0) u100 u0)
        }))
)