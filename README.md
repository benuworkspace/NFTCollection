# NFT Collection — Portfolio NFT Collection (PNC)

A production-ready ERC721 NFT collection with whitelist mint,
reveal mechanism, and full Etherscan verification.

## Deployed Contract

| Network | Address | Etherscan |
|---------|---------|-----------|
| Sepolia | `0xYourContractAddress` | [View](https://sepolia.etherscan.io/address/0xYourContractAddress) |

## Collection Info

| Property | Value |
|----------|-------|
| Name | Portfolio NFT Collection |
| Symbol | PNC |
| Max Supply | 5 |
| Public Mint Price | 0.01 ETH |
| Whitelist Mint Price | 0.005 ETH |
| Max Per Wallet | 2 |
| Max Per Wallet (WL) | 1 |
| Token ID | Starts from #1 |

## Mint Phases

### Phase 1 — Whitelist Mint (0.005 ETH)
Only addresses in the whitelist can mint.
Verified via Merkle Tree proof — gas efficient and secure.
Maximum 1 NFT per whitelisted address.

### Phase 2 — Public Mint (0.01 ETH)
Open to everyone. Maximum 2 NFTs per wallet.

### Reveal
All NFTs display hidden metadata until owner triggers reveal.
After reveal, each NFT displays its unique metadata from IPFS.

## Metadata

Images and metadata stored on IPFS via Pinata:

| Asset | CID |
|-------|-----|
| Images | `YOUR_IMAGES_CID` |
| Metadata | `YOUR_METADATA_CID` |
| Hidden Metadata | `YOUR_HIDDEN_METADATA_CID` |

## Architecture
```
NFTCollection.sol
├── Inherits: ERC721, Ownable, Pausable, ReentrancyGuard
├── Mint Functions
│   ├── publicMint(quantity) — payable, max 2 per wallet
│   └── whitelistMint(proof) — payable, Merkle verified
├── Admin Functions
│   ├── reveal(baseURI)       — trigger collection reveal
│   ├── togglePublicMint()    — activate/deactivate public mint
│   ├── toggleWhitelistMint() — activate/deactivate WL mint
│   ├── setMintPrice()        — update mint price
│   ├── setMerkleRoot()       — update whitelist
│   ├── ownerMint()           — mint for giveaways/team
│   └── withdraw()            — withdraw ETH to owner
└── View Functions
    ├── getMintInfo()         — all mint data in one call
    ├── getWalletInfo()       — wallet mint status
    └── isWhitelisted()       — verify whitelist status
```

## Test Coverage

```bash
forge test --gas-report
```

75 tests — all passing.

## Security Considerations

**Merkle Tree Whitelist**
Whitelist verified on-chain via Merkle proof.
Only the root (32 bytes) stored in contract — gas efficient.
Root can be updated by owner to add/remove addresses.

**ReentrancyGuard**
Withdraw function protected with nonReentrant modifier.
Prevents reentrancy attacks on ETH withdrawal.

**Checks-Effects-Interactions**
State updated before ETH transfers throughout.

**Refund Mechanism**
Excess ETH automatically refunded to minter.
Mint does not revert if refund fails — prevents DoS.

**Pausable**
Owner can pause all mint operations in emergency.

## License
MIT