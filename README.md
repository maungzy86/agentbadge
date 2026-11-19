# AgentBadge (ABDG)

A free NFT badge on BNB Chain that **only Binance Agent ID (.ai) holders can mint** — one per wallet, with its rarity rolled on-chain at mint time.

Built for the **Binance Agent ID Hackathon** (Project Awards submission).

## Live product

- Website: https://agentbadge.cloudzyro.app
- Contract (BNB Chain, chain 56): `0x126AF9585953004cbB9c5a0B37FC5616DD5F3B43`
- BscScan (source verified): https://bscscan.com/address/0x126AF9585953004cbB9c5a0B37FC5616DD5F3B43#code
- Sourcify: exact match (creation + runtime)

## How it works

- The `mint()` function checks **inside the smart contract** whether the caller's wallet holds an Agent ID in the official SPACE ID Agent ID contract on BNB Chain (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`). If `balanceOf(caller) == 0`, the mint reverts — there is no other way to obtain a badge.
- One badge per wallet, enforced on-chain. Minting is free; the minter only pays network gas.
- Rarity is rolled on-chain at mint time: `keccak256(prevrandao, minter, tokenId) % 100`

| Rarity    | Chance |
|-----------|--------|
| COMMON    | 60%    |
| RARE      | 25%    |
| EPIC      | 10%    |
| LEGENDARY | 4%     |
| MYTHIC    | 1%     |

- Max supply: 3,333.

## Why Agent ID

AgentBadge turns an Agent ID into a visible, verifiable identity credential: holding the badge proves the wallet is a real Agentic Wallet Agent ID holder. The same pattern gives any project a simple, Sybil-resistant way to gate rewards, drops, and access to genuine Agent ID holders — the gate is verified by the contract itself, not by a website or a list.

## Safety & disclosures

- Self-contained ERC-721 (no external dependencies), Solidity 0.8.26, MIT license.
- The contract holds **no user funds** and has no sale or royalty mechanics.
- The owner's only power is `setBaseURI` (metadata location). There is no owner mint, no pause, no proxy, no upgrade path, and no way to move users' badges or funds.
- AgentBadge is an independent project. It is not affiliated with or endorsed by Binance or SPACE ID; names are used only to describe the on-chain integration.

## Source

- Contract: [`contracts/AgentBadge.sol`](contracts/AgentBadge.sol) — the exact source verified on BscScan and Sourcify for the deployed contract above.
