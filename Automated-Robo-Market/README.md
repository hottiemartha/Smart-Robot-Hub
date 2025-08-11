# Autonomous Robotics Marketplace Smart Contract

A decentralized platform connecting customers with autonomous robotics service providers on the Stacks blockchain. This marketplace enables secure booking, automated payments, reputation management, and multi-category service offerings across various robotics sectors.

## Overview

The Autonomous Robotics Marketplace is a trustless platform that facilitates transactions between robotics service providers and customers. Built on Clarity smart contracts, it provides a secure, transparent, and efficient way to book and pay for robotics services ranging from household automation to industrial maintenance.

## Key Features

- **Decentralized Provider Registration** - Blockchain-verified service provider onboarding
- **Multi-Category Service Marketplace** - Support for 5 different robotics service categories
- **Secure Escrow Payment System** - Automated fund release upon service completion
- **Bidirectional Reputation System** - Quality assurance through customer and provider ratings
- **Dynamic Service Lifecycle Management** - State validation throughout the booking process
- **Transparent Governance** - Automated platform fee collection (2.5%)

## Service Categories

The marketplace supports five main robotics service categories:

| Category | ID | Description |
|----------|----|-----------| 
| Household Automation | 100 | Home cleaning, organization, smart home integration |
| Logistics & Delivery | 200 | Package delivery, inventory management, transportation |
| Security & Monitoring | 300 | Surveillance, patrol services, access control |
| Maintenance Services | 400 | Equipment maintenance, repairs, inspections |
| Entertainment Robotics | 500 | Events, performances, interactive experiences |

## Booking Lifecycle

Services follow a structured lifecycle with the following states:

1. **Awaiting Acceptance** (10) - Initial booking created, waiting for provider confirmation
2. **Provider Confirmed** (20) - Provider has accepted the booking
3. **Service In Progress** (30) - Service execution has begun
4. **Service Completed** (40) - Service finished, payment released
5. **Booking Cancelled** (50) - Booking cancelled by either party
6. **Dispute Pending** (60) - Dispute resolution in progress

## Core Functions

### Provider Management

#### `register-service-provider`
Register as a new robotics service provider.
```clarity
(register-service-provider "RoboClean Pro" "Professional home cleaning robots")
```

#### `update-provider-profile`
Update provider business information and availability status.
```clarity
(update-provider-profile "Updated Business Name" "New description" true)
```

### Service Listing Management

#### `create-service-listing`
Create a new service offering in the marketplace.
```clarity
(create-service-listing 
  "Home Deep Clean Service" 
  "Complete automated home cleaning with advanced robotics" 
  u100  ;; household-automation category
  u50)  ;; 50 µSTX per hour
```

#### `modify-service-listing`
Update existing service details, pricing, and availability.
```clarity
(modify-service-listing service-id "New Title" "New Description" u60 true)
```

### Booking Management

#### `create-service-booking`
Book a robotics service with escrow payment.
```clarity
(create-service-booking 
  u1001  ;; service-id
  u1000  ;; start-block-height
  u3)    ;; duration-hours
```

#### `accept-booking`
Provider accepts a pending booking request.
```clarity
(accept-booking u2001)
```

#### `start-service-execution`
Mark service as started (can only be called after start block height).
```clarity
(start-service-execution u2001)
```

#### `complete-service-delivery`
Complete service and release payment to provider.
```clarity
(complete-service-delivery u2001)
```

#### `cancel-booking`
Cancel booking (available before service starts).
```clarity
(cancel-booking u2001)
```

### Reputation System

#### `submit-service-rating`
Submit a rating for completed service (1-5 stars).
```clarity
(submit-service-rating u2001 u5 true)  ;; 5-star customer rating
```

## Read-Only Functions

### Provider Information
- `get-provider-profile` - Get provider details and statistics
- `calculate-provider-average-rating` - Calculate provider's average rating
- `get-provider-service-count` - Get number of services offered by provider
- `is-provider-registered` - Check if address is registered provider

### Service Information
- `get-service-details` - Get service listing details
- `calculate-service-average-rating` - Calculate average rating for specific service

### Booking Information
- `get-booking-information` - Get complete booking details
- `get-booking-escrow-amount` - Check escrow amount for booking

### Platform Statistics
- `get-platform-statistics` - Get platform-wide metrics
- `get-platform-earnings-balance` - Check total platform earnings

## Economic Model

- **Platform Fee**: 2.5% of each transaction
- **Payment Flow**: Customer → Escrow → Provider (minus platform fee)
- **Refund Policy**: Full refund available before service starts
- **Minimum Rating**: 1-5 star system for quality control

## Security Features

### Access Control
- Provider-only functions protected by principal verification
- Owner-only administrative functions
- Customer authorization for bookings and ratings

### Input Validation
- Non-empty string requirements for descriptions
- Valid category and rating range checks
- Positive amount validations
- State transition validations

### Financial Security
- Escrow system prevents payment disputes
- Atomic operations for payment releases
- Protected fund transfers with error handling

## Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Access to Stacks blockchain (mainnet/testnet)
- Clarity development environment (optional for development)

### For Service Providers
1. Register as a provider using `register-service-provider`
2. Create service listings with `create-service-listing`
3. Monitor for booking requests
4. Accept bookings and provide services
5. Complete services to receive payment

### For Customers
1. Browse available services using read-only functions
2. Create bookings with `create-service-booking`
3. Wait for provider acceptance
4. Receive service and submit rating
5. Automatic payment release upon completion

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 4000 | ERR-INVALID-PARAMETERS | Invalid input parameters provided |
| 4001 | ERR-UNAUTHORIZED-ACCESS | Caller not authorized for this operation |
| 4002 | ERR-PROVIDER-ALREADY-EXISTS | Provider already registered |
| 4003 | ERR-INSUFFICIENT-FUNDS | Not enough funds for operation |
| 4004 | ERR-RESOURCE-NOT-FOUND | Requested resource does not exist |
| 4005 | ERR-SERVICE-UNAVAILABLE | Service is not currently available |
| 4006 | ERR-BOOKING-NOT-ACTIVE | Booking is not in active state |
| 4007 | ERR-INVALID-STATE-TRANSITION | Invalid state change attempted |
| 4008 | ERR-OPERATION-ALREADY-COMPLETED | Operation already performed |
| 4009 | ERR-RATING-OUT-OF-BOUNDS | Rating must be between 1-5 |

## Best Practices

### For Providers
- Maintain accurate service descriptions
- Respond promptly to booking requests
- Provide quality services to maintain reputation
- Keep availability status updated

### For Customers
- Review provider ratings before booking
- Provide clear service requirements
- Submit honest ratings after service completion
- Allow sufficient time for service delivery