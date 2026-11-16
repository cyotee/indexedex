import { HDNodeWallet, Interface, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { dtfCustodySeSource } from "./payloads.js";
import { address, hash, hex } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { DEV, subscribeReceipt } from "./execution-rpc.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { save } from "./rehearsal-data.js";

// Authenticated deployed RebasingAwareERC4626Facet, not an assumed generic ABI.
// The archive and pinned runtime both hash to the facet identity checked below.
export const custodySeAbi = new Interface([
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
export async function acquireDtfCustodyShares(chain: RehearsalChain, evidence: string) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18567", "18568", "18569", "18571", "18573"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "W-SD acquisition is restricted to the pinned owned local node");
  }
  const wallet = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
    undefined, "m/44'/60'/0'/0/104");
  const originalWallet = wallet.address.toLowerCase();
  if (await chain.send("eth_getCode", [originalWallet, "latest"]) !== "0x") {
    throw new ExecutionError("DOMAIN", "controlled W-SD recipient is not an EOA");
  }
  const proxyHash = keccak256(hex.parse(await chain.send("eth_getCode", [dtfCustodySeSource, "latest"])));
  const facets = [];
  for (const selector of ["0x6e553f65", "0xba087652"]) {
    const facet = address.parse((await chain.call(dtfCustodySeSource, custodySeAbi, "facetAddress", [selector]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    const codeHash = keccak256(code);
    if (facet !== "0xdbceeff98f2388b0efa0c0fda2e08cdd263ce8f5"
      || codeHash !== "0x99b74f701969463d5147a782113b30bef06ef1c65f58902d410849d6d2cef616") {
      throw new ExecutionError("DOMAIN", "W-SD acquisition/redemption facet differs from authenticated source");
    }
    facets.push({ selector, facet, code, codeHash });
  }
  if (proxyHash !== "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601"
    || address.parse((await chain.call(dtfCustodySeSource, custodySeAbi, "asset"))[0]) !== LEGACY.dtf
    || (await chain.call(dtfCustodySeSource, custodySeAbi, "decimals"))[0] !== 28n
    || (await chain.call(LEGACY.dtf, custodySeAbi, "decimals"))[0] !== 18n) {
    throw new ExecutionError("DOMAIN", "W-SD source/asset/native units differ");
  }
  const balance = async (token: string, holder: string) =>
    z.bigint().parse((await chain.call(token, legacyAbi, "balanceOf", [holder]))[0]);
  const payment = 10n ** 18n;
  const beforeFunding = { dtf: String(await balance(LEGACY.dtf, originalWallet)),
    shares: String(await balance(dtfCustodySeSource, originalWallet)) };
  if (beforeFunding.dtf !== "0" || beforeFunding.shares !== "0") {
    throw new ExecutionError("STATE", "controlled acquisition must begin with no DTF or source shares");
  }
  const funding = await chain.transact(LEGACY.dtf, { from: DEV,
    data: legacyAbi.encodeFunctionData("transfer", [originalWallet, payment]) });
  await chain.transact(originalWallet, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  const sourceBefore = await balance(LEGACY.dtf, dtfCustodySeSource);
  const quotedShares = z.bigint().parse((await chain.call(dtfCustodySeSource, custodySeAbi, "previewDeposit", [payment]))[0]);
  const transactions = [];
  for (const request of [
    { to: LEGACY.dtf, data: legacyAbi.encodeFunctionData("approve", [dtfCustodySeSource, payment]) },
    { to: dtfCustodySeSource, data: custodySeAbi.encodeFunctionData("deposit", [payment, originalWallet]) },
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
  const shares = await balance(dtfCustodySeSource, originalWallet);
  const sourceAfter = await balance(LEGACY.dtf, dtfCustodySeSource);
  if (await balance(LEGACY.dtf, originalWallet) !== 0n || sourceAfter - sourceBefore !== payment
    || shares !== quotedShares || shares === 0n) {
    throw new ExecutionError("STATE", "W-SD actual payment/share acquisition differs");
  }
  await save(join(evidence, "dtf-custody-se-acquisition.json"), {
    originalWallet, derivationIndex: 104, source: dtfCustodySeSource, asset: LEGACY.dtf,
    shareDecimals: 28, assetDecimals: 18, proxyHash, facets, beforeFunding,
    fundingTransaction: funding.transactionHash, payment: payment.toString(), shares: shares.toString(),
    sourceBefore: sourceBefore.toString(), sourceAfter: sourceAfter.toString(), transactions,
    purpose: "actual local source acquisition; compensation allocation remains explicitly synthetic",
  });
  return { originalWallet, shares: shares.toString() };
}
