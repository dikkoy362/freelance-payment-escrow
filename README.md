# Freelance Payment Escrow

A secure freelance payment platform that protects both clients and freelancers through smart contract escrow services. Features milestone-based payments, dispute resolution, skill verification, and automated invoice processing for the gig economy.

## Overview

The Freelance Payment Escrow platform leverages blockchain technology to create a trustless environment where clients and freelancers can engage in secure transactions. The system handles escrow payments, milestone management, reputation tracking, and dispute resolution through transparent smart contracts.

## Features

### Core Functionality
- **Secure Escrow Payments**: Client funds are held in escrow until project milestones are met
- **Milestone-Based Releases**: Payments are released based on verified project completion
- **Dispute Resolution**: Multi-party arbitration system for resolving conflicts
- **Reputation System**: Track freelancer performance and client satisfaction
- **Automated Invoicing**: Generate invoices with tax compliance features

### Smart Contracts

#### 1. Escrow Payment Manager
- Manages secure escrow payments between clients and freelancers
- Handles milestone-based release mechanisms with approval workflows
- Processes dispute resolution through multi-party arbitration
- Maintains payment history and transaction records
- Provides automated invoice generation with tax compliance

#### 2. Freelancer Reputation System  
- Tracks freelancer performance and client satisfaction ratings
- Manages skill verification through completed project portfolios
- Handles client feedback and review systems
- Processes reputation-based pricing recommendations
- Maintains transparent freelancer profiles with verified credentials

## Architecture

```
┌─────────────────┐    ┌──────────────────────┐
│   Client App    │    │   Freelancer App     │
└─────────────────┘    └──────────────────────┘
         │                        │
         └──────────┬──────────────┘
                    │
         ┌─────────────────────────┐
         │   Escrow Platform       │
         └─────────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
┌───────────┐ ┌─────────────┐ ┌────────────┐
│  Escrow   │ │ Reputation  │ │  Stacks    │
│ Payment   │ │   System    │ │ Blockchain │
│ Manager   │ │             │ │            │
└───────────┘ └─────────────┘ └────────────┘
```

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Smart contract development tool
- [Node.js](https://nodejs.org/) - For running tests and development tools
- [Git](https://git-scm.com/) - Version control

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/dikkoy362/freelance-payment-escrow.git
   cd freelance-payment-escrow
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run contract checks:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   clarinet test
   ```

### Development

1. Create new contracts:
   ```bash
   clarinet contract new <contract-name>
   ```

2. Deploy to devnet:
   ```bash
   clarinet console
   ```

3. Deploy to testnet:
   ```bash
   clarinet deploy --testnet
   ```

## Usage

### For Clients

1. **Create Project**: Submit project requirements and budget
2. **Fund Escrow**: Deposit payment into secure escrow contract
3. **Set Milestones**: Define project milestones and payment schedules
4. **Review Work**: Approve completed milestones to release payments
5. **Rate Freelancer**: Provide feedback and ratings upon completion

### For Freelancers

1. **Create Profile**: Set up verified freelancer profile with skills
2. **Browse Projects**: Find suitable projects matching your expertise
3. **Submit Proposals**: Bid on projects with detailed proposals
4. **Deliver Work**: Complete milestones and submit for approval
5. **Receive Payment**: Get paid automatically upon milestone approval

## Smart Contract Documentation

### Escrow Payment Manager

**Public Functions:**
- `create-escrow` - Create new escrow contract
- `fund-escrow` - Fund escrow with STX tokens
- `release-milestone` - Release payment for completed milestone
- `dispute-milestone` - Raise dispute for milestone
- `resolve-dispute` - Admin function to resolve disputes

**Read-Only Functions:**
- `get-escrow-details` - Retrieve escrow information
- `get-milestone-status` - Check milestone completion status
- `get-payment-history` - View payment transaction history

### Freelancer Reputation System

**Public Functions:**
- `register-freelancer` - Register new freelancer profile
- `submit-review` - Submit client review for freelancer
- `verify-skill` - Verify freelancer skill through portfolio
- `update-profile` - Update freelancer information

**Read-Only Functions:**
- `get-freelancer-rating` - Get freelancer overall rating
- `get-review-history` - Retrieve review history
- `get-skill-verification` - Check verified skills

## Testing

Run the test suite:

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/escrow-payment-manager_test.ts

# Run tests with coverage
npm run test:coverage
```

## Security

### Audit Status
- Internal security review: ✅ Completed
- External audit: 🔄 In Progress
- Bug bounty program: 📋 Planned

### Security Features
- Multi-signature escrow releases
- Time-locked dispute resolution
- Reputation-based risk assessment
- Automated compliance checks

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Process
1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## Governance

This project uses decentralized governance for protocol updates:
- Community proposals for feature additions
- Token-weighted voting on protocol changes
- Transparent decision-making process
- Regular community calls and updates

## Roadmap

### Phase 1: Core Platform (Q4 2024)
- ✅ Basic escrow functionality
- ✅ Milestone management
- ✅ Simple reputation system

### Phase 2: Enhanced Features (Q1 2025)
- 🔄 Advanced dispute resolution
- 📋 Multi-currency support
- 📋 Mobile applications

### Phase 3: Ecosystem Growth (Q2 2025)
- 📋 Third-party integrations
- 📋 Advanced analytics
- 📋 Global marketplace

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Documentation: [docs.freelance-escrow.com](https://docs.freelance-escrow.com)
- Discord: [Community Server](https://discord.gg/freelance-escrow)
- Email: support@freelance-escrow.com
- GitHub Issues: Report bugs and request features

## Acknowledgments

- Stacks Foundation for blockchain infrastructure
- Hiro for development tools
- Community contributors and testers
- Security audit partners

---

**Disclaimer**: This is experimental software. Use at your own risk. Always conduct thorough testing before deploying to production.