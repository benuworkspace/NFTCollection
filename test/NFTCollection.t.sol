// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NFTCollection} from "../src/NFTCollection.sol";
import {Merkle} from "../lib/murky/src/Merkle.sol";

contract NFTCollectionTest is Test {

    // ______ Setup ______

    NFTCollection public nft;
    Merkle public merkleLib;

    /// @dev Implement IERC721Receiver agar test contract bisa terima NFT
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev Allow test contract to receive ETH from withdraw
    receive() external payable {}

    // Addresses
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public nonWhitelisted;

    // Whitelist config
    bytes32[] public leaves;
    bytes32 public merkleRoot;

    // Merkle proofs untuk masing-masing address
    bytes32[] public proofUser1;
    bytes32[] public proofUser2;
    bytes32[] public proofUser3;

    // IPFS URIs (placeholder untuk test)
    string public constant HIDDEN_URI =
        "ipfs://QmHiddenCID/hidden.json";
    string public constant BASE_URI =
        "ipfs://QmMetadataCID/";

    // Mint config
    uint256 public constant MINT_PRICE    = 0.01 ether;
    uint256 public constant WL_PRICE      = 0.005 ether;
    uint256 public constant MAX_SUPPLY    = 5;
    uint256 public constant MAX_PER_WALLET = 2;

    // Events untuk expectEmit
    event NFTMinted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 pricePaid,
        bool isWhitelist
    );
    event CollectionRevealed(string baseURI, uint256 timestamp);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event MintPhaseToggled(string phase, bool active);

    function setUp() public {
        owner          = address(this);
        user1          = makeAddr("user1");
        user2          = makeAddr("user2");
        user3          = makeAddr("user3");
        nonWhitelisted = makeAddr("nonWhitelisted");

        // Beri ETH ke semua user untuk test
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(nonWhitelisted, 10 ether);

        // _____ Setup Merkle Tree ______
        merkleLib = new Merkle();

        // Buat leaves dari whitelist addresses
        // PENTING: urutan harus konsisten antara test dan contract
        leaves = new bytes32[](3);
        leaves[0] = keccak256(abi.encodePacked(user1));
        leaves[1] = keccak256(abi.encodePacked(user2));
        leaves[2] = keccak256(abi.encodePacked(user3));

        // Generate root dari semua leaves
        merkleRoot = merkleLib.getRoot(leaves);

        // Generate proof untuk masing-masing user
        proofUser1 = merkleLib.getProof(leaves, 0);  // proof untuk user1
        proofUser2 = merkleLib.getProof(leaves, 1);  // proof untuk user2
        proofUser3 = merkleLib.getProof(leaves, 2);  // proof untuk user3

        // ___ Deploy contract ___
        nft = new NFTCollection(HIDDEN_URI, merkleRoot);
    }

    // ______ Helper Functions ______

    /// @dev Aktifkan public mint dan return
    function _activatePublicMint() internal {
        if (!nft.publicMintActive()) {
            nft.togglePublicMint();
        }
        assertTrue(nft.publicMintActive());
    }

    function _activateWhitelistMint() internal {
        if (!nft.whitelistMintActive()) {
            nft.toggleWhitelistMint();
        }
        assertTrue(nft.whitelistMintActive());
    }

    /// @dev Reveal collection dengan base URI
    function _reveal() internal {
        nft.reveal(BASE_URI);
        assertTrue(nft.revealed());
    }

    /// @dev Mint sejumlah NFT untuk user via public mint
    function _publicMintFor(address user, uint256 quantity) internal {
        if (!nft.publicMintActive()) {
            nft.togglePublicMint();
        }
        vm.prank(user);
        nft.publicMint{value: MINT_PRICE * quantity}(quantity);
    }

    // =============================================================
    //                    DEPLOYMENT TESTS
    // =============================================================

    function test_Deploy_Name() public view {
        assertEq(nft.name(), "Portfolio NFT Collection");
    }

    function test_Deploy_Symbol() public view {
        assertEq(nft.symbol(), "PNC");
    }

    function test_Deploy_Owner() public view {
        assertEq(nft.owner(), owner);
    }

    function test_Deploy_MaxSupply() public view {
        assertEq(nft.MAX_SUPPLY(), MAX_SUPPLY);
    }

    function test_Deploy_MaxPerWallet() public view {
        assertEq(nft.MAX_PER_WALLET(), MAX_PER_WALLET);
    }

    function test_Deploy_InitialSupplyZero() public view {
        assertEq(nft.totalSupply(), 0);
    }

    function test_Deploy_MintPrice() public view {
        assertEq(nft.mintPrice(), MINT_PRICE);
    }

    function test_Deploy_WhitelistPrice() public view {
        assertEq(nft.whitelistMintPrice(), WL_PRICE);
    }

    function test_Deploy_PublicMintNotActive() public view {
        assertFalse(nft.publicMintActive());
    }

    function test_Deploy_WhitelistMintNotActive() public view {
        assertFalse(nft.whitelistMintActive());
    }

    function test_Deploy_NotRevealed() public view {
        assertFalse(nft.revealed());
    }

    function test_Deploy_MerkleRootSet() public view {
        assertEq(nft.merkleRoot(), merkleRoot);
    }

    function test_Deploy_HiddenTokenURI() public {
        // Mint dulu supaya ada token untuk dicek
        nft.ownerMint(owner, 1);

        // Sebelum reveal, semua token return hidden URI
        string memory uri = nft.tokenURI(1);
        assertEq(uri, HIDDEN_URI);
    }

    // =============================================================
    //                    PUBLIC MINT TESTS
    // =============================================================

    function test_PublicMint_Success_OneToken() public {
        _activatePublicMint();

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.publicMintCount(user1), 1);
    }

    function test_PublicMint_Success_TwoTokens() public {
        _activatePublicMint();

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user1);
        assertEq(nft.totalSupply(), 2);
        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.publicMintCount(user1), 2);
    }

    function test_PublicMint_EmitsEvent() public {
        _activatePublicMint();

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(user1, 1, MINT_PRICE, false);

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_PublicMint_TokenIdIncrementsCorrectly() public {
        _activatePublicMint();

        // User1 mint 1
        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);

        // User2 mint 1
        vm.prank(user2);
        nft.publicMint{value: MINT_PRICE}(1);

        // Token IDs harus 1 dan 2, berurutan
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user2);
    }

    function test_PublicMint_ETHAccumulatesInContract() public {
        _activatePublicMint();

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);

        vm.prank(user2);
        nft.publicMint{value: MINT_PRICE}(1);

        assertEq(address(nft).balance, MINT_PRICE * 2);
    }

    function test_PublicMint_RevertsIfNotActive() public {
        // Public mint belum diaktifkan
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                NFTCollection.MintNotActive.selector,
                "public"
            )
        );
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_PublicMint_RevertsIfSoldOut() public {
        _activatePublicMint();

        // Mint semua 5 NFT (max supply)
        // user1 mint 2, user2 mint 2, owner mint 1
        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        vm.prank(user2);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        nft.ownerMint(owner, 1);  // owner mint sisa 1

        // Sekarang sold out — user3 tidak bisa mint
        vm.prank(user3);
        vm.expectRevert(
            abi.encodeWithSelector(NFTCollection.CollectionSoldOut.selector)
        );
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_PublicMint_RevertsIfInsufficientPayment() public {
        _activatePublicMint();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                NFTCollection.InsufficientPayment.selector,
                0.005 ether,  // yang dikirim
                MINT_PRICE    // yang dibutuhkan
            )
        );
        nft.publicMint{value: 0.005 ether}(1);
    }

    function test_PublicMint_RevertsIfWalletLimitReached() public {
        _activatePublicMint();

        // User1 mint 2 (limit)
        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        // User1 coba mint lagi — harus revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                NFTCollection.WalletLimitReached.selector,
                user1,
                MAX_PER_WALLET
            )
        );
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_PublicMint_RevertsIfQuantityZero() public {
        _activatePublicMint();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(NFTCollection.InvalidQuantity.selector)
        );
        nft.publicMint{value: 0}(0);
    }

    function test_PublicMint_RefundsExcessETH() public {
        _activatePublicMint();

        uint256 balanceBefore = user1.balance;
        uint256 overpayment   = MINT_PRICE + 0.1 ether;

        vm.prank(user1);
        nft.publicMint{value: overpayment}(1);

        // User1 harus hanya kehilangan MINT_PRICE, bukan overpayment
        assertEq(user1.balance, balanceBefore - MINT_PRICE);
    }

    function test_PublicMint_MultipleUsers() public {
        _activatePublicMint();

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);

        vm.prank(user2);
        nft.publicMint{value: MINT_PRICE}(1);

        vm.prank(user3);
        nft.publicMint{value: MINT_PRICE}(1);

        assertEq(nft.totalSupply(), 3);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user2);
        assertEq(nft.ownerOf(3), user3);
    }

    // =============================================================
    //                  WHITELIST MINT TESTS
    // =============================================================

    function test_WhitelistMint_Success() public {
        _activateWhitelistMint();

        vm.prank(user1);
        nft.whitelistMint{value: WL_PRICE}(proofUser1);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalSupply(), 1);
        assertTrue(nft.whitelistMinted(user1));
    }

    function test_WhitelistMint_EmitsEvent() public {
        _activateWhitelistMint();

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(user1, 1, WL_PRICE, true);

        vm.prank(user1);
        nft.whitelistMint{value: WL_PRICE}(proofUser1);
    }

    function test_WhitelistMint_AllWhitelistedUsersCanMint() public {
        _activateWhitelistMint();

        vm.prank(user1);
        nft.whitelistMint{value: WL_PRICE}(proofUser1);

        vm.prank(user2);
        nft.whitelistMint{value: WL_PRICE}(proofUser2);

        vm.prank(user3);
        nft.whitelistMint{value: WL_PRICE}(proofUser3);

        assertEq(nft.totalSupply(), 3);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user2);
        assertEq(nft.ownerOf(3), user3);
    }

    function test_WhitelistMint_RevertsIfNotActive() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                NFTCollection.MintNotActive.selector,
                "whitelist"
            )
        );
        nft.whitelistMint{value: WL_PRICE}(proofUser1);
    }

    function test_WhitelistMint_RevertsIfInvalidProof() public {
        _activateWhitelistMint();

        // Gunakan proof milik user1 untuk user2 — harus gagal
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(NFTCollection.InvalidMerkleProof.selector)
        );
        nft.whitelistMint{value: WL_PRICE}(proofUser1);
    }

    function test_WhitelistMint_RevertsIfNotWhitelisted() public {
        _activateWhitelistMint();

        // nonWhitelisted tidak ada di whitelist
        // Gunakan proof kosong
        bytes32[] memory emptyProof = new bytes32[](0);

        vm.prank(nonWhitelisted);
        vm.expectRevert(
            abi.encodeWithSelector(NFTCollection.InvalidMerkleProof.selector)
        );
        nft.whitelistMint{value: WL_PRICE}(emptyProof);
    }

    function test_WhitelistMint_RevertsIfAlreadyMinted() public {
        _activateWhitelistMint();

        // User1 mint pertama kali — sukses
        vm.prank(user1);
        nft.whitelistMint{value: WL_PRICE}(proofUser1);

        // User1 coba mint lagi — harus revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(NFTCollection.AlreadyWhitelistMinted.selector)
        );
        nft.whitelistMint{value: WL_PRICE}(proofUser1);
    }

    function test_WhitelistMint_RevertsIfInsufficientPayment() public {
        _activateWhitelistMint();

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                NFTCollection.InsufficientPayment.selector,
                0.001 ether,
                WL_PRICE
            )
        );
        nft.whitelistMint{value: 0.001 ether}(proofUser1);
    }

    function test_WhitelistMint_RefundsExcess() public {
        _activateWhitelistMint();

        uint256 balanceBefore = user1.balance;
        uint256 overpayment   = WL_PRICE + 0.05 ether;

        vm.prank(user1);
        nft.whitelistMint{value: overpayment}(proofUser1);

        // Hanya WL_PRICE yang diambil
        assertEq(user1.balance, balanceBefore - WL_PRICE);
    }

    function test_WhitelistMint_IsWhitelisted_ViewFunction() public view {
        // Verifikasi view function isWhitelisted
        assertTrue(nft.isWhitelisted(proofUser1, user1));
        assertTrue(nft.isWhitelisted(proofUser2, user2));
        assertFalse(nft.isWhitelisted(proofUser1, nonWhitelisted));
    }

    // =============================================================
    //                    TOKEN URI TESTS
    // =============================================================

    function test_TokenURI_BeforeReveal_ReturnsHidden() public {
        nft.ownerMint(owner, 3);

        // Semua token return hidden URI sebelum reveal
        assertEq(nft.tokenURI(1), HIDDEN_URI);
        assertEq(nft.tokenURI(2), HIDDEN_URI);
        assertEq(nft.tokenURI(3), HIDDEN_URI);
    }

    function test_TokenURI_AfterReveal_ReturnsUnique() public {
        nft.ownerMint(owner, 3);
        _reveal();

        assertEq(nft.tokenURI(1), string(abi.encodePacked(BASE_URI, "1.json")));
        assertEq(nft.tokenURI(2), string(abi.encodePacked(BASE_URI, "2.json")));
        assertEq(nft.tokenURI(3), string(abi.encodePacked(BASE_URI, "3.json")));
    }

    function test_TokenURI_RevertsForNonExistentToken() public view {
        // Token #999 tidak exist — harus revert
        // Foundry test untuk revert tanpa spesifik error
        // Karena OpenZeppelin throw error internal
        // kita pakai try-catch pattern
        try nft.tokenURI(999) returns (string memory) {
            // Kalau tidak revert, fail test
            assertTrue(false, "Should have reverted");
        } catch {
            // Expected — test pass
            assertTrue(true);
        }
    }

    function test_TokenURI_AfterReveal_Token5() public {
        nft.ownerMint(owner, MAX_SUPPLY);
        _reveal();

        assertEq(
            nft.tokenURI(MAX_SUPPLY),
            string(abi.encodePacked(BASE_URI, "5.json"))
        );
    }

    // =============================================================
    //                      REVEAL TESTS
    // =============================================================

    function test_Reveal_Success() public {
        assertFalse(nft.revealed());

        nft.reveal(BASE_URI);

        assertTrue(nft.revealed());
    }

    function test_Reveal_EmitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit CollectionRevealed(BASE_URI, block.timestamp);

        nft.reveal(BASE_URI);
    }

    function test_Reveal_ChangesTokenURI() public {
        nft.ownerMint(owner, 1);

        // Sebelum reveal
        assertEq(nft.tokenURI(1), HIDDEN_URI);

        // Reveal
        nft.reveal(BASE_URI);

        // Setelah reveal
        assertEq(nft.tokenURI(1), string(abi.encodePacked(BASE_URI, "1.json")));
    }

    function test_Reveal_RevertsIfAlreadyRevealed() public {
        nft.reveal(BASE_URI);

        vm.expectRevert("Already revealed");
        nft.reveal(BASE_URI);
    }

    function test_Reveal_RevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.reveal(BASE_URI);
    }

    function test_Reveal_RevertsIfEmptyURI() public {
        vm.expectRevert("Empty base URI");
        nft.reveal("");
    }

    // =============================================================
    //                      ADMIN TESTS
    // =============================================================

    function test_TogglePublicMint() public {
        assertFalse(nft.publicMintActive());

        nft.togglePublicMint();
        assertTrue(nft.publicMintActive());

        nft.togglePublicMint();
        assertFalse(nft.publicMintActive());
    }

    function test_ToggleWhitelistMint() public {
        assertFalse(nft.whitelistMintActive());

        nft.toggleWhitelistMint();
        assertTrue(nft.whitelistMintActive());

        nft.toggleWhitelistMint();
        assertFalse(nft.whitelistMintActive());
    }

    function test_SetMintPrice() public {
        uint256 newPrice = 0.05 ether;
        nft.setMintPrice(newPrice);
        assertEq(nft.mintPrice(), newPrice);
    }

    function test_SetMintPrice_NewPriceApplied() public {
        nft.setMintPrice(0.02 ether);
        _activatePublicMint();

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        nft.publicMint{value: 0.02 ether}(1);

        assertEq(user1.balance, balanceBefore - 0.02 ether);
        assertEq(address(nft).balance, 0.02 ether);
    }

    function test_SetMintPrice_RevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setMintPrice(0.02 ether);
    }

    function test_SetMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        nft.setMerkleRoot(newRoot);
        assertEq(nft.merkleRoot(), newRoot);
    }

    function test_SetMerkleRoot_NewWhitelistApplied() public {
        // Buat whitelist baru untuk nonWhitelisted dan user1 agar Merkle library dapat bekerja
        bytes32[] memory newLeaves = new bytes32[](2);
        newLeaves[0] = keccak256(abi.encodePacked(nonWhitelisted));
        newLeaves[1] = keccak256(abi.encodePacked(user1));

        bytes32 newRoot             = merkleLib.getRoot(newLeaves);
        bytes32[] memory newProof   = merkleLib.getProof(newLeaves, 0);

        nft.setMerkleRoot(newRoot);
        _activateWhitelistMint();

        // nonWhitelisted sekarang bisa mint
        vm.prank(nonWhitelisted);
        nft.whitelistMint{value: WL_PRICE}(newProof);

        assertEq(nft.ownerOf(1), nonWhitelisted);
    }

    function test_OwnerMint_Success() public {
        nft.ownerMint(owner, 3);

        assertEq(nft.totalSupply(), 3);
        assertEq(nft.balanceOf(owner), 3);
    }

    function test_OwnerMint_RevertsIfSoldOut() public {
        nft.ownerMint(owner, MAX_SUPPLY);

        vm.expectRevert(
            abi.encodeWithSelector(NFTCollection.CollectionSoldOut.selector)
        );
        nft.ownerMint(owner, 1);
    }

    function test_OwnerMint_RevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.ownerMint(user1, 1);
    }

    function test_Pause_BlocksPublicMint() public {
        _activatePublicMint();
        nft.pause();

        vm.prank(user1);
        vm.expectRevert();
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_Pause_BlocksWhitelistMint() public {
        _activateWhitelistMint();
        nft.pause();

        vm.prank(user1);
        vm.expectRevert();
        nft.whitelistMint{value: WL_PRICE}(proofUser1);
    }

    function test_Unpause_RestoresMint() public {
        _activatePublicMint();
        nft.pause();
        nft.unpause();

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);

        assertEq(nft.ownerOf(1), user1);
    }

    // =============================================================
    //                    WITHDRAW TESTS
    // =============================================================

    function test_Withdraw_Success() public {
        // Isi contract dengan ETH dari minting
        _publicMintFor(user1, 2);
        _publicMintFor(user2, 2);

        uint256 contractBalance = address(nft).balance;
        uint256 ownerBefore     = owner.balance;

        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBefore + contractBalance);
    }

    function test_Withdraw_EmitsEvent() public {
        _publicMintFor(user1, 1);

        uint256 balance = address(nft).balance;

        vm.expectEmit(true, false, false, true);
        emit ETHWithdrawn(owner, balance);

        nft.withdraw();
    }

    function test_Withdraw_UpdatesTotalWithdrawn() public {
        _publicMintFor(user1, 2);

        uint256 balance = address(nft).balance;
        nft.withdraw();

        assertEq(nft.totalWithdrawn(), balance);
    }

    function test_Withdraw_RevertsIfNothingToWithdraw() public {
        vm.expectRevert(
            abi.encodeWithSelector(NFTCollection.NothingToWithdraw.selector)
        );
        nft.withdraw();
    }

    function test_Withdraw_RevertsIfNotOwner() public {
        _publicMintFor(user1, 1);

        vm.prank(user1);
        vm.expectRevert();
        nft.withdraw();
    }

    function test_Withdraw_MultipleWithdraws() public {
        _publicMintFor(user1, 1);
        uint256 firstBalance = address(nft).balance;
        nft.withdraw();

        _publicMintFor(user2, 1);
        uint256 secondBalance = address(nft).balance;
        nft.withdraw();

        assertEq(nft.totalWithdrawn(), firstBalance + secondBalance);
    }

    // =============================================================
    //                    VIEW FUNCTION TESTS
    // =============================================================

    function test_GetMintInfo_InitialState() public view {
        (
            uint256 _totalSupply,
            uint256 _maxSupply,
            uint256 _remaining,
            uint256 _mintPrice,
            uint256 _wlPrice,
            bool _publicActive,
            bool _wlActive,
            bool _revealed,
            bool _paused
        ) = nft.getMintInfo();

        assertEq(_totalSupply, 0);
        assertEq(_maxSupply, MAX_SUPPLY);
        assertEq(_remaining, MAX_SUPPLY);
        assertEq(_mintPrice, MINT_PRICE);
        assertEq(_wlPrice, WL_PRICE);
        assertFalse(_publicActive);
        assertFalse(_wlActive);
        assertFalse(_revealed);
        assertFalse(_paused);
    }

    function test_GetMintInfo_AfterMints() public {
        _activatePublicMint();

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        (
            uint256 _totalSupply,
            uint256 _maxSupply,
            uint256 _remaining,
            ,,,,,
        ) = nft.getMintInfo();

        assertEq(_totalSupply, 2);
        assertEq(_maxSupply, MAX_SUPPLY);
        assertEq(_remaining, MAX_SUPPLY - 2);
    }

    function test_GetWalletInfo() public {
        _activatePublicMint();

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);

        (
            uint256 publicMinted,
            uint256 publicRemaining,
            bool wlUsed
        ) = nft.getWalletInfo(user1);

        assertEq(publicMinted, 1);
        assertEq(publicRemaining, MAX_PER_WALLET - 1);
        assertFalse(wlUsed);
    }

    function test_GetWalletInfo_AfterWhitelistMint() public {
        _activateWhitelistMint();

        vm.prank(user1);
        nft.whitelistMint{value: WL_PRICE}(proofUser1);

        (, , bool wlUsed) = nft.getWalletInfo(user1);
        assertTrue(wlUsed);
    }

    function test_RemainingSupply() public {
        assertEq(nft.remainingSupply(), MAX_SUPPLY);

        nft.ownerMint(owner, 2);

        assertEq(nft.remainingSupply(), MAX_SUPPLY - 2);
    }

    // =============================================================
    //                    EDGE CASE TESTS
    // =============================================================

    function test_EdgeCase_BothPhasesMintSimultaneously() public {
        _activatePublicMint();
        _activateWhitelistMint();

        // user1 whitelist mint
        vm.prank(user1);
        nft.whitelistMint{value: WL_PRICE}(proofUser1);

        // user2 public mint
        vm.prank(user2);
        nft.publicMint{value: MINT_PRICE}(1);

        assertEq(nft.totalSupply(), 2);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user2);
    }

    function test_EdgeCase_WhitelistUserCanAlsoPublicMint() public {
        // user1 sudah whitelist mint
        _activateWhitelistMint();
        vm.prank(user1);
        nft.whitelistMint{value: WL_PRICE}(proofUser1);

        // user1 juga bisa public mint (terpisah)
        _activatePublicMint();
        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(1);

        assertEq(nft.balanceOf(user1), 2);
    }

    function test_EdgeCase_ExactSupplyMint() public {
        _activatePublicMint();

        // Mint tepat MAX_SUPPLY token
        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        vm.prank(user2);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        nft.ownerMint(owner, 1);

        assertEq(nft.totalSupply(), MAX_SUPPLY);
        assertEq(nft.remainingSupply(), 0);
    }

    function test_EdgeCase_OwnerOf_AfterTransfer() public {
        nft.ownerMint(user1, 1);

        // user1 transfer ke user2
        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);

        // publicMintCount tidak berubah saat transfer
        // Transfer bukan mint — count hanya track mint
    }

    // =============================================================
    //                      GAS REPORT
    // =============================================================

    function test_Gas_PublicMint_One() public {
        _activatePublicMint();

        vm.prank(user1);
        uint256 before = gasleft();
        nft.publicMint{value: MINT_PRICE}(1);
        uint256 gasUsed = before - gasleft();

        console.log("Gas publicMint(1):", gasUsed);
    }

    function test_Gas_PublicMint_Two() public {
        _activatePublicMint();

        vm.prank(user1);
        uint256 before = gasleft();
        nft.publicMint{value: MINT_PRICE * 2}(2);
        uint256 gasUsed = before - gasleft();

        console.log("Gas publicMint(2):", gasUsed);
    }

    function test_Gas_WhitelistMint() public {
        _activateWhitelistMint();

        vm.prank(user1);
        uint256 before = gasleft();
        nft.whitelistMint{value: WL_PRICE}(proofUser1);
        uint256 gasUsed = before - gasleft();

        console.log("Gas whitelistMint:", gasUsed);
    }

    function test_Gas_Withdraw() public {
        _publicMintFor(user1, 2);

        uint256 before  = gasleft();
        nft.withdraw();
        uint256 gasUsed = before - gasleft();

        console.log("Gas withdraw:", gasUsed);
    }
}