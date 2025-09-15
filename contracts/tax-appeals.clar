;; Tax Appeals and Review System
;; Provides formal dispute resolution and appeal processes for tax assessments

;; Constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_APPEAL (err u301))
(define-constant ERR_APPEAL_CLOSED (err u302))
(define-constant ERR_INSUFFICIENT_EVIDENCE (err u303))

;; Appeal statuses
(define-constant STATUS_PENDING "PENDING")
(define-constant STATUS_UNDER_REVIEW "UNDER_REVIEW") 
(define-constant STATUS_APPROVED "APPROVED")
(define-constant STATUS_REJECTED "REJECTED")
(define-constant STATUS_ESCALATED "ESCALATED")

;; Appeal types
(define-constant TYPE_ASSESSMENT_ERROR "ASSESSMENT_ERROR")
(define-constant TYPE_CALCULATION_DISPUTE "CALCULATION_DISPUTE")
(define-constant TYPE_EXEMPTION_CLAIM "EXEMPTION_CLAIM")
(define-constant TYPE_PENALTY_CHALLENGE "PENALTY_CHALLENGE")

;; Main appeal tracking
(define-map tax-appeals
    (tuple (taxpayer principal) (appeal-id uint))
    (tuple
        (appeal-type (string-ascii 32))
        (disputed-amount uint)
        (original-assessment uint)
        (reason (string-ascii 256))
        (evidence-hash (string-ascii 64))
        (status (string-ascii 16))
        (filed-at uint)
        (review-deadline uint)
        (reviewer (optional principal))
        (decision (optional (string-ascii 128)))
        (adjusted-amount uint)
    )
)

;; Review officer registry
(define-map review-officers
    principal
    (tuple
        (active bool)
        (cases-handled uint)
        (approval-rate uint)
        (specialization (string-ascii 32))
        (assigned-cases uint)
    )
)

;; Appeal history for analytics
(define-map appeal-statistics
    (string-ascii 32)
    (tuple
        (total-appeals uint)
        (approved-appeals uint)
        (average-resolution-time uint)
        (total-amount-disputed uint)
        (total-amount-adjusted uint)
    )
)

;; System variables
(define-data-var government-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-map appeal-counter principal uint)
(define-data-var review-period uint u1440) ;; ~10 days in blocks
(define-data-var max-appeal-amount uint u100000)

;; Register a review officer
(define-public (register-review-officer (officer principal) (specialization (string-ascii 32)))
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (map-set review-officers officer
            (tuple
                (active true)
                (cases-handled u0)
                (approval-rate u50)
                (specialization specialization)
                (assigned-cases u0)
            ))
        (ok "Review officer registered successfully")
    )
)

;; File a tax appeal
(define-public (file-tax-appeal 
    (appeal-type (string-ascii 32))
    (disputed-amount uint)
    (original-assessment uint) 
    (reason (string-ascii 256))
    (evidence-hash (string-ascii 64))
)
    (let 
        ((current-count (default-to u0 (map-get? appeal-counter tx-sender)))
         (appeal-id (+ current-count u1)))
        (begin
            (asserts! (or (is-eq appeal-type TYPE_ASSESSMENT_ERROR)
                         (is-eq appeal-type TYPE_CALCULATION_DISPUTE)
                         (is-eq appeal-type TYPE_EXEMPTION_CLAIM)
                         (is-eq appeal-type TYPE_PENALTY_CHALLENGE))
                     ERR_INVALID_APPEAL)
            (asserts! (<= disputed-amount (var-get max-appeal-amount)) ERR_INVALID_APPEAL)
            (asserts! (> (len evidence-hash) u0) ERR_INSUFFICIENT_EVIDENCE)
            
            (map-set appeal-counter tx-sender appeal-id)
            (map-set tax-appeals (tuple (taxpayer tx-sender) (appeal-id appeal-id))
                (tuple
                    (appeal-type appeal-type)
                    (disputed-amount disputed-amount)
                    (original-assessment original-assessment)
                    (reason reason)
                    (evidence-hash evidence-hash)
                    (status STATUS_PENDING)
                    (filed-at stacks-block-height)
                    (review-deadline (+ stacks-block-height (var-get review-period)))
                    (reviewer none)
                    (decision none)
                    (adjusted-amount u0)
                ))
            
            ;; Update statistics
            (let ((current-stats (default-to 
                    (tuple (total-appeals u0) (approved-appeals u0) (average-resolution-time u0) 
                           (total-amount-disputed u0) (total-amount-adjusted u0))
                    (map-get? appeal-statistics appeal-type))))
                (map-set appeal-statistics appeal-type
                    (tuple
                        (total-appeals (+ (get total-appeals current-stats) u1))
                        (approved-appeals (get approved-appeals current-stats))
                        (average-resolution-time (get average-resolution-time current-stats))
                        (total-amount-disputed (+ (get total-amount-disputed current-stats) disputed-amount))
                        (total-amount-adjusted (get total-amount-adjusted current-stats))
                    )))
            (ok appeal-id)
        )
    )
)

;; Assign reviewer to appeal
(define-public (assign-reviewer (taxpayer principal) (appeal-id uint) (reviewer principal))
    (let 
        ((appeal-key (tuple (taxpayer taxpayer) (appeal-id appeal-id)))
         (appeal (unwrap! (map-get? tax-appeals appeal-key) ERR_INVALID_APPEAL))
         (officer-data (unwrap! (map-get? review-officers reviewer) ERR_UNAUTHORIZED)))
        (begin
            (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status appeal) STATUS_PENDING) ERR_APPEAL_CLOSED)
            (asserts! (get active officer-data) ERR_UNAUTHORIZED)
            
            (map-set tax-appeals appeal-key
                (merge appeal (tuple 
                    (reviewer (some reviewer))
                    (status STATUS_UNDER_REVIEW)
                )))
            
            ;; Update officer assignment count
            (map-set review-officers reviewer
                (merge officer-data (tuple 
                    (assigned-cases (+ (get assigned-cases officer-data) u1))
                )))
            (ok "Reviewer assigned successfully")
        )
    )
)

;; Submit additional evidence
(define-public (submit-additional-evidence 
    (appeal-id uint) 
    (evidence-hash (string-ascii 64))
)
    (let 
        ((appeal-key (tuple (taxpayer tx-sender) (appeal-id appeal-id)))
         (appeal (unwrap! (map-get? tax-appeals appeal-key) ERR_INVALID_APPEAL)))
        (begin
            (asserts! (is-eq (get status appeal) STATUS_UNDER_REVIEW) ERR_APPEAL_CLOSED)
            (asserts! (> (len evidence-hash) u0) ERR_INSUFFICIENT_EVIDENCE)
            
            (map-set tax-appeals appeal-key
                (merge appeal (tuple (evidence-hash evidence-hash))))
            (ok "Additional evidence submitted")
        )
    )
)

;; Resolve appeal (reviewer only)
(define-public (resolve-appeal 
    (taxpayer principal) 
    (appeal-id uint) 
    (approved bool)
    (decision (string-ascii 128))
    (adjusted-amount uint)
)
    (let 
        ((appeal-key (tuple (taxpayer taxpayer) (appeal-id appeal-id)))
         (appeal (unwrap! (map-get? tax-appeals appeal-key) ERR_INVALID_APPEAL))
         (reviewer-addr (unwrap! (get reviewer appeal) ERR_UNAUTHORIZED))
         (officer-data (unwrap! (map-get? review-officers reviewer-addr) ERR_UNAUTHORIZED)))
        (begin
            (asserts! (is-eq tx-sender reviewer-addr) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status appeal) STATUS_UNDER_REVIEW) ERR_APPEAL_CLOSED)
            
            (let ((new-status (if approved STATUS_APPROVED STATUS_REJECTED)))
                (map-set tax-appeals appeal-key
                    (merge appeal (tuple 
                        (status new-status)
                        (decision (some decision))
                        (adjusted-amount adjusted-amount)
                    )))
                
                ;; Update officer stats
                (let ((cases-handled (+ (get cases-handled officer-data) u1))
                      (current-approvals (get approval-rate officer-data))
                      (new-approval-rate (if approved 
                                           (+ current-approvals u10)
                                           (if (> current-approvals u10) (- current-approvals u5) u0))))
                    (map-set review-officers reviewer-addr
                        (merge officer-data (tuple 
                            (cases-handled cases-handled)
                            (approval-rate new-approval-rate)
                            (assigned-cases (- (get assigned-cases officer-data) u1))
                        ))))
                
                ;; Update type statistics
                (let ((appeal-type (get appeal-type appeal))
                      (current-stats (default-to 
                          (tuple (total-appeals u0) (approved-appeals u0) (average-resolution-time u0) 
                                 (total-amount-disputed u0) (total-amount-adjusted u0))
                          (map-get? appeal-statistics appeal-type))))
                    (map-set appeal-statistics appeal-type
                        (tuple
                            (total-appeals (get total-appeals current-stats))
                            (approved-appeals (if approved 
                                               (+ (get approved-appeals current-stats) u1)
                                               (get approved-appeals current-stats)))
                            (average-resolution-time (/ (+ (* (get average-resolution-time current-stats) 
                                                          (get total-appeals current-stats))
                                                      (- stacks-block-height (get filed-at appeal)))
                                                   (get total-appeals current-stats)))
                            (total-amount-disputed (get total-amount-disputed current-stats))
                            (total-amount-adjusted (+ (get total-amount-adjusted current-stats) adjusted-amount))
                        ))))
            (ok "Appeal resolved successfully")
        )
    )
)

;; Escalate appeal to higher authority
(define-public (escalate-appeal (taxpayer principal) (appeal-id uint))
    (let 
        ((appeal-key (tuple (taxpayer taxpayer) (appeal-id appeal-id)))
         (appeal (unwrap! (map-get? tax-appeals appeal-key) ERR_INVALID_APPEAL)))
        (begin
            (asserts! (or (is-eq tx-sender taxpayer) (is-eq tx-sender (var-get government-address))) 
                     ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status appeal) STATUS_REJECTED) ERR_INVALID_APPEAL)
            
            (map-set tax-appeals appeal-key
                (merge appeal (tuple (status STATUS_ESCALATED))))
            (ok "Appeal escalated to higher authority")
        )
    )
)

;; Read-only functions
(define-read-only (get-appeal (taxpayer principal) (appeal-id uint))
    (map-get? tax-appeals (tuple (taxpayer taxpayer) (appeal-id appeal-id)))
)

(define-read-only (get-review-officer (officer principal))
    (map-get? review-officers officer)
)

(define-read-only (get-appeal-statistics (appeal-type (string-ascii 32)))
    (map-get? appeal-statistics appeal-type)
)

(define-read-only (get-taxpayer-appeals-count (taxpayer principal))
    (default-to u0 (map-get? appeal-counter taxpayer))
)

;; System administration
(define-public (update-system-parameters 
    (new-government principal)
    (new-review-period uint)
    (new-max-amount uint)
)
    (begin
        (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
        (var-set government-address new-government)
        (var-set review-period new-review-period)
        (var-set max-appeal-amount new-max-amount)
        (ok "System parameters updated")
    )
)

(define-public (deactivate-review-officer (officer principal))
    (let ((officer-data (unwrap! (map-get? review-officers officer) ERR_UNAUTHORIZED)))
        (begin
            (asserts! (is-eq tx-sender (var-get government-address)) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get assigned-cases officer-data) u0) ERR_INVALID_APPEAL)
            
            (map-set review-officers officer
                (merge officer-data (tuple (active false))))
            (ok "Review officer deactivated")
        )
    )
)
