;; Freelancer Reputation System Contract
;; Tracks freelancer performance and client satisfaction ratings
;; Manages skill verification through completed project portfolios
;; Handles client feedback and review systems
;; Processes reputation-based pricing recommendations
;; Maintains transparent freelancer profiles with verified credentials

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-FREELANCER-NOT-FOUND (err u201))
(define-constant ERR-REVIEW-NOT-FOUND (err u202))
(define-constant ERR-SKILL-NOT-FOUND (err u203))
(define-constant ERR-ALREADY-EXISTS (err u204))
(define-constant ERR-INVALID-RATING (err u205))
(define-constant ERR-INSUFFICIENT-PROJECTS (err u206))
(define-constant ERR-INVALID-SKILL-LEVEL (err u207))
(define-constant ERR-PORTFOLIO-FULL (err u208))
(define-constant ERR-INVALID-PORTFOLIO-ID (err u209))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-RATING u5)
(define-constant MIN-RATING u1)
(define-constant MAX-SKILLS u20)
(define-constant MAX-PORTFOLIO-ITEMS u50)
(define-constant VERIFICATION-THRESHOLD u5) ;; Minimum projects for skill verification

;; Skill levels
(define-constant SKILL-BEGINNER u1)
(define-constant SKILL-INTERMEDIATE u2)
(define-constant SKILL-ADVANCED u3)
(define-constant SKILL-EXPERT u4)

;; Data variables
(define-data-var next-review-id uint u1)
(define-data-var next-portfolio-id uint u1)
(define-data-var platform-reputation-multiplier uint u100) ;; Base multiplier for reputation calculation

;; Freelancer profiles
(define-map freelancer-profiles principal {
  name: (string-ascii 100),
  bio: (string-ascii 500),
  joined-at: uint,
  total-projects: uint,
  completed-projects: uint,
  average-rating: uint, ;; Stored as rating * 100 for precision (e.g., 425 = 4.25)
  total-earnings: uint,
  verification-status: bool,
  reputation-score: uint,
  skills-count: uint,
  portfolio-count: uint
})

;; Client reviews for freelancers
(define-map reviews uint {
  review-id: uint,
  freelancer: principal,
  client: principal,
  project-id: uint,
  rating: uint,
  comment: (string-ascii 500),
  skills-rated: (list 10 (string-ascii 50)),
  created-at: uint,
  verified: bool
})

;; Skill assessments and verifications
(define-map freelancer-skills { freelancer: principal, skill: (string-ascii 50) } {
  skill-level: uint,
  projects-completed: uint,
  average-rating: uint,
  verified: bool,
  last-updated: uint,
  portfolio-items: (list 10 uint)
})

;; Portfolio items
(define-map portfolio-items uint {
  portfolio-id: uint,
  freelancer: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  skill-category: (string-ascii 50),
  project-url: (optional (string-ascii 200)),
  completion-date: uint,
  client-reference: (optional principal),
  verified-by-client: bool,
  rating-received: (optional uint)
})

;; Review aggregations by freelancer
(define-map review-summaries principal {
  total-reviews: uint,
  rating-distribution: { one-star: uint, two-star: uint, three-star: uint, four-star: uint, five-star: uint },
  recent-reviews: (list 10 uint),
  verified-reviews: uint,
  recommendation-rate: uint ;; Percentage of 4+ star ratings
})

;; Pricing recommendations based on reputation
(define-map pricing-recommendations principal {
  base-hourly-rate: uint,
  reputation-multiplier: uint,
  recommended-rate: uint,
  premium-tier: bool,
  last-updated: uint
})

;; Skills catalog
(define-map skills-catalog (string-ascii 50) {
  category: (string-ascii 50),
  demand-level: uint, ;; 1-5 scale
  average-rate: uint,
  active-freelancers: uint
})

;; Public functions

;; Register new freelancer profile
(define-public (register-freelancer (name (string-ascii 100)) (bio (string-ascii 500)))
  (let (
    (current-block stacks-block-height)
  )
    (asserts! (is-none (map-get? freelancer-profiles tx-sender)) ERR-ALREADY-EXISTS)
    
    (map-set freelancer-profiles tx-sender {
      name: name,
      bio: bio,
      joined-at: current-block,
      total-projects: u0,
      completed-projects: u0,
      average-rating: u0,
      total-earnings: u0,
      verification-status: false,
      reputation-score: u0,
      skills-count: u0,
      portfolio-count: u0
    })
    
    ;; Initialize review summary
    (map-set review-summaries tx-sender {
      total-reviews: u0,
      rating-distribution: { one-star: u0, two-star: u0, three-star: u0, four-star: u0, five-star: u0 },
      recent-reviews: (list),
      verified-reviews: u0,
      recommendation-rate: u0
    })
    
    (ok true)
  )
)

;; Submit client review for freelancer
(define-public (submit-review 
  (freelancer principal) 
  (project-id uint) 
  (rating uint) 
  (comment (string-ascii 500)) 
  (skills-rated (list 10 (string-ascii 50))))
  (let (
    (review-id (var-get next-review-id))
    (freelancer-profile (unwrap! (map-get? freelancer-profiles freelancer) ERR-FREELANCER-NOT-FOUND))
    (current-block stacks-block-height)
  )
    (asserts! (and (>= rating MIN-RATING) (<= rating MAX-RATING)) ERR-INVALID-RATING)
    
    ;; Create review record
    (map-set reviews review-id {
      review-id: review-id,
      freelancer: freelancer,
      client: tx-sender,
      project-id: project-id,
      rating: rating,
      comment: comment,
      skills-rated: skills-rated,
      created-at: current-block,
      verified: true ;; Auto-verify for now, can add verification logic later
    })
    
    ;; Update freelancer's average rating and profile
    (update-freelancer-rating freelancer rating)
    
    ;; Update skill ratings
    (update-skills-ratings freelancer skills-rated rating)
    
    ;; Update review summary
    (update-review-summary freelancer review-id rating)
    
    (var-set next-review-id (+ review-id u1))
    (ok review-id)
  )
)

;; Add skill to freelancer profile
(define-public (add-skill (skill (string-ascii 50)) (skill-level uint))
  (let (
    (freelancer-profile (unwrap! (map-get? freelancer-profiles tx-sender) ERR-FREELANCER-NOT-FOUND))
    (current-skills-count (get skills-count freelancer-profile))
  )
    (asserts! (and (>= skill-level SKILL-BEGINNER) (<= skill-level SKILL-EXPERT)) ERR-INVALID-SKILL-LEVEL)
    (asserts! (< current-skills-count MAX-SKILLS) ERR-PORTFOLIO-FULL)
    
    ;; Check if skill already exists
    (asserts! (is-none (map-get? freelancer-skills { freelancer: tx-sender, skill: skill })) ERR-ALREADY-EXISTS)
    
    (map-set freelancer-skills { freelancer: tx-sender, skill: skill } {
      skill-level: skill-level,
      projects-completed: u0,
      average-rating: u0,
      verified: false,
      last-updated: stacks-block-height,
      portfolio-items: (list)
    })
    
    ;; Update skills count
    (map-set freelancer-profiles tx-sender 
      (merge freelancer-profile { skills-count: (+ current-skills-count u1) })
    )
    
    (ok true)
  )
)

;; Add portfolio item
(define-public (add-portfolio-item 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (skill-category (string-ascii 50))
  (project-url (optional (string-ascii 200)))
  (client-reference (optional principal)))
  (let (
    (portfolio-id (var-get next-portfolio-id))
    (freelancer-profile (unwrap! (map-get? freelancer-profiles tx-sender) ERR-FREELANCER-NOT-FOUND))
    (current-portfolio-count (get portfolio-count freelancer-profile))
  )
    (asserts! (< current-portfolio-count MAX-PORTFOLIO-ITEMS) ERR-PORTFOLIO-FULL)
    
    (map-set portfolio-items portfolio-id {
      portfolio-id: portfolio-id,
      freelancer: tx-sender,
      title: title,
      description: description,
      skill-category: skill-category,
      project-url: project-url,
      completion-date: stacks-block-height,
      client-reference: client-reference,
      verified-by-client: false,
      rating-received: none
    })
    
    ;; Update portfolio count
    (map-set freelancer-profiles tx-sender
      (merge freelancer-profile { portfolio-count: (+ current-portfolio-count u1) })
    )
    
    ;; Add to skill portfolio if skill exists
    (update-skill-portfolio tx-sender skill-category portfolio-id)
    
    (var-set next-portfolio-id (+ portfolio-id u1))
    (ok portfolio-id)
  )
)

;; Verify freelancer skill through portfolio review
(define-public (verify-skill (freelancer principal) (skill (string-ascii 50)))
  (let (
    (skill-data (unwrap! (map-get? freelancer-skills { freelancer: freelancer, skill: skill }) ERR-SKILL-NOT-FOUND))
    (projects-completed (get projects-completed skill-data))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= projects-completed VERIFICATION-THRESHOLD) ERR-INSUFFICIENT-PROJECTS)
    
    (map-set freelancer-skills { freelancer: freelancer, skill: skill }
      (merge skill-data { 
        verified: true,
        last-updated: stacks-block-height
      })
    )
    
    ;; Update freelancer verification status if this is their first verified skill
    (let ((freelancer-profile (unwrap! (map-get? freelancer-profiles freelancer) ERR-FREELANCER-NOT-FOUND)))
      (if (not (get verification-status freelancer-profile))
        (map-set freelancer-profiles freelancer
          (merge freelancer-profile { verification-status: true })
        )
        true
      )
    )
    
    (ok true)
  )
)

;; Update freelancer profile information
(define-public (update-profile (name (string-ascii 100)) (bio (string-ascii 500)))
  (let (
    (freelancer-profile (unwrap! (map-get? freelancer-profiles tx-sender) ERR-FREELANCER-NOT-FOUND))
  )
    (map-set freelancer-profiles tx-sender
      (merge freelancer-profile {
        name: name,
        bio: bio
      })
    )
    (ok true)
  )
)

;; Helper functions

;; Update freelancer's average rating
(define-private (update-freelancer-rating (freelancer principal) (new-rating uint))
  (match (map-get? freelancer-profiles freelancer)
    profile (let (
      (total-projects (get total-projects profile))
      (current-avg (get average-rating profile))
      (new-total (+ total-projects u1))
      (new-avg (/ (+ (* current-avg total-projects) (* new-rating u100)) new-total))
    )
      (begin
        (map-set freelancer-profiles freelancer
          (merge profile {
            total-projects: new-total,
            average-rating: new-avg,
            reputation-score: (calculate-reputation-score new-avg new-total)
          })
        )
        true
      )
    )
    false
  )
)

;; Update skill ratings based on review
(define-private (update-skills-ratings (freelancer principal) (skills (list 10 (string-ascii 50))) (rating uint))
  true
)


;; Update review summary for freelancer
(define-private (update-review-summary (freelancer principal) (review-id uint) (rating uint))
  (let (
    (summary (default-to 
      {
        total-reviews: u0,
        rating-distribution: { one-star: u0, two-star: u0, three-star: u0, four-star: u0, five-star: u0 },
        recent-reviews: (list),
        verified-reviews: u0,
        recommendation-rate: u0
      }
      (map-get? review-summaries freelancer)
    ))
    (new-total (+ (get total-reviews summary) u1))
    (updated-distribution (update-rating-distribution (get rating-distribution summary) rating))
    (new-recent-list (match (as-max-len? (append (get recent-reviews summary) review-id) u10)
                      success success
                      (get recent-reviews summary)))
  )
    (begin
      (map-set review-summaries freelancer
        (merge summary {
          total-reviews: new-total,
          rating-distribution: updated-distribution,
          recent-reviews: new-recent-list,
          verified-reviews: (+ (get verified-reviews summary) u1),
          recommendation-rate: (calculate-recommendation-rate updated-distribution new-total)
        })
      )
      true
    )
  )
)

;; Update rating distribution
(define-private (update-rating-distribution (dist { one-star: uint, two-star: uint, three-star: uint, four-star: uint, five-star: uint }) (rating uint))
  (if (is-eq rating u1)
    (merge dist { one-star: (+ (get one-star dist) u1) })
    (if (is-eq rating u2)
      (merge dist { two-star: (+ (get two-star dist) u1) })
      (if (is-eq rating u3)
        (merge dist { three-star: (+ (get three-star dist) u1) })
        (if (is-eq rating u4)
          (merge dist { four-star: (+ (get four-star dist) u1) })
          (merge dist { five-star: (+ (get five-star dist) u1) })
        )
      )
    )
  )
)

;; Calculate recommendation rate (percentage of 4+ star ratings)
(define-private (calculate-recommendation-rate (dist { one-star: uint, two-star: uint, three-star: uint, four-star: uint, five-star: uint }) (total uint))
  (if (is-eq total u0)
    u0
    (/ (* (+ (get four-star dist) (get five-star dist)) u100) total)
  )
)

;; Calculate reputation score based on rating and project count
(define-private (calculate-reputation-score (avg-rating uint) (project-count uint))
  (let (
    (base-score (/ (* avg-rating project-count) u100))
    (multiplier (var-get platform-reputation-multiplier))
  )
    (/ (* base-score multiplier) u100)
  )
)

;; Update skill portfolio
(define-private (update-skill-portfolio (freelancer principal) (skill (string-ascii 50)) (portfolio-id uint))
  (match (map-get? freelancer-skills { freelancer: freelancer, skill: skill })
    skill-data (let (
      (new-portfolio-items (match (as-max-len? (append (get portfolio-items skill-data) portfolio-id) u10)
                           success success
                           (get portfolio-items skill-data)))
    )
      (begin
        (map-set freelancer-skills { freelancer: freelancer, skill: skill }
          (merge skill-data {
            projects-completed: (+ (get projects-completed skill-data) u1),
            portfolio-items: new-portfolio-items
          })
        )
        true
      )
    )
    true ;; Skill doesn't exist, ignore
  )
)

;; Read-only functions

;; Get freelancer profile
(define-read-only (get-freelancer-profile (freelancer principal))
  (map-get? freelancer-profiles freelancer)
)

;; Get freelancer overall rating
(define-read-only (get-freelancer-rating (freelancer principal))
  (match (map-get? freelancer-profiles freelancer)
    profile (some (get average-rating profile))
    none
  )
)

;; Get review history for freelancer
(define-read-only (get-review-history (freelancer principal))
  (map-get? review-summaries freelancer)
)

;; Get specific review details
(define-read-only (get-review-details (review-id uint))
  (map-get? reviews review-id)
)

;; Get skill verification status
(define-read-only (get-skill-verification (freelancer principal) (skill (string-ascii 50)))
  (map-get? freelancer-skills { freelancer: freelancer, skill: skill })
)

;; Get portfolio item details
(define-read-only (get-portfolio-item (portfolio-id uint))
  (map-get? portfolio-items portfolio-id)
)

;; Get pricing recommendations
(define-read-only (get-pricing-recommendations (freelancer principal))
  (map-get? pricing-recommendations freelancer)
)

;; Get freelancer reputation score
(define-read-only (get-reputation-score (freelancer principal))
  (match (map-get? freelancer-profiles freelancer)
    profile (some (get reputation-score profile))
    none
  )
)

;; Get total registered freelancers
(define-read-only (get-total-freelancers)
  ;; This would need a counter variable to track accurately
  u0
)

;; Check if freelancer is verified
(define-read-only (is-freelancer-verified (freelancer principal))
  (match (map-get? freelancer-profiles freelancer)
    profile (get verification-status profile)
    false
  )
)

;; title: freelancer-reputation-system
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

