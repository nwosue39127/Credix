
;; title: Credix
;; version:
;; summary:
;; description:


(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_LOAN_NOT_FOUND (err u103))
(define-constant ERR_LOAN_ALREADY_REPAID (err u104))
(define-constant ERR_INVALID_SCORE (err u105))
(define-constant ERR_USER_NOT_FOUND (err u106))
(define-constant ERR_LOAN_ACTIVE (err u107))

(define-map credit-profiles
  { user: principal }
  {
    score: uint,
    total-borrowed: uint,
    total-repaid: uint,
    active-loans: uint,
    payment-history: uint,
    last-updated: uint
  }
)

(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: principal,
    amount: uint,
    interest-rate: uint,
    duration: uint,
    start-block: uint,
    repaid: bool,
    repaid-amount: uint
  }
)

(define-map user-loans
  { user: principal, loan-index: uint }
  { loan-id: uint }
)

(define-map user-loan-counts
  { user: principal }
  { count: uint }
)

(define-data-var next-loan-id uint u1)
(define-data-var total-volume uint u0)

(define-read-only (get-credit-profile (user principal))
  (map-get? credit-profiles { user: user })
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-user-loan-count (user principal))
  (default-to u0 (get count (map-get? user-loan-counts { user: user })))
)

(define-read-only (get-user-loan-id (user principal) (index uint))
  (map-get? user-loans { user: user, loan-index: index })
)

(define-read-only (calculate-credit-score (user principal))
  (let (
    (profile (unwrap! (get-credit-profile user) u0))
    (total-borrowed (get total-borrowed profile))
    (total-repaid (get total-repaid profile))
    (active-loans (get active-loans profile))
    (payment-history (get payment-history profile))
  )
    (if (is-eq total-borrowed u0)
      u500
      (let (
        (repayment-ratio (/ (* total-repaid u100) total-borrowed))
        (activity-bonus u0)
        (active-penalty (if (> active-loans u3) u50 u0))
        (base-score (+ u300 (* repayment-ratio u4)))
        (adjusted-score (+ (- base-score active-penalty) activity-bonus))
      )
        (if (<= adjusted-score u850)
          (if (>= adjusted-score u300) adjusted-score u300)
          u850)
      )
    )
  )
)
(define-read-only (get-total-volume)
  (var-get total-volume)
)

(define-private (create-initial-profile (user principal))
  (map-set credit-profiles
    { user: user }
    {
      score: u500,
      total-borrowed: u0,
      total-repaid: u0,
      active-loans: u0,
      payment-history: u0,
      last-updated: stacks-block-height
    }
  )
)

(define-private (update-credit-profile (user principal) (borrowed uint) (repaid uint) (loan-change int))
  (let (
    (current-profile (default-to
      {
        score: u500,
        total-borrowed: u0,
        total-repaid: u0,
        active-loans: u0,
        payment-history: u0,
        last-updated: u0
      }
      (get-credit-profile user)
    ))
    (new-total-borrowed (+ (get total-borrowed current-profile) borrowed))
    (new-total-repaid (+ (get total-repaid current-profile) repaid))
    (new-active-loans (if (>= loan-change 0)
      (+ (get active-loans current-profile) (to-uint loan-change))
      (- (get active-loans current-profile) (to-uint (- loan-change)))
    ))
    (new-payment-history (if (> repaid u0)
      (+ (get payment-history current-profile) u1)
      (get payment-history current-profile)
    ))
  )
    (map-set credit-profiles
      { user: user }
      {
        score: (calculate-credit-score user),
        total-borrowed: new-total-borrowed,
        total-repaid: new-total-repaid,
        active-loans: new-active-loans,
        payment-history: new-payment-history,
        last-updated: stacks-block-height
      }
    )
  )
)

(define-public (create-loan (borrower principal) (amount uint) (interest-rate uint) (duration uint))
  (let (
    (loan-id (var-get next-loan-id))
    (user-loan-count (get-user-loan-count borrower))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= interest-rate u50) ERR_INVALID_AMOUNT)
    (asserts! (> duration u0) ERR_INVALID_AMOUNT)
    
    (if (is-none (get-credit-profile borrower))
      (create-initial-profile borrower)
      true
    )
    
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: borrower,
        lender: tx-sender,
        amount: amount,
        interest-rate: interest-rate,
        duration: duration,
        start-block: stacks-block-height,
        repaid: false,
        repaid-amount: u0
      }
    )
    
    (map-set user-loans
      { user: borrower, loan-index: user-loan-count }
      { loan-id: loan-id }
    )
    
    (map-set user-loan-counts
      { user: borrower }
      { count: (+ user-loan-count u1) }
    )
    
    (update-credit-profile borrower amount u0 1)
    (var-set next-loan-id (+ loan-id u1))
    (var-set total-volume (+ (var-get total-volume) amount))
    
    (ok loan-id)
  )
)

(define-public (repay-loan (loan-id uint) (amount uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (borrower (get borrower loan))
    (total-owed (+ (get amount loan) (/ (* (get amount loan) (get interest-rate loan)) u100)))
  )
    (asserts! (is-eq tx-sender borrower) ERR_UNAUTHORIZED)
    (asserts! (not (get repaid loan)) ERR_LOAN_ALREADY_REPAID)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (new-repaid-amount (+ (get repaid-amount loan) amount))
      (is-fully-repaid (>= new-repaid-amount total-owed))
    )
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          repaid: is-fully-repaid,
          repaid-amount: new-repaid-amount
        })
      )
      
      (update-credit-profile 
        borrower 
        u0 
        amount 
        (if is-fully-repaid -1 0)
      )
      
      (ok is-fully-repaid)
    )
  )
)

(define-public (register-user)
  (begin
    (asserts! (is-none (get-credit-profile tx-sender)) ERR_USER_NOT_FOUND)
    (create-initial-profile tx-sender)
    (ok true)
  )
)

(define-public (update-user-score (user principal))
  (let (
    (profile (unwrap! (get-credit-profile user) ERR_USER_NOT_FOUND))
    (new-score (calculate-credit-score user))
  )
    (map-set credit-profiles
      { user: user }
      (merge profile {
        score: new-score,
        last-updated: stacks-block-height
      })
    )
    (ok new-score)
  )
)

(define-read-only (get-loan-status (loan-id uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (total-owed (+ (get amount loan) (/ (* (get amount loan) (get interest-rate loan)) u100)))
    (blocks-elapsed (- stacks-block-height (get start-block loan)))
    (is-overdue (> blocks-elapsed (get duration loan)))
  )
    (ok {
      loan-id: loan-id,
      borrower: (get borrower loan),
      amount: (get amount loan),
      total-owed: total-owed,
      repaid-amount: (get repaid-amount loan),
      remaining: (- total-owed (get repaid-amount loan)),
      is-repaid: (get repaid loan),
      is-overdue: is-overdue,
      blocks-remaining: (if is-overdue u0 (- (get duration loan) blocks-elapsed))
    })
  )
)