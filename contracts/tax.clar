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


;; Tax Liability Prediction Engine

;; Constants for prediction algorithms
(define-constant ERR_INSUFFICIENT_DATA (err u103))
(define-constant ERR_PREDICTION_FAILED (err u104))
(define-constant MAX_PREDICTION_PERIODS u12)

;; Data Maps for prediction engine
(define-map balance-snapshots
    { taxpayer: principal, period: uint }
    { balance: uint, block-height: uint, trend-indicator: uint }
)

(define-map spending-patterns
    principal
    { 
        avg-monthly-spend: uint,
        volatility-score: uint,
        last-updated: uint,
        prediction-confidence: uint
    }
)

(define-map tax-predictions
    { taxpayer: principal, future-period: uint }
    {
        predicted-liability: uint,
        confidence-score: uint,
        calculated-at: uint,
        factors-used: uint
    }
)

(define-map taxpayer-risk-profiles
    principal
    {
        risk-score: uint,
        payment-reliability: uint,
        balance-stability: uint,
        prediction-accuracy: uint
    }
)

(define-map government-forecasts
    uint
    {
        period: uint,
        total-predicted-revenue: uint,
        confidence-level: uint,
        taxpayer-count: uint,
        created-at: uint
    }
)

;; Data Variables
(define-data-var snapshot-counter uint u0)
(define-data-var forecast-counter uint u0)
(define-data-var prediction-accuracy-threshold uint u80)

;; Helper function for minimum of two uints
(define-private (min (a uint) (b uint))
    (if (< a b) a b)
)

;; Core prediction functions
(define-public (record-balance-snapshot (taxpayer principal))
    (let
        (
            (current-balance (stx-get-balance taxpayer))
            (period-id (/ stacks-block-height u144))
            (snapshot-id (var-get snapshot-counter))
            (prev-snapshot (map-get? balance-snapshots { taxpayer: taxpayer, period: (- period-id u1) }))
            (trend (if (is-some prev-snapshot)
                      (if (> current-balance (get balance (unwrap-panic prev-snapshot))) u1 u0)
                      u1))
        )
        (map-set balance-snapshots
            { taxpayer: taxpayer, period: period-id }
            { 
                balance: current-balance,
                block-height: stacks-block-height,
                trend-indicator: trend
            }
        )
        (var-set snapshot-counter (+ snapshot-id u1))
        (ok snapshot-id))
)

(define-private (calculate-spending-volatility (taxpayer principal))
    (let
        (
            (current-period (/ stacks-block-height u144))
            (period-1 (map-get? balance-snapshots { taxpayer: taxpayer, period: (- current-period u1) }))
            (period-2 (map-get? balance-snapshots { taxpayer: taxpayer, period: (- current-period u2) }))
            (period-3 (map-get? balance-snapshots { taxpayer: taxpayer, period: (- current-period u3) }))
        )
        (if (and (is-some period-1) (is-some period-2) (is-some period-3))
            (let
                (
                    (balance-1 (get balance (unwrap-panic period-1)))
                    (balance-2 (get balance (unwrap-panic period-2)))
                    (balance-3 (get balance (unwrap-panic period-3)))
                    (change-1 (if (> balance-1 balance-2) (- balance-1 balance-2) (- balance-2 balance-1)))
                    (change-2 (if (> balance-2 balance-3) (- balance-2 balance-3) (- balance-3 balance-2)))
                    (avg-change (/ (+ change-1 change-2) u2))
                    (volatility (if (> avg-change u1000) (/ avg-change u100) u10))
                )
                (ok (min volatility u100)))
            (ok u50)))
)

(define-public (update-spending-pattern (taxpayer principal))
    (let
        (
            (current-period (/ stacks-block-height u144))
            (volatility-result (unwrap! (calculate-spending-volatility taxpayer) ERR_PREDICTION_FAILED))
            (current-balance (stx-get-balance taxpayer))
            (avg-spend (/ current-balance u30))
            (confidence (if (> volatility-result u70) u40 u80))
        )
        (map-set spending-patterns
            taxpayer
            {
                avg-monthly-spend: avg-spend,
                volatility-score: volatility-result,
                last-updated: stacks-block-height,
                prediction-confidence: confidence
            }
        )
        (ok true))
)

(define-public (generate-tax-prediction (taxpayer principal) (periods-ahead uint))
    (let
        (
            (pattern (unwrap! (map-get? spending-patterns taxpayer) ERR_INSUFFICIENT_DATA))
            (current-balance (stx-get-balance taxpayer))
            (tax-rate-value (var-get tax-rate))
            (volatility (get volatility-score pattern))
            (base-prediction (/ (* current-balance tax-rate-value) u1000))
            (volatility-adjustment (/ (* base-prediction volatility) u100))
            (adjusted-prediction (+ base-prediction volatility-adjustment))
            (time-factor (+ u100 (* periods-ahead u5)))
            (final-prediction (/ (* adjusted-prediction time-factor) u100))
            (confidence (if (< volatility u30) u90 (if (< volatility u70) u70 u40)))
        )
        (asserts! (<= periods-ahead MAX_PREDICTION_PERIODS) ERR_INVALID_AMOUNT)
        (map-set tax-predictions
            { taxpayer: taxpayer, future-period: periods-ahead }
            {
                predicted-liability: final-prediction,
                confidence-score: confidence,
                calculated-at: stacks-block-height,
                factors-used: u4
            }
        )
        (ok final-prediction))
)

(define-public (assess-taxpayer-risk (taxpayer principal))
    (let
        (
            (taxpayer-payment (get-tax-payment taxpayer))
            (pattern (map-get? spending-patterns taxpayer))
            (current-balance (stx-get-balance taxpayer))
            (base-risk (if (> taxpayer-payment u0) u20 u80))
            (balance-risk (if (> current-balance u10000) u10 u40))
            (volatility-risk (if (is-some pattern) 
                              (get volatility-score (unwrap-panic pattern)) 
                              u60))
            (total-risk (/ (+ base-risk balance-risk volatility-risk) u3))
            (reliability (if (> taxpayer-payment u0) u90 u30))
            (stability (if (< volatility-risk u30) u90 u50))
        )
        (map-set taxpayer-risk-profiles
            taxpayer
            {
                risk-score: total-risk,
                payment-reliability: reliability,
                balance-stability: stability,
                prediction-accuracy: u75
            }
        )
        (ok total-risk))
)

(define-public (create-government-forecast (period uint) (taxpayer-list (list 20 principal)))
    (let
        (
            (forecast-id (var-get forecast-counter))
            (total-predicted (fold calculate-taxpayer-contribution taxpayer-list u0))
            (taxpayer-count (len taxpayer-list))
            (confidence (if (> taxpayer-count u10) u85 u60))
        )
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set government-forecasts
            forecast-id
            {
                period: period,
                total-predicted-revenue: total-predicted,
                confidence-level: confidence,
                taxpayer-count: taxpayer-count,
                created-at: stacks-block-height
            }
        )
        (var-set forecast-counter (+ forecast-id u1))
        (ok total-predicted))
)

(define-private (calculate-taxpayer-contribution (taxpayer principal) (accumulator uint))
    (let
        (
            (balance (stx-get-balance taxpayer))
            (tax-liability (/ (* balance (var-get tax-rate)) u1000))
        )
        (+ accumulator tax-liability))
)

(define-public (validate-prediction-accuracy (taxpayer principal) (period uint) (actual-payment uint))
    (let
        (
            (prediction (unwrap! (map-get? tax-predictions { taxpayer: taxpayer, future-period: period }) ERR_INSUFFICIENT_DATA))
            (predicted-amount (get predicted-liability prediction))
            (accuracy-percentage (if (> predicted-amount actual-payment)
                                   (/ (* actual-payment u100) predicted-amount)
                                   (/ (* predicted-amount u100) actual-payment)))
            (current-profile (default-to 
                              { risk-score: u50, payment-reliability: u50, balance-stability: u50, prediction-accuracy: u50 }
                              (map-get? taxpayer-risk-profiles taxpayer)))
        )
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set taxpayer-risk-profiles
            taxpayer
            {
                risk-score: (get risk-score current-profile),
                payment-reliability: (get payment-reliability current-profile),
                balance-stability: (get balance-stability current-profile),
                prediction-accuracy: accuracy-percentage
            }
        )
        (ok accuracy-percentage))
)

;; Read-only functions
(define-read-only (get-tax-prediction (taxpayer principal) (period uint))
    (map-get? tax-predictions { taxpayer: taxpayer, future-period: period })
)

(define-read-only (get-taxpayer-risk-profile (taxpayer principal))
    (map-get? taxpayer-risk-profiles taxpayer)
)

(define-read-only (get-spending-pattern (taxpayer principal))
    (map-get? spending-patterns taxpayer)
)

(define-read-only (get-government-forecast (forecast-id uint))
    (map-get? government-forecasts forecast-id)
)

(define-read-only (get-balance-snapshot (taxpayer principal) (period uint))
    (map-get? balance-snapshots { taxpayer: taxpayer, period: period })
)

(define-read-only (calculate-recommended-savings (taxpayer principal) (target-period uint))
    (let
        (
            (prediction (map-get? tax-predictions { taxpayer: taxpayer, future-period: target-period }))
            (current-balance (stx-get-balance taxpayer))
        )
        (if (is-some prediction)
            (let
                (
                    (predicted-liability (get predicted-liability (unwrap-panic prediction)))
                    (recommended-savings (/ predicted-liability u12))
                )
                (ok { monthly-savings: recommended-savings, total-needed: predicted-liability }))
            ERR_INSUFFICIENT_DATA))
)

(define-read-only (get-prediction-metrics)
    (ok {
        total-snapshots: (var-get snapshot-counter),
        total-forecasts: (var-get forecast-counter),
        accuracy-threshold: (var-get prediction-accuracy-threshold),
        max-prediction-periods: MAX_PREDICTION_PERIODS
    })
)


;; Tax Compliance Rewards System

;; Constants for rewards system
(define-constant ERR_INSUFFICIENT_POINTS (err u200))
(define-constant ERR_INVALID_REWARD (err u201))
(define-constant ERR_TRANSFER_FAILED (err u202))
(define-constant ERR_REWARD_EXPIRED (err u203))

;; Reward multipliers and base values
(define-constant EARLY_PAYMENT_MULTIPLIER u150) ;; 1.5x points for early payment
(define-constant ON_TIME_BASE_POINTS u100)
(define-constant LATE_PAYMENT_PENALTY u50) ;; 50% points reduction
(define-constant CONSISTENCY_BONUS u200) ;; Bonus for 5+ consecutive on-time payments
(define-constant REFERRAL_BONUS u300) ;; Points for successful referrals

;; Data Maps for rewards system
(define-map taxpayer-points
    principal
    {
        total-points: uint,
        lifetime-earned: uint,
        current-streak: uint,
        last-earning-block: uint,
        tier-level: uint
    }
)

(define-map reward-tiers
    uint
    {
        name: (string-ascii 32),
        points-required: uint,
        discount-percentage: uint,
        special-benefits: (string-ascii 128),
        active: bool
    }
)

(define-map available-rewards
    uint
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        cost-in-points: uint,
        discount-percentage: uint,
        max-uses: uint,
        current-uses: uint,
        expiry-block: uint,
        reward-type: (string-ascii 32),
        active: bool
    }
)

(define-map user-reward-redemptions
    { user: principal, reward-id: uint }
    {
        redeemed-at: uint,
        discount-applied: uint,
        expires-at: uint,
        used: bool
    }
)

(define-map point-transfers
    uint
    {
        from: principal,
        to: principal,
        amount: uint,
        transferred-at: uint,
        reason: (string-ascii 128)
    }
)

(define-map taxpayer-achievements
    { user: principal, achievement-id: uint }
    {
        earned-at: uint,
        points-awarded: uint,
        achievement-name: (string-ascii 64)
    }
)

(define-map seasonal-bonuses
    uint
    {
        season-name: (string-ascii 32),
        multiplier: uint,
        start-block: uint,
        end-block: uint,
        active: bool
    }
)

;; Data Variables for rewards system
(define-data-var rewards-counter uint u0)
(define-data-var transfer-counter uint u0)
(define-data-var achievement-counter uint u0)
(define-data-var season-counter uint u0)
(define-data-var points-to-stx-rate uint u1000) ;; 1000 points = 1 STX discount

;; Helper function to get current tier level
(define-private (calculate-tier-level (total-points uint))
    (if (>= total-points u50000) u5
        (if (>= total-points u20000) u4
            (if (>= total-points u10000) u3
                (if (>= total-points u5000) u2
                    (if (>= total-points u1000) u1 u0)))))
)

;; Initialize default reward tiers
(define-public (initialize-reward-tiers)
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set reward-tiers u0 {name: "BRONZE", points-required: u1000, discount-percentage: u5, special-benefits: "Basic tax reminders", active: true})
        (map-set reward-tiers u1 {name: "SILVER", points-required: u5000, discount-percentage: u10, special-benefits: "Priority support, quarterly reports", active: true})
        (map-set reward-tiers u2 {name: "GOLD", points-required: u10000, discount-percentage: u15, special-benefits: "Personal tax advisor access", active: true})
        (map-set reward-tiers u3 {name: "PLATINUM", points-required: u20000, discount-percentage: u20, special-benefits: "Custom payment plans, early access", active: true})
        (map-set reward-tiers u4 {name: "DIAMOND", points-required: u50000, discount-percentage: u25, special-benefits: "VIP status, special recognition", active: true})
        (ok true))
)

;; Award points for various tax compliance activities
(define-public (award-points-for-payment (taxpayer principal) (payment-amount uint) (payment-timing (string-ascii 16)))
    (let
        (
            (current-data (default-to {total-points: u0, lifetime-earned: u0, current-streak: u0, last-earning-block: u0, tier-level: u0} 
                          (map-get? taxpayer-points taxpayer)))
            (base-points (/ payment-amount u100)) ;; 1 point per 100 units paid
            (timing-multiplier (if (is-eq payment-timing "EARLY") EARLY_PAYMENT_MULTIPLIER
                               (if (is-eq payment-timing "ON_TIME") u100 LATE_PAYMENT_PENALTY)))
            (points-earned (/ (* base-points timing-multiplier) u100))
            (new-streak (if (is-eq payment-timing "LATE") u0 (+ (get current-streak current-data) u1)))
            (streak-bonus (if (>= new-streak u5) CONSISTENCY_BONUS u0))
            (total-points-earned (+ points-earned streak-bonus))
            (new-total-points (+ (get total-points current-data) total-points-earned))
            (new-tier (calculate-tier-level new-total-points))
        )
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set taxpayer-points
            taxpayer
            {
                total-points: new-total-points,
                lifetime-earned: (+ (get lifetime-earned current-data) total-points-earned),
                current-streak: new-streak,
                last-earning-block: stacks-block-height,
                tier-level: new-tier
            }
        )
        (ok total-points-earned))
)

;; Create new rewards that users can redeem
(define-public (create-reward (name (string-ascii 64)) (description (string-ascii 256)) (cost uint) (discount uint) (max-uses uint) (duration-blocks uint) (reward-type (string-ascii 32)))
    (let
        (
            (reward-id (var-get rewards-counter))
            (expiry-block (+ stacks-block-height duration-blocks))
        )
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (asserts! (<= discount u100) ERR_INVALID_AMOUNT)
        (map-set available-rewards
            reward-id
            {
                name: name,
                description: description,
                cost-in-points: cost,
                discount-percentage: discount,
                max-uses: max-uses,
                current-uses: u0,
                expiry-block: expiry-block,
                reward-type: reward-type,
                active: true
            }
        )
        (var-set rewards-counter (+ reward-id u1))
        (ok reward-id))
)

;; Redeem points for rewards
(define-public (redeem-reward (reward-id uint))
    (let
        (
            (user-data (unwrap! (map-get? taxpayer-points tx-sender) ERR_INSUFFICIENT_POINTS))
            (reward-data (unwrap! (map-get? available-rewards reward-id) ERR_INVALID_REWARD))
            (cost (get cost-in-points reward-data))
            (current-uses (get current-uses reward-data))
            (max-uses (get max-uses reward-data))
        )
        (asserts! (get active reward-data) ERR_INVALID_REWARD)
        (asserts! (< stacks-block-height (get expiry-block reward-data)) ERR_REWARD_EXPIRED)
        (asserts! (>= (get total-points user-data) cost) ERR_INSUFFICIENT_POINTS)
        (asserts! (< current-uses max-uses) ERR_INVALID_REWARD)
        
        ;; Update user points
        (map-set taxpayer-points
            tx-sender
            {
                total-points: (- (get total-points user-data) cost),
                lifetime-earned: (get lifetime-earned user-data),
                current-streak: (get current-streak user-data),
                last-earning-block: (get last-earning-block user-data),
                tier-level: (get tier-level user-data)
            }
        )
        
        ;; Update reward usage
        (map-set available-rewards
            reward-id
            {
                name: (get name reward-data),
                description: (get description reward-data),
                cost-in-points: cost,
                discount-percentage: (get discount-percentage reward-data),
                max-uses: max-uses,
                current-uses: (+ current-uses u1),
                expiry-block: (get expiry-block reward-data),
                reward-type: (get reward-type reward-data),
                active: (get active reward-data)
            }
        )
        
        ;; Record redemption
        (map-set user-reward-redemptions
            { user: tx-sender, reward-id: reward-id }
            {
                redeemed-at: stacks-block-height,
                discount-applied: (get discount-percentage reward-data),
                expires-at: (+ stacks-block-height u1440), ;; Valid for ~10 days
                used: false
            }
        )
        (ok true))
)

;; Transfer points between users
(define-public (transfer-points (recipient principal) (amount uint) (reason (string-ascii 128)))
    (let
        (
            (sender-data (unwrap! (map-get? taxpayer-points tx-sender) ERR_INSUFFICIENT_POINTS))
            (recipient-data (default-to {total-points: u0, lifetime-earned: u0, current-streak: u0, last-earning-block: u0, tier-level: u0} 
                            (map-get? taxpayer-points recipient)))
            (transfer-id (var-get transfer-counter))
        )
        (asserts! (>= (get total-points sender-data) amount) ERR_INSUFFICIENT_POINTS)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        ;; Update sender points
        (map-set taxpayer-points
            tx-sender
            {
                total-points: (- (get total-points sender-data) amount),
                lifetime-earned: (get lifetime-earned sender-data),
                current-streak: (get current-streak sender-data),
                last-earning-block: (get last-earning-block sender-data),
                tier-level: (calculate-tier-level (- (get total-points sender-data) amount))
            }
        )
        
        ;; Update recipient points
        (map-set taxpayer-points
            recipient
            {
                total-points: (+ (get total-points recipient-data) amount),
                lifetime-earned: (get lifetime-earned recipient-data),
                current-streak: (get current-streak recipient-data),
                last-earning-block: (get last-earning-block recipient-data),
                tier-level: (calculate-tier-level (+ (get total-points recipient-data) amount))
            }
        )
        
        ;; Record transfer
        (map-set point-transfers
            transfer-id
            {
                from: tx-sender,
                to: recipient,
                amount: amount,
                transferred-at: stacks-block-height,
                reason: reason
            }
        )
        (var-set transfer-counter (+ transfer-id u1))
        (ok transfer-id))
)

;; Award achievement points
(define-public (award-achievement (user principal) (achievement-name (string-ascii 64)) (points uint))
    (let
        (
            (achievement-id (var-get achievement-counter))
            (user-data (default-to {total-points: u0, lifetime-earned: u0, current-streak: u0, last-earning-block: u0, tier-level: u0} 
                       (map-get? taxpayer-points user)))
        )
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        
        ;; Record achievement
        (map-set taxpayer-achievements
            { user: user, achievement-id: achievement-id }
            {
                earned-at: stacks-block-height,
                points-awarded: points,
                achievement-name: achievement-name
            }
        )
        
        ;; Update user points
        (map-set taxpayer-points
            user
            {
                total-points: (+ (get total-points user-data) points),
                lifetime-earned: (+ (get lifetime-earned user-data) points),
                current-streak: (get current-streak user-data),
                last-earning-block: stacks-block-height,
                tier-level: (calculate-tier-level (+ (get total-points user-data) points))
            }
        )
        (var-set achievement-counter (+ achievement-id u1))
        (ok achievement-id))
)

;; Create seasonal bonus periods
(define-public (create-seasonal-bonus (season-name (string-ascii 32)) (multiplier uint) (duration-blocks uint))
    (let
        (
            (season-id (var-get season-counter))
            (start-block stacks-block-height)
            (end-block (+ start-block duration-blocks))
        )
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set seasonal-bonuses
            season-id
            {
                season-name: season-name,
                multiplier: multiplier,
                start-block: start-block,
                end-block: end-block,
                active: true
            }
        )
        (var-set season-counter (+ season-id u1))
        (ok season-id))
)

;; Read-only functions for rewards system
(define-read-only (get-user-points (user principal))
    (map-get? taxpayer-points user)
)

(define-read-only (get-user-tier-info (user principal))
    (let
        (
            (user-data (map-get? taxpayer-points user))
        )
        (if (is-some user-data)
            (let
                (
                    (tier-level (get tier-level (unwrap-panic user-data)))
                    (tier-info (map-get? reward-tiers tier-level))
                )
                (ok { user-tier: tier-level, tier-benefits: tier-info }))
            ERR_INSUFFICIENT_POINTS))
)

(define-read-only (get-available-reward (reward-id uint))
    (map-get? available-rewards reward-id)
)

(define-read-only (get-user-redemption (user principal) (reward-id uint))
    (map-get? user-reward-redemptions { user: user, reward-id: reward-id })
)

(define-read-only (get-point-transfer (transfer-id uint))
    (map-get? point-transfers transfer-id)
)

(define-read-only (calculate-tax-discount (user principal))
    (let
        (
            (user-data (map-get? taxpayer-points user))
        )
        (if (is-some user-data)
            (let
                (
                    (tier-level (get tier-level (unwrap-panic user-data)))
                    (tier-info (map-get? reward-tiers tier-level))
                )
                (if (is-some tier-info)
                    (ok (get discount-percentage (unwrap-panic tier-info)))
                    (ok u0)))
            (ok u0)))
)

(define-read-only (get-rewards-summary)
    (ok {
        total-rewards-created: (var-get rewards-counter),
        total-point-transfers: (var-get transfer-counter),
        total-achievements: (var-get achievement-counter),
        active-seasons: (var-get season-counter),
        points-to-stx-rate: (var-get points-to-stx-rate)
    })
)


