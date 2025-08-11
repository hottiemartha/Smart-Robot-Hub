;; AUTONOMOUS ROBOTICS MARKETPLACE SMART CONTRACT
;; 
;; A decentralized platform connecting customers with autonomous robotics service providers.
;; This marketplace enables secure booking, automated payments, reputation management, and
;; multi-category service offerings across household, industrial, security, maintenance,
;; and entertainment robotics sectors. The platform provides trustless transactions,
;; transparent pricing, dispute resolution, and comprehensive service quality tracking.
;;
;; Key Features:
;; - Decentralized provider registration with blockchain verification
;; - Multi-category robotics service marketplace with real-time booking
;; - Secure escrow payment system with automated fund release
;; - Bidirectional reputation system for quality assurance  
;; - Dynamic service lifecycle management with state validation
;; - Transparent governance with automated fee collection

;; ERROR CONSTANTS

(define-constant ERR-INVALID-PARAMETERS (err u4000))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u4001))
(define-constant ERR-PROVIDER-ALREADY-EXISTS (err u4002))
(define-constant ERR-INSUFFICIENT-FUNDS (err u4003))
(define-constant ERR-RESOURCE-NOT-FOUND (err u4004))
(define-constant ERR-SERVICE-UNAVAILABLE (err u4005))
(define-constant ERR-BOOKING-NOT-ACTIVE (err u4006))
(define-constant ERR-INVALID-STATE-TRANSITION (err u4007))
(define-constant ERR-OPERATION-ALREADY-COMPLETED (err u4008))
(define-constant ERR-RATING-OUT-OF-BOUNDS (err u4009))

;; PLATFORM CONFIGURATION

(define-constant contract-owner tx-sender)
(define-constant marketplace-fee-basis-points u250) ;; 2.5% platform fee

;; SERVICE CATEGORIES

(define-constant category-household-automation u100)
(define-constant category-logistics-delivery u200)
(define-constant category-security-monitoring u300)
(define-constant category-maintenance-services u400)
(define-constant category-entertainment-robotics u500)

;; BOOKING LIFECYCLE STATES

(define-constant status-awaiting-acceptance u10)
(define-constant status-provider-confirmed u20)
(define-constant status-service-in-progress u30)
(define-constant status-service-completed u40)
(define-constant status-booking-cancelled u50)
(define-constant status-dispute-pending u60)

;; GLOBAL STATE MANAGEMENT

(define-data-var next-service-id uint u1000)
(define-data-var next-booking-id uint u2000)
(define-data-var total-platform-earnings uint u0)

;; DATA STRUCTURES

;; Robotics Service Provider Profiles
(define-map robotics-service-providers
  principal
  {
    business-name: (string-ascii 50),
    service-description: (string-ascii 200),
    is-active: bool,
    total-earnings-ustx: uint,
    services-created: uint,
    reputation-score-sum: uint,
    total-reviews-received: uint,
    registration-block-height: uint
  }
)

;; Service Marketplace Listings
(define-map service-marketplace-listings
  uint
  {
    provider-principal: principal,
    service-title: (string-ascii 100),
    service-description: (string-ascii 300),
    category-type: uint,
    hourly-rate-ustx: uint,
    is-available: bool,
    created-at-block: uint,
    completed-bookings: uint,
    cumulative-rating-points: uint,
    review-count: uint
  }
)

;; Customer Booking Management
(define-map service-booking-records
  uint
  {
    service-id: uint,
    customer-principal: principal,
    provider-principal: principal,
    start-block-height: uint,
    duration-hours: uint,
    total-cost-ustx: uint,
    platform-fee-ustx: uint,
    current-status: uint,
    created-at-block: uint,
    completed-at-block: (optional uint),
    customer-review-score: (optional uint),
    provider-review-score: (optional uint)
  }
)

;; Payment Escrow System
(define-map booking-escrow-accounts
  uint  ;; booking-id
  uint  ;; escrow-amount-ustx
)

;; Provider Service Counter
(define-map provider-service-counts
  principal
  uint
)

;; UTILITY FUNCTIONS

(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (calculate-platform-fee (total-amount-ustx uint))
  (/ (* total-amount-ustx marketplace-fee-basis-points) u10000)
)

(define-private (get-next-service-id)
  (let ((current-id (var-get next-service-id)))
    (var-set next-service-id (+ current-id u1))
    current-id
  )
)

(define-private (get-next-booking-id)
  (let ((current-id (var-get next-booking-id)))
    (var-set next-booking-id (+ current-id u1))
    current-id
  )
)

(define-private (is-valid-service-category (category uint))
  (or (is-eq category category-household-automation)
      (is-eq category category-logistics-delivery)
      (is-eq category category-security-monitoring)
      (is-eq category category-maintenance-services)
      (is-eq category category-entertainment-robotics))
)

(define-private (is-valid-rating (score uint))
  (and (>= score u1) (<= score u5))
)

(define-private (is-non-empty-string (text (string-ascii 300)))
  (> (len text) u0)
)

;; PROVIDER MANAGEMENT

(define-public (register-service-provider 
  (business-name (string-ascii 50)) 
  (description (string-ascii 200)))
  (let ((provider-address tx-sender))
    (asserts! (is-none (map-get? robotics-service-providers provider-address)) 
              ERR-PROVIDER-ALREADY-EXISTS)
    (asserts! (is-non-empty-string business-name) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string description) ERR-INVALID-PARAMETERS)
    
    (ok (map-set robotics-service-providers provider-address {
      business-name: business-name,
      service-description: description,
      is-active: true,
      total-earnings-ustx: u0,
      services-created: u0,
      reputation-score-sum: u0,
      total-reviews-received: u0,
      registration-block-height: block-height
    }))
  )
)

(define-public (update-provider-profile 
  (new-business-name (string-ascii 50)) 
  (new-description (string-ascii 200)) 
  (active-status bool))
  (let ((current-profile (unwrap! (map-get? robotics-service-providers tx-sender) 
                                  ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-non-empty-string new-business-name) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string new-description) ERR-INVALID-PARAMETERS)
    
    (ok (map-set robotics-service-providers tx-sender 
                 (merge current-profile {
                   business-name: new-business-name,
                   service-description: new-description,
                   is-active: active-status
                 })))
  )
)

;; SERVICE LISTING MANAGEMENT

(define-public (create-service-listing 
  (title (string-ascii 100)) 
  (description (string-ascii 300)) 
  (category uint) 
  (hourly-rate-ustx uint))
  (let (
    (service-id (get-next-service-id))
    (provider-address tx-sender)
    (provider-profile (unwrap! (map-get? robotics-service-providers provider-address) 
                       ERR-RESOURCE-NOT-FOUND))
    (current-service-count (default-to u0 (map-get? provider-service-counts provider-address)))
  )
    (asserts! (get is-active provider-profile) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-non-empty-string title) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string description) ERR-INVALID-PARAMETERS)
    (asserts! (> hourly-rate-ustx u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-service-category category) ERR-INVALID-PARAMETERS)
    
    ;; Create new service listing
    (map-set service-marketplace-listings service-id {
      provider-principal: provider-address,
      service-title: title,
      service-description: description,
      category-type: category,
      hourly-rate-ustx: hourly-rate-ustx,
      is-available: true,
      created-at-block: block-height,
      completed-bookings: u0,
      cumulative-rating-points: u0,
      review-count: u0
    })
    
    ;; Update provider statistics
    (map-set provider-service-counts provider-address (+ current-service-count u1))
    
    (map-set robotics-service-providers provider-address 
             (merge provider-profile {
               services-created: (+ (get services-created provider-profile) u1)
             }))
    
    (ok service-id)
  )
)

(define-public (modify-service-listing 
  (service-id uint) 
  (new-title (string-ascii 100)) 
  (new-description (string-ascii 300)) 
  (new-hourly-rate uint) 
  (availability-status bool))
  (let ((service-data (unwrap! (map-get? service-marketplace-listings service-id) 
                        ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-eq (get provider-principal service-data) tx-sender) 
              ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-non-empty-string new-title) ERR-INVALID-PARAMETERS)
    (asserts! (is-non-empty-string new-description) ERR-INVALID-PARAMETERS)
    (asserts! (> new-hourly-rate u0) ERR-INVALID-PARAMETERS)
    
    (ok (map-set service-marketplace-listings service-id 
                 (merge service-data {
                   service-title: new-title,
                   service-description: new-description,
                   hourly-rate-ustx: new-hourly-rate,
                   is-available: availability-status
                 })))
  )
)

;; BOOKING MANAGEMENT SYSTEM

(define-public (create-service-booking 
  (service-id uint) 
  (start-block uint) 
  (duration-hours uint))
  (let (
    (service-info (unwrap! (map-get? service-marketplace-listings service-id) 
                    ERR-RESOURCE-NOT-FOUND))
    (booking-id (get-next-booking-id))
    (customer-address tx-sender)
    (provider-address (get provider-principal service-info))
    (total-payment (* (get hourly-rate-ustx service-info) duration-hours))
    (platform-fee (calculate-platform-fee total-payment))
  )
    (asserts! (get is-available service-info) ERR-SERVICE-UNAVAILABLE)
    (asserts! (not (is-eq customer-address provider-address)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> duration-hours u0) ERR-INVALID-PARAMETERS)
    (asserts! (> start-block block-height) ERR-INVALID-PARAMETERS)
    
    ;; Transfer customer payment to escrow
    (try! (stx-transfer? total-payment customer-address (as-contract tx-sender)))
    
    ;; Create booking record
    (map-set service-booking-records booking-id {
      service-id: service-id,
      customer-principal: customer-address,
      provider-principal: provider-address,
      start-block-height: start-block,
      duration-hours: duration-hours,
      total-cost-ustx: total-payment,
      platform-fee-ustx: platform-fee,
      current-status: status-awaiting-acceptance,
      created-at-block: block-height,
      completed-at-block: none,
      customer-review-score: none,
      provider-review-score: none
    })
    
    ;; Set up escrow account
    (map-set booking-escrow-accounts booking-id total-payment)
    
    ;; Update service statistics
    (map-set service-marketplace-listings service-id 
             (merge service-info {
               completed-bookings: (+ (get completed-bookings service-info) u1)
             }))
    
    (ok booking-id)
  )
)

(define-public (accept-booking (booking-id uint))
  (let ((booking-data (unwrap! (map-get? service-booking-records booking-id) 
                        ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-eq (get provider-principal booking-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get current-status booking-data) status-awaiting-acceptance) 
              ERR-INVALID-STATE-TRANSITION)
    
    (ok (map-set service-booking-records booking-id 
                 (merge booking-data {
                   current-status: status-provider-confirmed
                 })))
  )
)

(define-public (start-service-execution (booking-id uint))
  (let ((booking-data (unwrap! (map-get? service-booking-records booking-id) 
                        ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-eq (get provider-principal booking-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get current-status booking-data) status-provider-confirmed) 
              ERR-INVALID-STATE-TRANSITION)
    (asserts! (>= block-height (get start-block-height booking-data)) ERR-UNAUTHORIZED-ACCESS)
    
    (ok (map-set service-booking-records booking-id 
                 (merge booking-data {
                   current-status: status-service-in-progress
                 })))
  )
)

(define-public (complete-service-delivery (booking-id uint))
  (let (
    (booking-data (unwrap! (map-get? service-booking-records booking-id) 
                    ERR-RESOURCE-NOT-FOUND))
    (escrow-amount (unwrap! (map-get? booking-escrow-accounts booking-id) 
                     ERR-RESOURCE-NOT-FOUND))
    (provider-address (get provider-principal booking-data))
    (fee-amount (get platform-fee-ustx booking-data))
    (provider-payment (- escrow-amount fee-amount))
    (provider-profile (unwrap! (map-get? robotics-service-providers provider-address) 
                       ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (is-eq provider-address tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get current-status booking-data) status-service-in-progress) 
              ERR-INVALID-STATE-TRANSITION)
    
    ;; Pay provider
    (try! (as-contract (stx-transfer? provider-payment tx-sender provider-address)))
    
    ;; Collect platform fee
    (var-set total-platform-earnings 
             (+ (var-get total-platform-earnings) fee-amount))
    
    ;; Update booking status
    (map-set service-booking-records booking-id 
             (merge booking-data {
               current-status: status-service-completed,
               completed-at-block: (some block-height)
             }))
    
    ;; Clear escrow
    (map-delete booking-escrow-accounts booking-id)
    
    ;; Update provider earnings
    (map-set robotics-service-providers provider-address 
             (merge provider-profile {
               total-earnings-ustx: (+ (get total-earnings-ustx provider-profile) provider-payment)
             }))
    
    (ok true)
  )
)

(define-public (cancel-booking (booking-id uint))
  (let (
    (booking-data (unwrap! (map-get? service-booking-records booking-id) 
                    ERR-RESOURCE-NOT-FOUND))
    (requester tx-sender)
    (customer-address (get customer-principal booking-data))
    (provider-address (get provider-principal booking-data))
    (current-state (get current-status booking-data))
    (refund-amount (unwrap! (map-get? booking-escrow-accounts booking-id) 
                     ERR-RESOURCE-NOT-FOUND))
  )
    ;; Validate booking ID is valid (implicitly done by unwrap! above)
    (asserts! (> booking-id u0) ERR-INVALID-PARAMETERS)
    
    ;; Check authorization
    (asserts! (or (is-eq requester customer-address) 
                  (is-eq requester provider-address)) ERR-UNAUTHORIZED-ACCESS)
    ;; Check cancellable status
    (asserts! (or (is-eq current-state status-awaiting-acceptance) 
                  (is-eq current-state status-provider-confirmed)) ERR-INVALID-STATE-TRANSITION)
    
    ;; Refund customer
    (try! (as-contract (stx-transfer? refund-amount tx-sender customer-address)))
    
    ;; Update booking status
    (map-set service-booking-records booking-id 
             (merge booking-data {
               current-status: status-booking-cancelled
             }))
    
    ;; Clear escrow
    (map-delete booking-escrow-accounts booking-id)
    
    (ok true)
  )
)

;; REPUTATION SYSTEM

(define-public (submit-service-rating 
  (booking-id uint) 
  (rating-score uint) 
  (is-customer-rating bool))
  (let (
    (booking-data (unwrap! (map-get? service-booking-records booking-id) 
                    ERR-RESOURCE-NOT-FOUND))
    (service-id (get service-id booking-data))
    (service-data (unwrap! (map-get? service-marketplace-listings service-id) 
                    ERR-RESOURCE-NOT-FOUND))
    (provider-address (get provider-principal booking-data))
    (provider-profile (unwrap! (map-get? robotics-service-providers provider-address) 
                       ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (is-eq (get current-status booking-data) status-service-completed) 
              ERR-INVALID-STATE-TRANSITION)
    (asserts! (is-valid-rating rating-score) ERR-RATING-OUT-OF-BOUNDS)
    
    (if is-customer-rating
      (begin
        (asserts! (is-eq (get customer-principal booking-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-none (get customer-review-score booking-data)) ERR-OPERATION-ALREADY-COMPLETED)
        
        ;; Update booking with customer rating
        (map-set service-booking-records booking-id 
                 (merge booking-data {
                   customer-review-score: (some rating-score)
                 }))
        
        ;; Update service rating
        (map-set service-marketplace-listings service-id 
                 (merge service-data {
                   cumulative-rating-points: (+ (get cumulative-rating-points service-data) rating-score),
                   review-count: (+ (get review-count service-data) u1)
                 }))
        
        ;; Update provider reputation
        (map-set robotics-service-providers provider-address 
                 (merge provider-profile {
                   reputation-score-sum: (+ (get reputation-score-sum provider-profile) rating-score),
                   total-reviews-received: (+ (get total-reviews-received provider-profile) u1)
                 }))
      )
      (begin
        (asserts! (is-eq provider-address tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-none (get provider-review-score booking-data)) ERR-OPERATION-ALREADY-COMPLETED)
        
        ;; Update booking with provider rating
        (map-set service-booking-records booking-id 
                 (merge booking-data {
                   provider-review-score: (some rating-score)
                 }))
      )
    )
    
    (ok true)
  )
)

;; PLATFORM ADMINISTRATION

(define-public (withdraw-platform-earnings (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= amount (var-get total-platform-earnings)) 
              ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set total-platform-earnings 
             (- (var-get total-platform-earnings) amount))
    
    (ok true)
  )
)

;; READ-ONLY QUERY FUNCTIONS

(define-read-only (get-provider-profile (provider-address principal))
  (map-get? robotics-service-providers provider-address)
)

(define-read-only (get-service-details (service-id uint))
  (map-get? service-marketplace-listings service-id)
)

(define-read-only (get-booking-information (booking-id uint))
  (map-get? service-booking-records booking-id)
)

(define-read-only (calculate-provider-average-rating (provider-address principal))
  (match (map-get? robotics-service-providers provider-address)
    provider-data
      (if (> (get total-reviews-received provider-data) u0)
        (some (/ (get reputation-score-sum provider-data) 
                 (get total-reviews-received provider-data)))
        none
      )
    none
  )
)

(define-read-only (calculate-service-average-rating (service-id uint))
  (match (map-get? service-marketplace-listings service-id)
    service-data
      (if (> (get review-count service-data) u0)
        (some (/ (get cumulative-rating-points service-data) 
                 (get review-count service-data)))
        none
      )
    none
  )
)

(define-read-only (get-platform-earnings-balance)
  (var-get total-platform-earnings)
)

(define-read-only (get-booking-escrow-amount (booking-id uint))
  (map-get? booking-escrow-accounts booking-id)
)

(define-read-only (get-provider-service-count (provider-address principal))
  (default-to u0 (map-get? provider-service-counts provider-address))
)

(define-read-only (is-provider-registered (provider-address principal))
  (is-some (map-get? robotics-service-providers provider-address))
)

(define-read-only (get-platform-statistics)
  {
    total-earnings-collected: (var-get total-platform-earnings),
    next-service-identifier: (var-get next-service-id),
    next-booking-identifier: (var-get next-booking-id),
    marketplace-fee-rate: marketplace-fee-basis-points
  }
)