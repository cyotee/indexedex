import { HDNodeWallet, Interface, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { address, hash, hex } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { DEV, subscribeReceipt } from "./execution-rpc.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { save } from "./rehearsal-data.js";

export const wsSourceAbi = new Interface([
  "function facetAddress(bytes4) view returns(address)",
  "function synchronizeRewards() returns(uint256)",
  "event RewardsFunded(uint256 amount,uint256 stakingGrowth,uint256 feeReceipt,uint256 creatorReceipt,uint256 gonsPerUnit)",
]);
export const wsWallet = (index = 117) => HDNodeWallet.fromPhrase(
  "test test test test test test test test test test test junk", undefined, `m/44'/60'/0'/0/${index}`);

/** Every original-wallet source/compensation operation retains its actual signed bytes and raw receipt. */
export async function signWs(chain: RehearsalChain, evidence: string, request: {
  readonly to: string; readonly data: string; readonly index?: number; readonly status?: bigint;
}) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18567", "18568"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "WS signed fixture requires the fixed owned18567 node");
  }
  const wallet = wsWallet(request.index);
  const signer = wallet.address.toLowerCase();
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [signer, "pending"]))));
  const gasPrice = BigInt(quantity.parse(await chain.send("eth_gasPrice", [])));
  const raw = await wallet.signTransaction({
    to: request.to, data: request.data, chainId: 4663, nonce, gasLimit: 20000000n, gasPrice, type: 0,
  });
  const transactionHash = keccak256(raw);
  const watch = await subscribeReceipt(chain, transactionHash);
  try {
    if (hash.parse(await chain.send("eth_sendRawTransaction", [raw])) !== transactionHash) {
      throw new ExecutionError("STATE", "WS signed transaction identity differs");
    }
    const mined = await watch.mined();
    // Raw RPC receipt is retained in addition to the parsed subset.
    const rawReceipt = await chain.send("eth_getTransactionReceipt", [transactionHash]);
    await save(join(evidence, `ws-signed-${signer}-${nonce}.json`), {
      signer, chainId: "4663", nonce, raw, transactionHash, to: request.to, data: request.data,
      receipt: rawReceipt,
    });
    chain.receipts.push(mined);
    if (BigInt(mined.status) !== (request.status ?? 1n) || mined.from !== signer) {
      throw new ExecutionError("STATE", `WS signed operation status differs: ${transactionHash}`);
    }
    return mined;
  } finally { watch.close(); }
}

/** Actual funded WS acquisition; original historical ETH/DTF allocations remain synthetic inputs. */
export async function acquireWeightedReceipt(chain: RehearsalChain, evidence: string) {
  const originalWallet = wsWallet().address.toLowerCase();
  const proxyCode = hex.parse(await chain.send("eth_getCode", [LEGACY.receipt, "latest"]));
  if (await chain.send("eth_getCode", [originalWallet, "latest"]) !== "0x"
    || keccak256(proxyCode) !== "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601") {
    throw new ExecutionError("DOMAIN", "WS source or controlled signer identity differs");
  }
  const facets = [];
  for (const selector of ["0x23b872dd", "0x79a67521", "0xe082f1d4", "0xd02d3063"]) {
    const facet = address.parse((await chain.call(LEGACY.receipt, wsSourceAbi, "facetAddress", [selector]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    if (facet !== "0xb7581fe833a2b2380dd786b345d61ffb734d36eb"
      || keccak256(code) !== "0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361") {
      throw new ExecutionError("DOMAIN", "WS facet differs from admitted archived runtime");
    }
    facets.push({ selector, facet, code, codeHash: keccak256(code) });
  }
  const gonsBefore = z.bigint().parse((await chain.call(LEGACY.receipt, legacyAbi, "gonsOf", [originalWallet]))[0]);
  if (gonsBefore !== 0n) throw new ExecutionError("STATE", "WS acquisition wallet already owns receipt gons");
  const donor = "0x082cb14f04d9c485473dedc00d604d7e9abca303";
  await chain.send("anvil_setBalance", [donor, "0xde0b6b3a7640000"]);
  await chain.send("anvil_impersonateAccount", [donor]);
  try {
    await chain.transact(LEGACY.detf, { from: donor,
      data: legacyAbi.encodeFunctionData("transfer", [originalWallet, 101]) });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
  for (const signer of [originalWallet, wsWallet(118).address.toLowerCase()]) {
    await chain.transact(signer, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  }
  await signWs(chain, evidence, { to: LEGACY.detf,
    data: legacyAbi.encodeFunctionData("approve", [LEGACY.receipt, 101]) });
  const acquisition = await signWs(chain, evidence, { to: LEGACY.receipt,
    data: legacyAbi.encodeFunctionData("exchangeIn", [LEGACY.detf, 101, LEGACY.receipt, 101,
      originalWallet, false, (await chain.timestamp() + 3600n).toString()]) });
  const gons = z.bigint().parse((await chain.call(LEGACY.receipt, legacyAbi, "gonsOf", [originalWallet]))[0]);
  const state = (await chain.call(LEGACY.receipt, legacyAbi, "stakingState"))[0];
  const divisor = z.bigint().parse(state.gonsPerUnit);
  if (gons !== 101n * divisor) throw new ExecutionError("STATE", "WS acquired principal gons differ from actual operation divisor");
  await save(join(evidence, "weighted-receipt-acquisition.json"), {
    originalWallet, derivationIndex: 117, source: LEGACY.receipt, nativePrincipal: "101",
    originalOperationDivisor: divisor.toString(), eligibleOriginalGons: gons.toString(), facets,
    acquisition: acquisition.transactionHash, originalAllocations: "synthetic; not approved historical amounts",
  });
  return { originalWallet, gons: gons.toString() };
}
