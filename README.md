# SoulBadge

**Batch Minting-enabled Digital Certificates Based on Soulbound Token for Achievement Verification**

A blockchain-based solution using Soulbound Tokens (SBTs) to authenticate digital certificates and optimize the verification process. This implementation leverages decentralized and immutable blockchain technology to ensure secure and transparent certificate authentication.

## Overview

Traditional methods of certificate verification relying on paper-based documentation are prone to inefficiencies, errors, and fraud. This project proposes an efficient and reliable certificate verification solution using:

- **Soulbound Tokens (SBTs)**: Non-transferable NFTs that are permanently bound to a recipient's wallet
- **Batch Minting**: Generate and store digital certificates in batches, reducing transaction fees as the number of certificates increases
- **Smart Contract Verification**: Verifiers can authenticate certificates by utilizing the smart contract's verification function

### Key Features

- Non-transferable digital badges (Soulbound)
- Batch minting for cost-effective certificate generation
- Nullifier-based event management for secure claiming
- Double-claim prevention mechanism
- Decentralized storage before distribution

## Architecture

The system consists of two main smart contracts:

### SoulBadge Contract

The core ERC721-based token contract that implements soulbound functionality:

- Inherits from `ERC721URIStorage`, `Ownable`, `ReentrancyGuard`, and `ERC721Burnable`
- Tokens can only be transferred during minting, burning, or through the storage contract
- Supports batch minting with automatic nullifier generation

### BadgeStorage Contract

A temporary storage contract that holds minted badges before distribution to recipients:

- Stores NFTs on behalf of the program manager
- Handles the claim process for attendees/recipients
- Prevents the owner from claiming badges (only attendees can claim)

## How It Works

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Program        │     │   BadgeStorage  │     │    Attendee     │
│  Manager        │     │   Contract      │     │   (Recipient)   │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  1. mintNFTs()        │                       │
         │──────────────────────>│                       │
         │  (batch mint badges)  │                       │
         │                       │                       │
         │  2. storeItem()       │                       │
         │──────────────────────>│                       │
         │  (transfer to storage)│                       │
         │                       │                       │
         │                       │  3. claimBadge()      │
         │                       │<──────────────────────│
         │                       │  (with nullifier)     │
         │                       │                       │
         │                       │  4. Transfer SBT      │
         │                       │──────────────────────>│
         │                       │  (permanently bound)  │
         └───────────────────────┴───────────────────────┘
```

### Process Flow

1. **Registration**: Program manager deploys contracts and prepares event details
2. **Batch Minting**: Manager calls `mintNFTs()` with the number of attendees and token URI, receiving a unique nullifier
3. **Storage**: Minted tokens are transferred to `BadgeStorage` contract via `storeItem()`
4. **Distribution**: Attendees claim their badges using `claimBadge()` with the event nullifier
5. **Verification**: Anyone can verify certificate authenticity by checking token ownership on-chain

## Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/soul-badge.git
cd soul-badge

# Install dependencies
forge install

# Build
forge build

# Run tests
forge test
```

## Usage

### Deploy Contracts

```bash
# Start local node
anvil

# Deploy (customize the script as needed)
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --private-key <your_private_key> --broadcast
```

### Contract Interaction

#### Mint Badges (Owner Only)

```solidity
// Mint 100 badges for an event
bytes32 nullifier = soulBadge.mintNFTs(100, "ipfs://QmYourTokenURI");
```

#### Store Badges

```solidity
// Store each minted token in BadgeStorage
badgeStorage.storeItem(soulBadgeAddress, tokenId);
```

#### Claim Badge (Attendee)

```solidity
// Attendee claims their badge using the event nullifier
badgeStorage.claimBadge(soulBadgeAddress, nullifier);
```

#### Query Claimers

```solidity
// Get all claimers for an event
(address[] memory addresses, uint[] memory tokenIds, bool[] memory claimed) = soulBadge.getClaimer(nullifier);
```

## Contract Details

### SoulBadge Functions

| Function | Access | Description |
|----------|--------|-------------|
| `mintNFTs(uint, string)` | Owner | Batch mint badges, returns nullifier |
| `claim(bytes32, address)` | Public | Internal claim logic, called by BadgeStorage |
| `getClaimer(bytes32)` | View | Get all claimers for an event |
| `tokenURI(uint256)` | View | Get token metadata URI |

### BadgeStorage Functions

| Function | Access | Description |
|----------|--------|-------------|
| `storeItem(address, uint)` | Owner | Store a minted NFT in the contract |
| `claimBadge(address, bytes32)` | Public | Claim a badge (attendees only) |

### Events

```solidity
// SoulBadge
event eventCreated(uint maxAttendees, string eventInfo, bytes32 nullifier);

// BadgeStorage
event ItemStored(address indexed nftContract, uint indexed tokenId, address creator, address owner, bool claim);
event badgeClaimed(address recipient, uint tokenId, uint remainingTokens);
```

## Soulbound Mechanism

The soulbound property is enforced in the `_update` function:

```solidity
require(
    from == address(0) ||      // Minting is allowed
    to == address(0) ||        // Burning is allowed
    from == storageAddress ||  // Transfer from storage is allowed
    to == storageAddress,      // Transfer to storage is allowed
    "Err: token is SOUL BOUND"
);
```

Once a badge is claimed by an attendee, it cannot be transferred to any other address.

## Tech Stack

- **Solidity** ^0.8.33
- **OpenZeppelin Contracts** v5.x
- **Foundry** (Forge, Cast, Anvil)

## Research Paper

This implementation is based on the research paper:

> **Batch Minting-enabled Digital Certificates Based on Soulbound Token for Achievement Verification**
>
> Muhammad Rasyid Redha Ansori, Allwinnaldo, Revin Naufal Alief, Ikechi Saviour Igboanusi, Jae Min Lee, and Dong-Seong Kim
>
> Department of IT Convergence Engineering & ICT Convergence Research Center
> Kumoh National Institute of Technology, Gumi, South Korea

### Citation

```bibtex
@article{ansori2024soulbadge,
  title={Batch Minting-enabled Digital Certificates Based on Soulbound Token for Achievement Verification},
  author={Ansori, Muhammad Rasyid Redha and Allwinnaldo and Alief, Revin Naufal and Igboanusi, Ikechi Saviour and Lee, Jae Min and Kim, Dong-Seong},
  institution={Kumoh National Institute of Technology},
  address={Gumi, South Korea}
}
```

## License

MIT License
