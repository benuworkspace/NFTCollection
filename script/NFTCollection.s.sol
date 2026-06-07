// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Merkle} from "../lib/murky/src/Merkle.sol";

/// @title GenerateMerkle
/// @notice Script untuk generate Merkle root dari whitelist addresses
/// @dev Jalankan dengan: forge script script/GenerateMerkle.s.sol
contract GenerateMerkle is Script {

    function run() public {
        Merkle merkleLib = new Merkle();

        // __________ Daftar whitelist addresses __________
        // Ganti dengan address nyata yang ingin kamu whitelist
        // Untuk testing, gunakan address deployer kamu sendiri
        address[] memory whitelist = new address[](3);
        whitelist[0] = vm.envAddress("DEPLOYER_ADDRESS");
        whitelist[1] = 0x000000000000000000000000000000000000dEaD; // placeholder
        whitelist[2] = 0x000000000000000000000000000000000000bEEF; // placeholder

        // __________ Generate leaves __________
        bytes32[] memory leaves = new bytes32[](whitelist.length);
        for (uint256 i = 0; i < whitelist.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelist[i]));
        }

        // __________ Generate root __________
        bytes32 root = merkleLib.getRoot(leaves);

        // __________ Generate proofs untuk setiap address __________
        console.log("==================================================================");
        console.log("                     MERKLE TREE GENERATION("                     ");
        console.log("==================================================================");
        console.log("Whitelist addresses:");
        for (uint256 i = 0; i < whitelist.length; i++) {
            console.log(i, ":", whitelist[i]);
        }
        console.log("------------------------------------------------------------------");
        console.log("             Merkle Root (save this for deployment):              ");
        console.logBytes32(root);
        console.log("------------------------------------------------------------------");
        console.log("          Proofs (save these for each whitelisted user):          ");

        for (uint256 i = 0; i < whitelist.length; i++) {
            bytes32[] memory proof = merkleLib.getProof(leaves, i);
            console.log("Proof for", whitelist[i], ":");
            for (uint256 j = 0; j < proof.length; j++) {
                console.logBytes32(proof[j]);
            }
            console.log("------------------------------------------------------------------");
        }
        console.log("==================================================================");
    }
}