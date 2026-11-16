import { Interface } from "ethers";

export const stakingSource = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
export const stakingClaim = new Interface([
  "function withdrawClaim(uint256) returns(uint256)",
  "function balanceOf(address) view returns(uint256)",
  "function totalSupply() view returns(uint256)",
  "function phase() view returns(uint8)",
  "function claimVault() view returns(address)",
  "function asset() view returns(address)",
  "function decimals() view returns(uint8)",
  "function facetAddress(bytes4) view returns(address)",
  "function redeem(uint256,address,address) returns(uint256)",
  "event ClaimWithdrawn(address indexed user,uint256 stakeAmount,uint256 claimOut)",
  "event Transfer(address indexed from,address indexed to,uint256 value)",
  "event Withdraw(address indexed sender,address indexed receiver,address indexed owner,uint256 assets,uint256 shares)",
]);
export const proxyHash = "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601";
// Actual read delegation observed on the fixed 4663 sources, not caller-selected facets.
export const claimBookFacets = {
  [stakingSource]: "0x9c90d4a476f3473b9a0e32b530af3474271a80b1",
  "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0": "0x1d17aca0e0717d90cea916372070a1be4652223f",
  "0xb55604cf4dcdabb362078e106d20f98512391edf": "0x4b6e65cfc9a16aae0dfa4257a680f4697275e5fc",
} as const;
export const claimBookRuntimeHashes = {
  "0x9c90d4a476f3473b9a0e32b530af3474271a80b1": "0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742",
  "0x1d17aca0e0717d90cea916372070a1be4652223f": "0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50",
  "0x4b6e65cfc9a16aae0dfa4257a680f4697275e5fc": "0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d",
} as const;
export const routes = [
  [stakingSource, "0xa224dcb7", "0x9c90d4a476f3473b9a0e32b530af3474271a80b1",
    "0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742"],
  ["0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0", "0xba087652", "0x517234f78a4bcafc5f880024a3e45d49cf43b305",
    "0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f"],
  ["0xb55604cf4dcdabb362078e106d20f98512391edf", "0xa9059cbb", "0x4b6e65cfc9a16aae0dfa4257a680f4697275e5fc",
    "0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d"],
] as const;
