# 🏦 Credix - Decentralized Credit Scoring Platform

> 📊 Build your on-chain credit profile and access decentralized lending

## 🌟 Overview

Credix is a revolutionary decentralized credit scoring system built on Stacks blockchain. It enables users to build verifiable credit profiles through on-chain lending activities, creating a transparent and trustless credit ecosystem.

## ✨ Features

- 🆔 **Decentralized Identity**: Create and manage your on-chain credit profile
- 📈 **Dynamic Credit Scoring**: Algorithm-based scoring from 300-850 range
- 💰 **P2P Lending**: Direct lending between users without intermediaries  
- 📋 **Loan Management**: Create, track, and repay loans seamlessly
- 🔍 **Transparent History**: All credit activities recorded on-chain
- 📊 **Real-time Analytics**: Track total platform volume and user metrics

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet (Hiro Wallet recommended)
- STX tokens for transactions

### Installation

```bash
git clone <repository-url>
cd credix
clarinet check
```

## 📖 Usage Guide

### 1️⃣ Register as User

```clarity
(contract-call? .Credix register-user)
```

### 2️⃣ Create a Loan

```clarity
(contract-call? .Credix create-loan 'SP1234... u1000 u10 u144)
```
- `borrower`: Principal address
- `amount`: Loan amount in microSTX
- `interest-rate`: Interest percentage (10 = 10%)
- `duration`: Loan duration in blocks

### 3️⃣ Repay Loan

```clarity
(contract-call? .Credix repay-loan u1 u500)
```
- `loan-id`: Unique loan identifier
- `amount`: Repayment amount

### 4️⃣ Check Credit Profile

```clarity
(contract-call? .Credix get-credit-profile 'SP1234...)
```

## 🧮 Credit Score Calculation

The credit score (300-850) is calculated based on:

- **Repayment Ratio** (60%): Total repaid / Total borrowed
- **Payment History** (20%): Number of successful payments
- **Active Loans** (20%): Penalty for too many active loans

## 📋 Contract Functions

### Read-Only Functions
- `get-credit-profile(user)` - Get user's credit profile
- `get-loan(loan-id)` - Get loan details
- `calculate-credit-score(user)` - Calculate current credit score
- `get-loan-status(loan-id)` - Get comprehensive loan status

### Public Functions
- `register-user()` - Create initial credit profile
- `create-loan(borrower, amount, rate, duration)` - Create new loan
- `repay-loan(loan-id, amount)` - Make loan repayment
- `update-user-score(user)` - Refresh credit score

## 🔧 Development

### Testing

```bash
clarinet test
```

### Deploy

```bash
clarinet deploy --testnet
```

## 🛡️ Security Features

- ✅ Authorization checks for all sensitive operations
- ✅ Input validation and sanitization
- ✅ Overflow protection in calculations
- ✅ Comprehensive error handling

## 🎯 Roadmap

- [ ] 🔗 Cross-chain credit verification
- [ ] 🤖 AI-powered risk assessment
- [ ] 🏛️ Integration with DeFi protocols
- [ ] 📱 Mobile application
- [ ] 🌐 Multi-collateral support

## 🤝 Contributing

We welcome contributions! Please feel free to submit issues and pull requests.

## 📄 License

MIT License - see LICENSE file for details

---



