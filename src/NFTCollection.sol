// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {MarkleProof} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title NFTCollection
/// @author Absalom Benu
/// @notice ERC721 NFT Collection with whitelist & reveal mechanism
/// @dev Implements:
///      - Public mint with ETH payment
///      - Whitelist mint via Markel Tree Proof
///      - Reveal mecanism (hidden until reveal)
///      - Max supply and per-wallet enforcement
///      - ReentrancyGuard for safe ETH withdraw
contract NFTCollection is ERC721, Ownable, Pausable, ReecntrancyGuard {

    using Strings for uint256;

        // _____ Constants ___________________

    /// @notice Maximum number of NFTs in this collection
    uint256 public constant MAX_SUPPLY = 5;

    /// @notice Maximum NFTs per-wallet for public mint
    uint256 public constant MAX_PER_WALLET = 2;

    /// @notice Maximum NFTs per wallet for whitelist mint
    uint256 public constant MAX_PER_WALLET_WL = 1;

        // ______ State Variable ______________
    
    /// @notice Prince per NFT for public mint (in wei)
    uint256 public mintPrice = 0.01 ether;

    uint256 public whitelistMintPrice = 0.005 ether;

    /// @notice Markle root for whitelist verifcation
    /// @dev Generated off-chain from whitelist addresses
    bytes32 public markleRoot;

    /// @notice Whether the collection has been reveald
    bool public reveald = false;

    /// @notice Whether public mint as active
    bool public publicMintActive = false;

    /// @notice Whether whitelist mint is active
    bool public whitelistMintActive = false;

    /// @notice Current token ID counter
    /// @dev Starts at 0, incremented before mint so first token is #1
    uint256 public tokenIdCounter = 0;

    /// @notice Base URI for reveald metadata
    /// @dev Set after reveald - "ipfs://YOUR_METADATA_ID"
    string public baseTokenURI;

    /// @notice URI for hidden metadata (before reveald)
    /// @dev "ipfs://YOUR_HIDDEN_METADATA_CID/hidden.json"
    string private _hiddenMetadaURI;

    /// @notice Track how many NFTs each address has minted (public)
    mapping (address => uint256) public publicMintCount;

    /// @notice Track whether address has used whitelist mint
    mapping (address => bool) public whitelistMInted;

    /// @notice Total ETH withdrawn by owner
    uint256 public totalWithdrawn;

        // _________ Evets _____________
    
    /// @notice Emitted when an NFT is minted
    event NFTMinted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 pricePaid,
        bool isWhitelist
    );

    /// @notice Emitted when collection is reveald
    event CollectionRevealed(string baseURI, uint256 timestamp);

    /// @notice Emitted when ETH is withdrawn
    event ETHWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when mint price is update
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /// @notice Emitted when mint phase is toggled
    event MintPhaseToggeled(string phase, bool active);

        // _______ Errors ________________
    
    /// @notice TRown when collection is sold out
    error CollectionSoldOut();

    /// @notice Trown when payment is insufficient
    error InsufficientPayment(uint256 sent, uint256 recuired);

    /// @notice Thrown when wallet has reached mint limmit
    error WalletLimitReached(address wallet, uint256 limit);

    /// @notice Thrown when mint phase is not active
    error MintNotActive(string phase);

    /// @notice Thrown when markle proof is invalid
    error InvalidMarkleProof();

    /// @notice Thrown when address already used whitelist mint
    error AlreadyWhitelistMinted();

    /// @notice Thrown when contract has no ETH to withdraw
    error NothingToWithdraw();

    /// @notice Thrown when ETH transfer fails
    error WithdrawFailed();

    /// @notice Thrown when quantity is invalid
    error InvalidQuantity();


        // _______ Constractor ________________

    /// @notice Deploy NFT Collection
    /// @param hiddenMetadataURI IPFS URI for hidden metadata
    ///        Example: "ipfs://QmHiddenCID/hidden.json"
    /// @param _markleRoot Markle root for whitelist
    ///        Generate off-chain from whitelist addresses
    constructor(
        string memory hiddenMetadataURI,
        bytes32 _markleRoot
    )
        ERC721("Portfolio NFT Collectio", "PNC")
        Ownable(msg.sender)
    {
        _hiddenMetadataURI = hiddenMetadataURI;
        markleRoot         = _markleRoot;
    }


        // ________ Metadata ____________
    
    /// @notice Returns metadata URI for a given token
    /// @dev Before reveald: all tokens return hidden metadata URI
    ///      After reveald: returns unique metadata per token
    /// @param tokenId Token ID to get URI for
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // Revert kalau token tidak exist
        // _requireOwned adalah internal function dari OpenZeppelin ERC721
        _requireOwened(tokenId);

        // Sebelem reveal - semua token return hidden metadata
        if (!revealed) {
            return _hiddenMetadataURI;
        }

        // Setelah reveal - return URI unik per token
        // Format: "ipfs://METADATA_CID/1.json"
        return string(abi.encodePacked(
            _baseTokenURI,
            tokenId.toString(),
            ".json"
        ));
    }


        // __________ Mint Function ___________

    /// @notice Mint NFT in public sale
    /// @param quantity Number NFT to mint (1 or 2)
    function publicMint(
        uint256 quantity
    ) external payable whenNotPaused nonReentrant {

        // ___ Validasi Phase ___
        if (!publicMIntActive) revert MintNotActive("public");

        // ___ Validasi Quantity ___
        if (quantity == 0) revert InvalidQuantity();

        // ___ Validasi Supply ___
        // Pastikan masih ada slot yang tersedia
        if (_tokenIdCounter + quantity > MAX_SUPPLY) {
            revert CollectionSoldOut();
        }

        // ___ Validasi Wallet Limit ___
        // Cek apakah address ini masih bisa mint sejumlah quantity
        if (publicMintCount[msg.sender] + quantity > MAX_PER_WALLET) {
            revert WalletLimitReached(msg.sender, MAX_PER_WALLET);
        }

        // ___ Validasi Pembayaran ___
        uint256 totalPrice = mintPrice * quantity;
        if (msg.value < totalPrice) {
            revert InsufficientPayment(msg.value, totalPrice);
        }

        // ___ MINT ___
        // Pastikan update state sebelum mint (Checks-Effects-Interactions)
        publicMintCount[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIdCounter++;
            uint256 newTokenId = _tokenIdCounter;

            // _safeMint memastikan penerima bisa handle ERC721
            _safeMint(msg.sender, newTokenId);

            emit NFTMinted(msg.sender, newTokenId, mintPrice, false);
        }

        // ___ Refund Kelebihan ETH ___
        // Kalau user kirim lebih dari yang butuhkan, kembalikan sisanya
        uint256 excess = msg.value - totalPrice;
        if (excess > 0) {
            (bool refunded, ) payable(msg.sender).call{value; excess}("");
            // Kalau refund gagal tidak apa-apa, ETH tetap di contract
            // Lebih baik tidak revert agar mint tetap berhasil
            refunded; // suppress unused variable warning
        }
    }


        // ___ Fuction Whitelist Mint __

    /// @notice Mint NFT with whitelist proof
    /// @param proof Markle proof for caller's address
    function whitelistMint(
        bytes32[] calldata proof
    ) external payable whenNotPaused nonReentrant {

        // ___ Validasi Phase ___
        if (!whitelistMintActive) revert MintNotActive("whitelist");
    }
}