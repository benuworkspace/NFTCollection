require('dotenv').config();
const ethers = require('ethers');

(async () => {
  try {
    const provider = (ethers.providers && ethers.providers.JsonRpcProvider)
      ? new ethers.providers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL)
      : new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);

    const wallet = (ethers.Wallet)
      ? new ethers.Wallet(process.env.PRIVATE_KEY, provider)
      : ethers.Wallet.fromPrivateKey(process.env.PRIVATE_KEY).connect(provider);
    const abi = ["function whitelistMint(bytes32[]) payable"];
    const contract = new ethers.Contract(process.env.CONTRACT_ADDRESS, abi, wallet);

    const proof = [
      "0x5f6174255b44b7ca652c5289d2546de65e4394eb6aa52a40045e01237736d023",
      "0x2584ed8dae197c4c7aae3512da2168b7c49e3384af790aff4463b4187239cc01"
    ];

    console.log('Calling whitelistMint with proof:', proof);

    const parseEther = (ethers.utils && ethers.utils.parseEther) ? ethers.utils.parseEther : ethers.parseEther;
    const tx = await contract.whitelistMint(proof, { value: parseEther('0.005') });
    console.log('txHash:', tx.hash);
    const receipt = await tx.wait();
    console.log('Confirmed in block', receipt.blockNumber);
  } catch (err) {
    console.error('Error:', err.message || err);
    process.exitCode = 1;
  }
})();
