
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
(define-constant ERR_INVALID_RATE (err u115))
(define-constant ERR_RATE_ORACLE_NOT_AUTHORIZED (err u116))
(define-constant ERR_RATE_UPDATE_TOO_FREQUENT (err u117))
(define-constant ERR_RATE_BAND_VIOLATION (err u118))
(define-constant ERR_MARKET_DATA_STALE (err u119))

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

(define-map market-rate-data
  { period: uint }
  {
    base-rate: uint,
    utilization-rate: uint,
    demand-pressure: uint,
    supply-pressure: uint,
    market-volatility: uint,
    timestamp: uint,
    total-supply: uint,
    total-demand: uint
  }
)

(define-map rate-oracle-config
  { config-key: (string-ascii 32) }
  {
    value: uint,
    last-updated: uint,
    authorized-updater: principal
  }
)

(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool, permissions: uint }
)

(define-map rate-history
  { timestamp: uint }
  {
    rate: uint,
    reason: (string-ascii 64),
    market-conditions: uint,
    adjustment-magnitude: int
  }
)

(define-map dynamic-rate-bands
  { risk-tier: uint }
  {
    min-rate: uint,
    max-rate: uint,
    adjustment-factor: uint,
    utilization-threshold: uint
  }
)

(define-data-var next-loan-id uint u1)
(define-data-var total-volume uint u0)
(define-data-var total-guaranteed-volume uint u0)
(define-data-var current-base-rate uint u500)
(define-data-var rate-update-frequency uint u144)
(define-data-var last-rate-update uint u0)
(define-data-var market-utilization-rate uint u0)
(define-data-var total-active-loans-value uint u0)

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

(define-read-only (get-market-rate-data (period uint))
  (map-get? market-rate-data { period: period })
)

(define-read-only (get-rate-oracle-config (config-key (string-ascii 32)))
  (map-get? rate-oracle-config { config-key: config-key })
)

(define-read-only (is-authorized-oracle (oracle principal))
  (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle })))
)

(define-read-only (get-rate-history (timestamp uint))
  (map-get? rate-history { timestamp: timestamp })
)

(define-read-only (get-dynamic-rate-band (risk-tier uint))
  (map-get? dynamic-rate-bands { risk-tier: risk-tier })
)

(define-read-only (get-current-base-rate)
  (var-get current-base-rate)
)

(define-read-only (get-market-utilization-rate)
  (var-get market-utilization-rate)
)

(define-read-only (calculate-dynamic-interest-rate (borrower-score uint) (loan-amount uint))
  (let (
    (base-rate (var-get current-base-rate))
    (utilization-rate (var-get market-utilization-rate))
    (risk-tier (if (>= borrower-score u750) u1 (if (>= borrower-score u650) u2 (if (>= borrower-score u550) u3 u4))))
    (rate-band (get-dynamic-rate-band risk-tier))
    (tier-adjustment (if (is-some rate-band) (get adjustment-factor (unwrap-panic rate-band)) u10))
    (utilization-adjustment (/ (* utilization-rate u50) u100))
    (risk-adjustment (if (< borrower-score u550) u100 (if (< borrower-score u650) u50 u0)))
    (amount-adjustment (if (> loan-amount u100000) u25 u0))
    (calculated-rate (+ base-rate tier-adjustment utilization-adjustment risk-adjustment amount-adjustment))
    (min-rate (if (is-some rate-band) (get min-rate (unwrap-panic rate-band)) u100))
    (max-rate (if (is-some rate-band) (get max-rate (unwrap-panic rate-band)) u2000))
  )
    (if (<= calculated-rate max-rate)
      (if (>= calculated-rate min-rate) calculated-rate min-rate)
      max-rate)
  )
)

(define-read-only (get-market-health-score)
  (let (
    (utilization (var-get market-utilization-rate))
    (total-vol (var-get total-volume))
    (active-loans-value (var-get total-active-loans-value))
    (health-base u100)
    (utilization-penalty (if (> utilization u80) (* (- utilization u80) u2) u0))
    (volume-bonus (if (> total-vol u1000000) u20 (/ total-vol u50000)))
  )
    (+ (- health-base utilization-penalty) volume-bonus)
  )
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

(define-private (update-market-utilization)
  (let (
    (total-supplied (var-get total-volume))
    (total-active (var-get total-active-loans-value))
  )
    (if (> total-supplied u0)
      (var-set market-utilization-rate (/ (* total-active u100) total-supplied))
      (var-set market-utilization-rate u0)
    )
  )
)

(define-public (authorize-oracle (oracle principal) (permissions uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-oracles
      { oracle: oracle }
      { authorized: true, permissions: permissions }
    )
    (ok true)
  )
)

(define-public (initialize-rate-bands)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set dynamic-rate-bands { risk-tier: u1 } { min-rate: u100, max-rate: u500, adjustment-factor: u0, utilization-threshold: u70 })
    (map-set dynamic-rate-bands { risk-tier: u2 } { min-rate: u200, max-rate: u800, adjustment-factor: u50, utilization-threshold: u75 })
    (map-set dynamic-rate-bands { risk-tier: u3 } { min-rate: u400, max-rate: u1200, adjustment-factor: u100, utilization-threshold: u80 })
    (map-set dynamic-rate-bands { risk-tier: u4 } { min-rate: u600, max-rate: u2000, adjustment-factor: u200, utilization-threshold: u85 })
    (ok true)
  )
)

(define-public (update-market-data (demand-pressure uint) (supply-pressure uint) (volatility uint))
  (let (
    (current-period (/ stacks-block-height u144))
    (total-supply (var-get total-volume))
    (total-demand (var-get total-active-loans-value))
    (utilization-rate (var-get market-utilization-rate))
  )
    (asserts! (is-authorized-oracle tx-sender) ERR_RATE_ORACLE_NOT_AUTHORIZED)
    (asserts! (<= demand-pressure u100) ERR_INVALID_AMOUNT)
    (asserts! (<= supply-pressure u100) ERR_INVALID_AMOUNT)
    (asserts! (<= volatility u100) ERR_INVALID_AMOUNT)
    
    (map-set market-rate-data
      { period: current-period }
      {
        base-rate: (var-get current-base-rate),
        utilization-rate: utilization-rate,
        demand-pressure: demand-pressure,
        supply-pressure: supply-pressure,
        market-volatility: volatility,
        timestamp: stacks-block-height,
        total-supply: total-supply,
        total-demand: total-demand
      }
    )
    (ok true)
  )
)

(define-public (update-base-rate (new-rate uint) (reason (string-ascii 64)))
  (let (
    (current-rate (var-get current-base-rate))
    (rate-change (if (>= new-rate current-rate) (to-int (- new-rate current-rate)) (- (to-int (- current-rate new-rate)))))
    (last-update (var-get last-rate-update))
    (update-frequency (var-get rate-update-frequency))
    (blocks-since-update (- stacks-block-height last-update))
  )
    (asserts! (is-authorized-oracle tx-sender) ERR_RATE_ORACLE_NOT_AUTHORIZED)
    (asserts! (and (>= new-rate u50) (<= new-rate u3000)) ERR_INVALID_RATE)
    (asserts! (>= blocks-since-update update-frequency) ERR_RATE_UPDATE_TOO_FREQUENT)
    
    (var-set current-base-rate new-rate)
    (var-set last-rate-update stacks-block-height)
    
    (map-set rate-history
      { timestamp: stacks-block-height }
      {
        rate: new-rate,
        reason: reason,
        market-conditions: (get-market-health-score),
        adjustment-magnitude: rate-change
      }
    )
    (ok true)
  )
)

(define-public (auto-adjust-rates)
  (let (
    (utilization (var-get market-utilization-rate))
    (current-rate (var-get current-base-rate))
    (health-score (get-market-health-score))
    (adjustment-factor (if (> utilization u80) 25 (if (< utilization u40) -25 0)))
    (new-rate (if (>= adjustment-factor 0) (+ current-rate (to-uint adjustment-factor)) (- current-rate (to-uint (- adjustment-factor)))))
    (bounded-rate (if (<= new-rate u3000) (if (>= new-rate u50) new-rate u50) u3000))
  )
    (asserts! (is-authorized-oracle tx-sender) ERR_RATE_ORACLE_NOT_AUTHORIZED)
    (asserts! (not (is-eq adjustment-factor 0)) ERR_INVALID_AMOUNT)
    
    (var-set current-base-rate bounded-rate)
    (var-set last-rate-update stacks-block-height)
    
    (map-set rate-history
      { timestamp: stacks-block-height }
      {
        rate: bounded-rate,
        reason: "AUTO_ADJUSTMENT",
        market-conditions: health-score,
        adjustment-magnitude: adjustment-factor
      }
    )
    (ok bounded-rate)
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
    (var-set total-active-loans-value (+ (var-get total-active-loans-value) amount))
    (update-market-utilization)
    
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
      
      (if is-fully-repaid
        (var-set total-active-loans-value (- (var-get total-active-loans-value) (get amount loan)))
        true
      )
      
      (update-credit-profile 
        borrower 
        u0 
        amount 
        (if is-fully-repaid -1 0)
      )
      
      (update-market-utilization)
      
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

;; === LOAN RESTRUCTURING SYSTEM ===

;; Restructuring error constants
(define-constant ERR_RESTRUCTURE_REQUEST_EXISTS (err u200))
(define-constant ERR_RESTRUCTURE_REQUEST_NOT_FOUND (err u201))
(define-constant ERR_RESTRUCTURE_UNAUTHORIZED (err u202))
(define-constant ERR_RESTRUCTURE_INVALID_PARAMS (err u203))
(define-constant ERR_RESTRUCTURE_LOAN_REPAID (err u204))
(define-constant ERR_RESTRUCTURE_ALREADY_APPROVED (err u205))

;; Restructuring limits
(define-constant MAX_RATE_MULTIPLIER u2) ;; 2x original rate
(define-constant MAX_DURATION_MULTIPLIER u2) ;; 2x original duration

;; Map to store restructure requests
(define-map restructure-requests
  { loan-id: uint }
  {
    borrower: principal,
    lender: principal,
    original-duration: uint,
    original-rate: uint,
    proposed-duration: uint,
    proposed-rate: uint,
    request-reason: (string-ascii 100),
    requested-at: uint,
    approved: bool,
    approved-at: uint,
    expires-at: uint
  }
)

;; Map to track restructuring history per loan
(define-map loan-restructure-history
  { loan-id: uint }
  {
    total-restructures: uint,
    last-restructure: uint,
    original-terms-duration: uint,
    original-terms-rate: uint
  }
)

;; Request loan restructuring (borrower only)
(define-public (request-restructure 
    (loan-id uint) 
    (proposed-duration uint) 
    (proposed-rate uint) 
    (reason (string-ascii 100))
  )
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (existing-request (map-get? restructure-requests { loan-id: loan-id }))
    (original-duration (get duration loan))
    (original-rate (get interest-rate loan))
    )
    
    ;; Validation checks
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_RESTRUCTURE_UNAUTHORIZED)
    (asserts! (not (get repaid loan)) ERR_RESTRUCTURE_LOAN_REPAID)
    (asserts! (is-none existing-request) ERR_RESTRUCTURE_REQUEST_EXISTS)
    
    ;; Validate restructuring limits
    (asserts! (<= proposed-rate (* original-rate MAX_RATE_MULTIPLIER)) ERR_RESTRUCTURE_INVALID_PARAMS)
    (asserts! (<= proposed-duration (* original-duration MAX_DURATION_MULTIPLIER)) ERR_RESTRUCTURE_INVALID_PARAMS)
    (asserts! (> proposed-duration u0) ERR_RESTRUCTURE_INVALID_PARAMS)
    (asserts! (> proposed-rate u0) ERR_RESTRUCTURE_INVALID_PARAMS)
    
    ;; Create restructure request (expires in ~30 days)
    (map-set restructure-requests
      { loan-id: loan-id }
      {
        borrower: (get borrower loan),
        lender: (get lender loan),
        original-duration: original-duration,
        original-rate: original-rate,
        proposed-duration: proposed-duration,
        proposed-rate: proposed-rate,
        request-reason: reason,
        requested-at: stacks-block-height,
        approved: false,
        approved-at: u0,
        expires-at: (+ stacks-block-height u4320) ;; ~30 days
      }
    )
    
    ;; Initialize restructure history if needed
    (if (is-none (map-get? loan-restructure-history { loan-id: loan-id }))
      (map-set loan-restructure-history
        { loan-id: loan-id }
        {
          total-restructures: u0,
          last-restructure: u0,
          original-terms-duration: original-duration,
          original-terms-rate: original-rate
        }
      )
      true
    )
    
    ;; Emit event
    (print {
      event: "restructure-requested",
      loan-id: loan-id,
      borrower: (get borrower loan),
      lender: (get lender loan),
      proposed-duration: proposed-duration,
      proposed-rate: proposed-rate,
      reason: reason,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Approve loan restructuring (lender only)
(define-public (approve-restructure (loan-id uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (request (unwrap! (map-get? restructure-requests { loan-id: loan-id }) ERR_RESTRUCTURE_REQUEST_NOT_FOUND))
    (history (unwrap! (map-get? loan-restructure-history { loan-id: loan-id }) ERR_RESTRUCTURE_REQUEST_NOT_FOUND))
    )
    
    ;; Validation checks
    (asserts! (is-eq tx-sender (get lender loan)) ERR_RESTRUCTURE_UNAUTHORIZED)
    (asserts! (not (get approved request)) ERR_RESTRUCTURE_ALREADY_APPROVED)
    (asserts! (not (get repaid loan)) ERR_RESTRUCTURE_LOAN_REPAID)
    (asserts! (< stacks-block-height (get expires-at request)) ERR_RESTRUCTURE_REQUEST_NOT_FOUND)
    
    ;; Update the loan with new terms
    (map-set loans
      { loan-id: loan-id }
      (merge loan {
        duration: (get proposed-duration request),
        interest-rate: (get proposed-rate request)
      })
    )
    
    ;; Mark request as approved
    (map-set restructure-requests
      { loan-id: loan-id }
      (merge request {
        approved: true,
        approved-at: stacks-block-height
      })
    )
    
    ;; Update restructure history
    (map-set loan-restructure-history
      { loan-id: loan-id }
      (merge history {
        total-restructures: (+ (get total-restructures history) u1),
        last-restructure: stacks-block-height
      })
    )
    
    ;; Emit event
    (print {
      event: "restructure-approved",
      loan-id: loan-id,
      borrower: (get borrower loan),
      lender: (get lender loan),
      new-duration: (get proposed-duration request),
      new-rate: (get proposed-rate request),
      approved-at: stacks-block-height
    })
    
    (ok true)
  )
)

;; Reject loan restructuring (lender only)
(define-public (reject-restructure (loan-id uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (request (unwrap! (map-get? restructure-requests { loan-id: loan-id }) ERR_RESTRUCTURE_REQUEST_NOT_FOUND))
    )
    
    ;; Validation checks
    (asserts! (is-eq tx-sender (get lender loan)) ERR_RESTRUCTURE_UNAUTHORIZED)
    (asserts! (not (get approved request)) ERR_RESTRUCTURE_ALREADY_APPROVED)
    (asserts! (< stacks-block-height (get expires-at request)) ERR_RESTRUCTURE_REQUEST_NOT_FOUND)
    
    ;; Remove the request
    (map-delete restructure-requests { loan-id: loan-id })
    
    ;; Emit event
    (print {
      event: "restructure-rejected",
      loan-id: loan-id,
      borrower: (get borrower loan),
      lender: (get lender loan),
      rejected-at: stacks-block-height
    })
    
    (ok true)
  )
)

;; Cancel loan restructuring request (borrower only)
(define-public (cancel-restructure-request (loan-id uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
    (request (unwrap! (map-get? restructure-requests { loan-id: loan-id }) ERR_RESTRUCTURE_REQUEST_NOT_FOUND))
    )
    
    ;; Validation checks
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_RESTRUCTURE_UNAUTHORIZED)
    (asserts! (not (get approved request)) ERR_RESTRUCTURE_ALREADY_APPROVED)
    
    ;; Remove the request
    (map-delete restructure-requests { loan-id: loan-id })
    
    ;; Emit event
    (print {
      event: "restructure-cancelled",
      loan-id: loan-id,
      borrower: (get borrower loan),
      lender: (get lender loan),
      cancelled-at: stacks-block-height
    })
    
    (ok true)
  )
)

;; Read-only functions for restructuring

(define-read-only (get-restructure-request (loan-id uint))
  (let (
    (request (map-get? restructure-requests { loan-id: loan-id }))
    )
    (if (is-some request)
      (ok (unwrap-panic request))
      (err ERR_RESTRUCTURE_REQUEST_NOT_FOUND)
    )
  )
)

(define-read-only (get-loan-restructure-history (loan-id uint))
  (let (
    (history (map-get? loan-restructure-history { loan-id: loan-id }))
    )
    (if (is-some history)
      (ok (unwrap-panic history))
      (err ERR_RESTRUCTURE_REQUEST_NOT_FOUND)
    )
  )
)

(define-read-only (is-restructure-request-active (loan-id uint))
  (let (
    (request (map-get? restructure-requests { loan-id: loan-id }))
    )
    (if (is-some request)
      (let (
        (request-data (unwrap-panic request))
        )
        (ok (and 
          (not (get approved request-data))
          (< stacks-block-height (get expires-at request-data))
        ))
      )
      (ok false)
    )
  )
)

(define-read-only (get-restructure-eligibility (loan-id uint))
  (let (
    (loan (map-get? loans { loan-id: loan-id }))
    (existing-request (map-get? restructure-requests { loan-id: loan-id }))
    (history (map-get? loan-restructure-history { loan-id: loan-id }))
    )
    (if (is-some loan)
      (let (
        (loan-data (unwrap-panic loan))
        (restructure-count (if (is-some history) (get total-restructures (unwrap-panic history)) u0))
        )
        (ok {
          eligible: (and 
            (not (get repaid loan-data))
            (is-none existing-request)
            (< restructure-count u3) ;; Max 3 restructures per loan
          ),
          reason: (if (get repaid loan-data) "loan-already-repaid"
                    (if (is-some existing-request) "request-already-exists"
                      (if (>= restructure-count u3) "max-restructures-reached"
                        "eligible"
                      )
                    )
                  ),
          max-rate: (* (get interest-rate loan-data) MAX_RATE_MULTIPLIER),
          max-duration: (* (get duration loan-data) MAX_DURATION_MULTIPLIER),
          restructure-count: restructure-count
        })
      )
      (err ERR_LOAN_NOT_FOUND)
    )
  )
)


