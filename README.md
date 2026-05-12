# RatRun Core 🐀🏃‍♂️

The core infrastructure for the RatRun ecosystem, featuring smart contracts, a subgraph, and a high-performance frontend.

## 🏗 Project Structure

```text
ratrun-core/
├── contracts/          # Solidity smart contracts (Foundry)
├── test/               # Smart contract tests
├── script/             # Deployment and management scripts
├── frontend/           # Next.js/Vite web application
├── subgraph/           # The Graph indexing protocol
├── assets/             # Branding and mascot assets
│   ├── branding/       # Logos, ICO icons, and UI previews
│   └── mascot/         # Character designs and emotion sheets
├── docs/               # Technical documentation
├── audit/              # Security audit reports
├── diagrams/           # Architecture and flow diagrams
└── .github/workflows/  # CI/CD pipelines
```

## 🚀 Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v18+)
- [Git](https://git-scm.com/)

### Installation
```bash
# Clone the repository
git clone https://github.com/duesenbek/ratrun-core

# Install dependencies
npm install

# Build contracts
forge build

# Run tests
forge test
```

## 🛠 Tech Stack
- **Contracts**: Solidity & Foundry
- **Frontend**: React (Next.js/Vite)
- **Indexing**: The Graph
- **Oracles**: Chainlink / Pyth

## 🛡 Security
For security concerns, please refer to our `audit/` folder or contact the team directly.

---
*Built with passion for the decentralized rat race.*
