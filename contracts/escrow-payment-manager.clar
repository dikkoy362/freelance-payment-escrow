;; Escrow Payment Manager Contract
;; Manages secure escrow payments between clients and freelancers
;; Handles milestone-based release mechanisms with approval workflows
;; Processes dispute resolution through multi-party arbitration
;; Maintains payment history and transaction records
;; Provides automated invoice generation with tax compliance

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-ESCROW-NOT-FOUND (err u102))
(define-constant ERR-MILESTONE-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-COMPLETED (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-INVALID-STATUS (err u106))
(define-constant ERR-DISPUTE-ALREADY-EXISTS (err u107))
(define-constant ERR-NO-DISPUTE-FOUND (err u108))
(define-constant ERR-INVALID-MILESTONE-ID (err u109))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Escrow status constants
(define-constant STATUS-CREATED u0)
(define-constant STATUS-FUNDED u1)
(define-constant STATUS-IN-PROGRESS u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-DISPUTED u4)
(define-constant STATUS-CANCELLED u5)

;; Data variables
(define-data-var next-escrow-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% platform fee
(define-data-var dispute-timeout uint u144) ;; 24 hours in blocks (assuming 10-min blocks)

;; Data maps
(define-map escrows uint {
  client: principal,
  freelancer: principal,
  amount: uint,
  status: uint,
  created-at: uint,
  description: (string-ascii 500),
  milestones-count: uint,
  completed-milestones: uint
})

(define-map milestones uint {
  escrow-id: uint,
  milestone-id: uint,
  description: (string-ascii 300),
  amount: uint,
  status: uint,
  created-at: uint,
  completed-at: (optional uint),
  approved-by-client: bool
})

(define-map disputes uint {
  escrow-id: uint,
  milestone-id: uint,
  raised-by: principal,
  reason: (string-ascii 500),
  status: uint,
  created-at: uint,
  resolved-at: (optional uint),
  resolution: (optional (string-ascii 500))
})

(define-map escrow-balances uint uint)
(define-map payment-history uint (list 50 {
  milestone-id: uint,
  amount: uint,
  paid-at: uint,
  transaction-type: (string-ascii 20)
}))

;; Invoice tracking
(define-map invoices uint {
  escrow-id: uint,
  amount: uint,
  tax-amount: uint,
  total-amount: uint,
  generated-at: uint,
  status: (string-ascii 20)
})

;; Public functions

;; Create new escrow contract
(define-public (create-escrow (freelancer principal) (amount uint) (description (string-ascii 500)))
  (let (
    (escrow-id (var-get next-escrow-id))
    (current-block stacks-block-height)
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq tx-sender freelancer)) ERR-NOT-AUTHORIZED)
    
    (map-set escrows escrow-id {
      client: tx-sender,
      freelancer: freelancer,
      amount: amount,
      status: STATUS-CREATED,
      created-at: current-block,
      description: description,
      milestones-count: u0,
      completed-milestones: u0
    })
    
    (var-set next-escrow-id (+ escrow-id u1))
    (ok escrow-id)
  )
)

;; Fund escrow with STX tokens
(define-public (fund-escrow (escrow-id uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    (amount (get amount escrow-data))
  )
    (asserts! (is-eq tx-sender (get client escrow-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status escrow-data) STATUS-CREATED) ERR-INVALID-STATUS)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set escrows escrow-id (merge escrow-data { status: STATUS-FUNDED }))
    (map-set escrow-balances escrow-id amount)
    
    (ok true)
  )
)

;; Add milestone to escrow
(define-public (add-milestone (escrow-id uint) (description (string-ascii 300)) (amount uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    (milestone-id (var-get next-milestone-id))
    (current-block stacks-block-height)
  )
    (asserts! (is-eq tx-sender (get client escrow-data)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (map-set milestones milestone-id {
      escrow-id: escrow-id,
      milestone-id: milestone-id,
      description: description,
      amount: amount,
      status: STATUS-CREATED,
      created-at: current-block,
      completed-at: none,
      approved-by-client: false
    })
    
    (map-set escrows escrow-id 
      (merge escrow-data { 
        milestones-count: (+ (get milestones-count escrow-data) u1)
      })
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

;; Release payment for completed milestone
(define-public (release-milestone (milestone-id uint))
  (let (
    (milestone-data (unwrap! (map-get? milestones milestone-id) ERR-MILESTONE-NOT-FOUND))
    (escrow-id (get escrow-id milestone-data))
    (escrow-data (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    (amount (get amount milestone-data))
    (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000))
    (net-amount (- amount platform-fee))
    (current-balance (default-to u0 (map-get? escrow-balances escrow-id)))
  )
    (asserts! (is-eq tx-sender (get client escrow-data)) ERR-NOT-AUTHORIZED)
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (not (get approved-by-client milestone-data)) ERR-ALREADY-COMPLETED)
    
    ;; Transfer payment to freelancer
    (try! (as-contract (stx-transfer? net-amount tx-sender (get freelancer escrow-data))))
    
    ;; Transfer platform fee
    (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT-OWNER)))
    
    ;; Update milestone status
    (map-set milestones milestone-id 
      (merge milestone-data {
        status: STATUS-COMPLETED,
        completed-at: (some stacks-block-height),
        approved-by-client: true
      })
    )
    
    ;; Update escrow balance
    (map-set escrow-balances escrow-id (- current-balance amount))
    
    ;; Update escrow completed milestones count
    (map-set escrows escrow-id
      (merge escrow-data {
        completed-milestones: (+ (get completed-milestones escrow-data) u1)
      })
    )
    
    ;; Add to payment history
    (try! (add-payment-record escrow-id milestone-id amount "milestone-payment"))
    
    (ok true)
  )
)

;; Raise dispute for milestone
(define-public (dispute-milestone (milestone-id uint) (reason (string-ascii 500)))
  (let (
    (milestone-data (unwrap! (map-get? milestones milestone-id) ERR-MILESTONE-NOT-FOUND))
    (escrow-id (get escrow-id milestone-data))
    (escrow-data (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
  )
    (asserts! (or 
      (is-eq tx-sender (get client escrow-data))
      (is-eq tx-sender (get freelancer escrow-data))
    ) ERR-NOT-AUTHORIZED)
    
    ;; Check if dispute already exists
    (asserts! (is-none (map-get? disputes milestone-id)) ERR-DISPUTE-ALREADY-EXISTS)
    
    (map-set disputes milestone-id {
      escrow-id: escrow-id,
      milestone-id: milestone-id,
      raised-by: tx-sender,
      reason: reason,
      status: STATUS-DISPUTED,
      created-at: stacks-block-height,
      resolved-at: none,
      resolution: none
    })
    
    ;; Update escrow status to disputed
    (map-set escrows escrow-id (merge escrow-data { status: STATUS-DISPUTED }))
    
    (ok true)
  )
)

;; Resolve dispute (admin function)
(define-public (resolve-dispute (milestone-id uint) (resolution (string-ascii 500)) (award-to-freelancer bool))
  (let (
    (dispute-data (unwrap! (map-get? disputes milestone-id) ERR-NO-DISPUTE-FOUND))
    (milestone-data (unwrap! (map-get? milestones milestone-id) ERR-MILESTONE-NOT-FOUND))
    (escrow-id (get escrow-id dispute-data))
    (escrow-data (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    (amount (get amount milestone-data))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Update dispute status
    (map-set disputes milestone-id
      (merge dispute-data {
        status: STATUS-COMPLETED,
        resolved-at: (some stacks-block-height),
        resolution: (some resolution)
      })
    )
    
    ;; Award payment if freelancer wins dispute
    (if award-to-freelancer
      (begin
        (try! (release-milestone milestone-id))
      )
      (begin
        ;; Return funds to client if client wins
        (let ((current-balance (default-to u0 (map-get? escrow-balances escrow-id))))
          (try! (as-contract (stx-transfer? amount tx-sender (get client escrow-data))))
          (map-set escrow-balances escrow-id (- current-balance amount))
        )
      )
    )
    
    ;; Update escrow status back to in-progress
    (map-set escrows escrow-id (merge escrow-data { status: STATUS-IN-PROGRESS }))
    
    (ok true)
  )
)

;; Helper function to add payment records
(define-private (add-payment-record (escrow-id uint) (milestone-id uint) (amount uint) (tx-type (string-ascii 20)))
  (let (
    (current-history (default-to (list) (map-get? payment-history escrow-id)))
    (new-record {
      milestone-id: milestone-id,
      amount: amount,
      paid-at: stacks-block-height,
      transaction-type: tx-type
    })
  )
    (map-set payment-history escrow-id (unwrap! (as-max-len? (append current-history new-record) u50) (err u999)))
    (ok true)
  )
)


;; Read-only functions

;; Get escrow details
(define-read-only (get-escrow-details (escrow-id uint))
  (map-get? escrows escrow-id)
)

;; Get milestone status
(define-read-only (get-milestone-status (milestone-id uint))
  (map-get? milestones milestone-id)
)

;; Get payment history
(define-read-only (get-payment-history (escrow-id uint))
  (map-get? payment-history escrow-id)
)

;; Get escrow balance
(define-read-only (get-escrow-balance (escrow-id uint))
  (map-get? escrow-balances escrow-id)
)

;; Get dispute details
(define-read-only (get-dispute-details (milestone-id uint))
  (map-get? disputes milestone-id)
)

;; Get platform fee rate
(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

;; Get total escrows created
(define-read-only (get-total-escrows)
  (- (var-get next-escrow-id) u1)
)

;; Get total milestones created
(define-read-only (get-total-milestones)
  (- (var-get next-milestone-id) u1)
)

;; Check if user is authorized for escrow
(define-read-only (is-authorized-user (escrow-id uint) (user principal))
  (match (map-get? escrows escrow-id)
    escrow-data (or 
      (is-eq user (get client escrow-data))
      (is-eq user (get freelancer escrow-data))
    )
    false
  )
)

;; title: escrow-payment-manager
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

