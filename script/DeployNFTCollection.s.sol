// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {NFTCollection} from "../src/NFTCollection.sol";

/// @title DeployNFTCollection
/// @notice Script untuk deploy NFTCollection ke network
/// @dev Jalankan setelah generate Merkle root via GenerateMerkle.s.sol
///
/// Required env vars:
///   PRIVATE_KEY          - deployer private key
///   HIDDEN_METADATA_URI  - IPFS URI untuk hidden metadata
///   MERKLE_ROOT          - bytes32 Merkle root dari whitelist
///
contract DeployNFTCollection is Script {

    function run() public returns (NFTCollection nft) {

        // _______________ Load environment _______________
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer           = vm.addr(deployerPrivateKey);

        // Hidden metadata URI dari IPFS (Bagian 2)
        string memory hiddenMetadataURI = vm.envString("HIDDEN_METADATA_URI");

        // Merkle root yang di-generate dari GenerateMerkle.s.sol
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");

        // _______________ Pre-deploy logging _______________
        console.log("===================================================================");
        console.log("                      Deploying NFTCollection                      ");
        console.log("===================================================================");
        console.log("Deployer          :", deployer);
        console.log("Hidden URI        :", hiddenMetadataURI);
        console.log("Merkle Root       :" );
        console.logBytes32(merkleRoot);
        console.log("Max Supply        : 5");
        console.log("Mint Price        : 0.01 ETH");
        console.log("Whitelist Price   : 0.005 ETH");
        console.log("Network Chain ID  :", block.chainid);
        console.log("===================================================================");

        // _______________ Deploy _______________
        vm.startBroadcast(deployerPrivateKey);

        nft = new NFTCollection(hiddenMetadataURI, merkleRoot);

        vm.stopBroadcast();

        // _______________ Post-deploy logging _______________
        console.log("===================================================================");
        console.log("                        Deploy Successful!!                        ");
        console.log("===================================================================");
        console.log("Contract Address  :", address(nft));
        console.log("Name              :", nft.name());
        console.log("Symbol            :", nft.symbol());
        console.log("Max Supply        :", nft.MAX_SUPPLY());
        console.log("Mint Price        :", nft.mintPrice());
        console.log("Whitelist Price   :", nft.whitelistMintPrice());
        console.log("Revealed          :", nft.revealed());
        console.log("Public Mint Active:", nft.publicMintActive());
        console.log("WL Mint Active    :", nft.whitelistMintActive());
        console.log("===================================================================");
        console.log("Etherscan:");
        console.log(
            string(abi.encodePacked(
                "https://sepolia.etherscan.io/address/",
                vm.toString(address(nft))
            ))
        );
        console.log("===================================================================");
        console.log("Next steps:");
        console.log("1. Verify contract on Etherscan");
        console.log("2. Toggle whitelist mint via Etherscan Write");
        console.log("3. Test whitelist mint with your proof");
        console.log("4. Toggle public mint");
        console.log("5. Reveal collection after mint is complete");
        console.log("===================================================================");

        return nft;
    }
}