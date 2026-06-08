# WhitelistMint Debugging Notes

## Ringkasan Masalah

Debug dimulai saat mencoba melakukan `whitelistMint` pada kontrak yang telah dideploy di Sepolia.

Permasalahan yang ditemui:

1. `cast` CLI tidak bisa parse argumen karena variabel shell belum ter-set.
2. `cast abi-encode` dan `cast calldata` gagal karena format `bytes32[]` dan quoting yang tidak tepat saat dipanggil dari shell.
3. Saat menggunakan `ethers` via Node.js, script awal error karena `ethers` versi 6 memiliki API berbeda dari contoh v5.
4. Setelah `whitelistMint` dipanggil kembali, transaksi revert kembali karena kondisi kontrak:
   - `whitelistMintActive` awalnya `false`
   - Arsitektur whitelist menggunakan `Merkle root`
   - Proof yang digunakan tidak valid untuk address caller

## Diagnosa

### 1. Variabel shell kosong

Perintah berikut gagal karena `$CONTRACT_ADDRESS` dan `$NEW_ROOT` belum di-export:

```bash
cast send $CONTRACT_ADDRESS "setMerkleRoot(bytes32)" $NEW_ROOT --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

Perbaikan:

```bash
export CONTRACT_ADDRESS=0xadF5c838C89dc587bCc2A6C7D146159D660a0B06
export NEW_ROOT=0x03cc8ffd336ddb79c60daec4d4a9e70515909c1fdc33eacccde4b6d6829f718d
```

### 2. `cast` dan array `bytes32[]`

Perintah `cast abi-encode` mengembalikan error parser ketika argumen array tidak dikutip dengan benar.
Solusi terbaik adalah mem-bypass `cast` untuk pembuatan proof dengan cara yang lebih langsung menggunakan `forge` atau script yang menghasilkan proof.

### 3. Ethers v6 API berbeda

Di `script/sendWhitelist.js`, kode awal mencoba akses `contract.estimateGas.whitelistMint(...)`.
Di `ethers` versi 6, properti ini tidak tersedia dengan cara yang sama, sehingga script gagal sebelum tujuan utama tercapai.

### 4. Revert karena `InvalidMerkleProof`

Setelah `whitelistMintActive` di-`toggle` menjadi `true`, transaksi masih revert dengan selector `0xb05e92fa`, yang menandakan custom error `InvalidMerkleProof()`.
Artinya proof yang digunakan tidak sesuai dengan address caller.

## Solusi yang Dilakukan

### 1. Aktifkan fase whitelist

Sebagai deployer, phase whitelist diaktifkan dengan:

```bash
cast send $CONTRACT_ADDRESS "toggleWhitelistMint()" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

### 2. Regenerasi Merkle root

Karena whitelist dibuat dengan Merkle tree, untuk menambahkan alamat baru kita tidak bisa update satu address di on-chain secara langsung.
Kita perlu membangun ulang Merkle tree dengan daftar whitelist yang sudah diperbarui dan memanggil `setMerkleRoot(newRoot)`.

Contoh pembaruan di `script/GenerateMerkle.s.sol`:

```solidity
address[] memory whitelist = new address[](4);
whitelist[0] = vm.envAddress("DEPLOYER_ADDRESS");
whitelist[1] = 0xDb6e602b5b90100f5a149398abf2daFBBd1D0386; // alamat deployer / baru
whitelist[2] = 0x000000000000000000000000000000000000dEaD;
whitelist[3] = 0x000000000000000000000000000000000000bEEF;
```

### 3. Set Merkle root baru ke kontrak

```bash
cast send $CONTRACT_ADDRESS "setMerkleRoot(bytes32)" $NEW_ROOT --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

### 4. Verifikasi on-chain

```bash
cast call $CONTRACT_ADDRESS "merkleRoot()" --rpc-url $SEPOLIA_RPC_URL
cast call $CONTRACT_ADDRESS "whitelistMintActive()" --rpc-url $SEPOLIA_RPC_URL
```

### 5. Lakukan whitelist mint dengan proof yang benar

Gunakan proof yang dihasilkan dari `GenerateMerkle.s.sol` untuk address kamu, lalu panggil:

```bash
cast send $CONTRACT_ADDRESS "whitelistMint(bytes32[])" '["0x...","0x..."]' --private-key $PRIVATE_KEY --value 0.005ether --rpc-url $SEPOLIA_RPC_URL
```

## Catatan Penting

- `Merkle root` adalah representasi dari seluruh daftar whitelist. Mengubah daftar berarti harus membuat root baru.
- Proof harus cocok dengan `keccak256(abi.encodePacked(address))` dari alamat pemanggil.
- `whitelistMintActive` harus `true` sebelum mint dijalankan.
- `cast` sensitif terhadap quoting shell ketika memanggil array, jadi gunakan format yang tepat atau script bantu.

## Hasil Akhir

- `merkleRoot` berhasil di-update di Sepolia.
- `whitelistMintActive` sudah aktif.
- Langkah berikutnya adalah menggunakan proof yang benar untuk `whitelistMint` pada address yang ditambahkan.
