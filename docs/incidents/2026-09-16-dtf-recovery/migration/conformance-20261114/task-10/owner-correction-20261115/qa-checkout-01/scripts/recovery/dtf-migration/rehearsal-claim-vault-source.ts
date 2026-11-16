import { HDNodeWallet, Interface, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { claimVaultSource } from "./payloads.js";
import { address, hash, hex } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { DEV, subscribeReceipt } from "./execution-rpc.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { save } from "./rehearsal-data.js";

// Executed pinned layouts from controlled payment/mint/burn traces, not source equivalence.
export const claimVaultAbi = new Interface([
  "function deposit(uint256 assets,address receiver) returns(uint256 shares)",
  "function redeem(uint256 shares,address receiver,address owner) returns(uint256 assets)",
  "function previewDeposit(uint256 assets) view returns(uint256 shares)",
  "function previewRedeem(uint256 shares) view returns(uint256 assets)",
  "function asset() view returns(address)",
  "function decimals() view returns(uint8)",
  "function facetAddress(bytes4) view returns(address)",
  "event Deposit(address indexed sender,address indexed owner,uint256 assets,uint256 shares)",
  "event Transfer(address indexed from,address indexed to,uint256 amount)",
]);

/** A fresh, signed controlled-wallet acquisition, not a transfer of infrastructure-held shares. */
export async function acquireClaimVaultShares(chain: RehearsalChain, evidence: string) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18567", "18568", "18569", "18571", "18573", "18575"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "claim-vault acquisition is restricted to the pinned owned local node");
  }
  const wallet = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
    undefined, "m/44'/60'/0'/0/105");
  const originalWallet = wallet.address.toLowerCase();
  if (await chain.send("eth_getCode", [originalWallet, "latest"]) !== "0x") {
    throw new ExecutionError("DOMAIN", "controlled claim-vault recipient is not an EOA");
  }
  const proxyHash = keccak256(hex.parse(await chain.send("eth_getCode", [claimVaultSource, "latest"])));
  const facets = [];
  for (const selector of ["0x6e553f65", "0xba087652"]) {
    const facet = address.parse((await chain.call(claimVaultSource, claimVaultAbi, "facetAddress", [selector]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    const codeHash = keccak256(code);
    if (facet !== "0x517234f78a4bcafc5f880024a3e45d49cf43b305"
      || codeHash !== "0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f") {
      throw new ExecutionError("DOMAIN", "claim-vault acquisition/redemption facet differs from executed pinned identity");
    }
    facets.push({ selector, facet, code, codeHash });
  }
  if (proxyHash !== "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601"
    || address.parse((await chain.call(claimVaultSource, claimVaultAbi, "asset"))[0]) !== LEGACY.sy
    || (await chain.call(claimVaultSource, claimVaultAbi, "decimals"))[0] !== 19n
    || (await chain.call(LEGACY.sy, claimVaultAbi, "decimals"))[0] !== 9n) {
    throw new ExecutionError("DOMAIN", "claim-vault source/asset/native units differ");
  }
  const balance = async (token: string, holder: string) =>
    z.bigint().parse((await chain.call(token, legacyAbi, "balanceOf", [holder]))[0]);
  const payment = 3000n;
  const beforeFunding = { dtf: String(await balance(LEGACY.sy, originalWallet)),
    shares: String(await balance(claimVaultSource, originalWallet)) };
  if (beforeFunding.dtf !== "0" || beforeFunding.shares !== "0") {
    throw new ExecutionError("STATE", "controlled acquisition must begin with no SY or source shares");
  }
  const holder = "0x11c17f25e958e4637dd26ca362adeae12e24ed5b";
  await chain.fundGas(holder);
  await chain.send("anvil_impersonateAccount", [holder]);
  let funding;
  try {
    funding = await chain.transact(LEGACY.sy, { from: holder,
      data: legacyAbi.encodeFunctionData("transfer", [originalWallet, payment]) });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [holder]); }
  await chain.transact(originalWallet, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  const sourceBefore = await balance(LEGACY.sy, claimVaultSource);
  const quotedShares = z.bigint().parse((await chain.call(claimVaultSource, claimVaultAbi, "previewDeposit", [payment]))[0]);
  const transactions = [];
  for (const request of [
    { to: LEGACY.sy, data: legacyAbi.encodeFunctionData("approve", [claimVaultSource, payment]) },
    { to: claimVaultSource, data: claimVaultAbi.encodeFunctionData("deposit", [payment, originalWallet]) },
  ]) {
    const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [originalWallet, "pending"]))));
    const gasPrice = BigInt(quantity.parse(await chain.send("eth_gasPrice", [])));
    const raw = await wallet.signTransaction({ ...request, chainId: 4663, nonce, gasLimit: 2000000n, gasPrice, type: 0 });
    const transactionHash = keccak256(raw);
    const watch = await subscribeReceipt(chain, transactionHash);
    try {
      if (hash.parse(await chain.send("eth_sendRawTransaction", [raw])) !== transactionHash) {
        throw new ExecutionError("STATE", "signed acquisition transaction hash differs");
      }
      const mined = await watch.mined();
      if (BigInt(mined.status) !== 1n || mined.from !== originalWallet) {
        throw new ExecutionError("STATE", "controlled-wallet acquisition failed");
      }
      chain.receipts.push(mined);
      transactions.push({ transactionHash, nonce, to: request.to, data: request.data, receipt: mined });
    } finally { watch.close(); }
  }
  const shares = await balance(claimVaultSource, originalWallet);
  const sourceAfter = await balance(LEGACY.sy, claimVaultSource);
  if (await balance(LEGACY.sy, originalWallet) !== 0n || sourceAfter - sourceBefore !== payment
    || shares !== quotedShares || shares === 0n) {
    throw new ExecutionError("STATE", "claim-vault actual payment/share acquisition differs");
  }
  await save(join(evidence, "claim-vault-acquisition.json"), {
    originalWallet, derivationIndex: 105, source: claimVaultSource, asset: LEGACY.sy,
    shareDecimals: 19, assetDecimals: 9, proxyHash, facets, beforeFunding,
    fundingTransaction: funding.transactionHash, payment: payment.toString(), shares: shares.toString(),
    sourceBefore: sourceBefore.toString(), sourceAfter: sourceAfter.toString(), transactions,
    purpose: "actual local source acquisition; compensation allocation remains explicitly synthetic",
  });
  return { originalWallet, shares: shares.toString() };
}
