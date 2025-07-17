
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
(define-constant ERR_GUARANTOR_NOT_FOUND (err u108))
(define-constant ERR_ALREADY_GUARANTOR (err u109))
(define-constant ERR_SELF_GUARANTEE (err u110))
(define-constant ERR_INSUFFICIENT_GUARANTEE_CAPACITY (err u111))
(define-constant ERR_GUARANTEE_NOT_FOUND (err u112))
(define-constant ERR_GUARANTEE_ALREADY_CLAIMED (err u113))
(define-constant ERR_GUARANTEE_EXPIRED (err u114))

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

(define-map guarantor-profiles
  { guarantor: principal }
  {
    total-guaranteed: uint,
    active-guarantees: uint,
    successful-guarantees: uint,
    failed-guarantees: uint,
    reputation-score: uint,
    max-guarantee-capacity: uint,
    last-updated: uint
  }
)

(define-map loan-guarantees
  { loan-id: uint }
  {
    guarantor: principal,
    guarantee-amount: uint,
    guarantee-percentage: uint,
    created-at: uint,
    is-active: bool,
    claimed: bool
  }
)

(define-map guarantor-obligations
  { guarantor: principal, loan-id: uint }
  {
    guaranteed-amount: uint,
    liability-amount: uint,
    is-liable: bool,
    settled: bool
  }
)

(define-map guarantor-loan-counts
  { guarantor: principal }
  { count: uint }
)

(define-map guarantor-loans
  { guarantor: principal, loan-index: uint }
  { loan-id: uint }
)

(define-data-var next-loan-id uint u1)
(define-data-var total-volume uint u0)
(define-data-var total-guaranteed-volume uint u0)

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

(define-read-only (get-guarantor-profile (guarantor principal))
  (map-get? guarantor-profiles { guarantor: guarantor })
)

(define-read-only (get-loan-guarantee (loan-id uint))
  (map-get? loan-guarantees { loan-id: loan-id })
)

(define-read-only (get-guarantor-obligation (guarantor principal) (loan-id uint))
  (map-get? guarantor-obligations { guarantor: guarantor, loan-id: loan-id })
)

(define-read-only (get-guarantor-loan-count (guarantor principal))
  (default-to u0 (get count (map-get? guarantor-loan-counts { guarantor: guarantor })))
)

(define-read-only (get-guarantor-loan-id (guarantor principal) (index uint))
  (map-get? guarantor-loans { guarantor: guarantor, loan-index: index })
)

(define-read-only (calculate-guarantor-reputation (guarantor principal))
  (let (
    (profile (unwrap! (get-guarantor-profile guarantor) u0))
    (total-guaranteed (get total-guaranteed profile))
    (successful-guarantees (get successful-guarantees profile))
    (failed-guarantees (get failed-guarantees profile))
  )
    (if (is-eq total-guaranteed u0)
      u500
      (let (
        (success-rate (/ (* successful-guarantees u100) (+ successful-guarantees failed-guarantees)))
        (base-score (+ u300 (* success-rate u5)))
        (volume-bonus (if (<= (/ total-guaranteed u10000) u50) (/ total-guaranteed u10000) u50))
        (final-score (+ base-score volume-bonus))
      )
        (if (<= final-score u850)
          (if (>= final-score u300) final-score u300)
          u850)
      )
    )
  )
)

(define-read-only (get-total-guaranteed-volume)
  (var-get total-guaranteed-volume)
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

(define-private (create-initial-guarantor-profile (guarantor principal))
  (map-set guarantor-profiles
    { guarantor: guarantor }
    {
      total-guaranteed: u0,
      active-guarantees: u0,
      successful-guarantees: u0,
      failed-guarantees: u0,
      reputation-score: u500,
      max-guarantee-capacity: u50000,
      last-updated: stacks-block-height
    }
  )
)

(define-private (update-guarantor-profile (guarantor principal) (guaranteed-amount uint) (guarantee-change int) (outcome-change int))
  (let (
    (current-profile (default-to
      {
        total-guaranteed: u0,
        active-guarantees: u0,
        successful-guarantees: u0,
        failed-guarantees: u0,
        reputation-score: u500,
        max-guarantee-capacity: u50000,
        last-updated: u0
      }
      (get-guarantor-profile guarantor)
    ))
    (new-total-guaranteed (+ (get total-guaranteed current-profile) guaranteed-amount))
    (new-active-guarantees (if (>= guarantee-change 0)
      (+ (get active-guarantees current-profile) (to-uint guarantee-change))
      (- (get active-guarantees current-profile) (to-uint (- guarantee-change)))
    ))
    (new-successful-guarantees (if (is-eq outcome-change 1)
      (+ (get successful-guarantees current-profile) u1)
      (get successful-guarantees current-profile)
    ))
    (new-failed-guarantees (if (is-eq outcome-change -1)
      (+ (get failed-guarantees current-profile) u1)
      (get failed-guarantees current-profile)
    ))
  )
    (map-set guarantor-profiles
      { guarantor: guarantor }
      {
        total-guaranteed: new-total-guaranteed,
        active-guarantees: new-active-guarantees,
        successful-guarantees: new-successful-guarantees,
        failed-guarantees: new-failed-guarantees,
        reputation-score: (calculate-guarantor-reputation guarantor),
        max-guarantee-capacity: (get max-guarantee-capacity current-profile),
        last-updated: stacks-block-height
      }
    )
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

(define-public (register-guarantor (max-capacity uint))
  (begin
    (asserts! (is-none (get-guarantor-profile tx-sender)) ERR_ALREADY_GUARANTOR)
    (asserts! (> max-capacity u0) ERR_INVALID_AMOUNT)
    (create-initial-guarantor-profile tx-sender)
    (map-set guarantor-profiles
      { guarantor: tx-sender }
      (merge (unwrap-panic (get-guarantor-profile tx-sender)) {
        max-guarantee-capacity: max-capacity
      })
    )
    (ok true)
  )
)

(define-public (guarantee-loan (loan-id uint) (guarantee-percentage uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (guarantor-profile (unwrap! (get-guarantor-profile tx-sender) ERR_GUARANTOR_NOT_FOUND))
    (existing-guarantee (get-loan-guarantee loan-id))
    (loan-amount (get amount loan))
    (guarantee-amount (/ (* loan-amount guarantee-percentage) u100))
    (current-guaranteed (get total-guaranteed guarantor-profile))
    (max-capacity (get max-guarantee-capacity guarantor-profile))
    (guarantor-loan-count (get-guarantor-loan-count tx-sender))
  )
    (asserts! (is-none existing-guarantee) ERR_ALREADY_GUARANTOR)
    (asserts! (not (is-eq tx-sender (get borrower loan))) ERR_SELF_GUARANTEE)
    (asserts! (not (get repaid loan)) ERR_LOAN_ALREADY_REPAID)
    (asserts! (and (> guarantee-percentage u0) (<= guarantee-percentage u100)) ERR_INVALID_AMOUNT)
    (asserts! (<= (+ current-guaranteed guarantee-amount) max-capacity) ERR_INSUFFICIENT_GUARANTEE_CAPACITY)
    
    (map-set loan-guarantees
      { loan-id: loan-id }
      {
        guarantor: tx-sender,
        guarantee-amount: guarantee-amount,
        guarantee-percentage: guarantee-percentage,
        created-at: stacks-block-height,
        is-active: true,
        claimed: false
      }
    )
    
    (map-set guarantor-obligations
      { guarantor: tx-sender, loan-id: loan-id }
      {
        guaranteed-amount: guarantee-amount,
        liability-amount: u0,
        is-liable: false,
        settled: false
      }
    )
    
    (map-set guarantor-loans
      { guarantor: tx-sender, loan-index: guarantor-loan-count }
      { loan-id: loan-id }
    )
    
    (map-set guarantor-loan-counts
      { guarantor: tx-sender }
      { count: (+ guarantor-loan-count u1) }
    )
    
    (update-guarantor-profile tx-sender guarantee-amount 1 0)
    (var-set total-guaranteed-volume (+ (var-get total-guaranteed-volume) guarantee-amount))
    
    (ok true)
  )
)

(define-public (claim-guarantee (loan-id uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (guarantee (unwrap! (get-loan-guarantee loan-id) ERR_GUARANTEE_NOT_FOUND))
    (guarantor (get guarantor guarantee))
    (obligation (unwrap! (get-guarantor-obligation guarantor loan-id) ERR_GUARANTEE_NOT_FOUND))
    (loan-amount (get amount loan))
    (total-owed (+ loan-amount (/ (* loan-amount (get interest-rate loan)) u100)))
    (repaid-amount (get repaid-amount loan))
    (remaining-debt (- total-owed repaid-amount))
    (liability-amount (if (<= (get guarantee-amount guarantee) remaining-debt) (get guarantee-amount guarantee) remaining-debt))
    (loan-duration (get duration loan))
    (blocks-elapsed (- stacks-block-height (get start-block loan)))
    (is-overdue (> blocks-elapsed loan-duration))
  )
    (asserts! (is-eq tx-sender (get lender loan)) ERR_UNAUTHORIZED)
    (asserts! (not (get claimed guarantee)) ERR_GUARANTEE_ALREADY_CLAIMED)
    (asserts! (not (get repaid loan)) ERR_LOAN_ALREADY_REPAID)
    (asserts! is-overdue ERR_INVALID_AMOUNT)
    (asserts! (> remaining-debt u0) ERR_INVALID_AMOUNT)
    
    (map-set loan-guarantees
      { loan-id: loan-id }
      (merge guarantee {
        claimed: true,
        is-active: false
      })
    )
    
    (map-set guarantor-obligations
      { guarantor: guarantor, loan-id: loan-id }
      (merge obligation {
        liability-amount: liability-amount,
        is-liable: true
      })
    )
    
    (update-guarantor-profile guarantor u0 -1 -1)
    
    (ok liability-amount)
  )
)

(define-public (settle-guarantee-obligation (loan-id uint))
  (let (
    (guarantee (unwrap! (get-loan-guarantee loan-id) ERR_GUARANTEE_NOT_FOUND))
    (guarantor (get guarantor guarantee))
    (obligation (unwrap! (get-guarantor-obligation guarantor loan-id) ERR_GUARANTEE_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender guarantor) ERR_UNAUTHORIZED)
    (asserts! (get is-liable obligation) ERR_GUARANTEE_NOT_FOUND)
    (asserts! (not (get settled obligation)) ERR_GUARANTEE_ALREADY_CLAIMED)
    
    (map-set guarantor-obligations
      { guarantor: guarantor, loan-id: loan-id }
      (merge obligation {
        settled: true
      })
    )
    
    (ok true)
  )
)

(define-public (release-guarantee (loan-id uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (guarantee (unwrap! (get-loan-guarantee loan-id) ERR_GUARANTEE_NOT_FOUND))
    (guarantor (get guarantor guarantee))
    (obligation (unwrap! (get-guarantor-obligation guarantor loan-id) ERR_GUARANTEE_NOT_FOUND))
  )
    (asserts! (get repaid loan) ERR_LOAN_ACTIVE)
    (asserts! (get is-active guarantee) ERR_GUARANTEE_ALREADY_CLAIMED)
    (asserts! (not (get is-liable obligation)) ERR_GUARANTEE_ALREADY_CLAIMED)
    
    (map-set loan-guarantees
      { loan-id: loan-id }
      (merge guarantee {
        is-active: false
      })
    )
    
    (update-guarantor-profile guarantor u0 -1 1)
    
    (ok true)
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