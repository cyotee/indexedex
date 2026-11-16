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
import { readReference } from "./provenance.js";
import { parseCandidateCsv, field } from "./candidate-input.js";
import type { authorityInput } from "./bundle.js";
import type { FileRef } from "./schema.js";

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
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18567", "18568", "18569", "18571", "18573", "18575"].includes(chain.endpoint.port)) {
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

/** Acquire only synthetic setup capital from the declared contained transfer census. */
export async function acquireSetupFunding(context: {
  readonly chain: RehearsalChain; readonly evidence: string;
  readonly authorities: Pick<z.infer<typeof authorityInput>, "sources" | "rehearsalFundingEvidence">; readonly reference: FileRef;
}) {
  const { chain, evidence, authorities, reference } = context;
  const source = authorities.rehearsalFundingEvidence;
  if (!source) throw new ExecutionError("DOMAIN", "rehearsal requires declared funding transfer evidence");
  const raw = await readReference(source, reference);
  const rows = parseCandidateCsv(raw.toString("utf8"), source.path)
    .filter((row) => field(row, "asset").toLowerCase() === LEGACY.dtf);
  if (!rows.length) throw new ExecutionError("DOMAIN", "declared transfer census has no original DTF");
  const candidates = [...new Set(rows.flatMap((row) => [field(row, "from"), field(row, "to")])
    .map((who) => who.toLowerCase()).filter((who) => who !== `0x${"0".repeat(40)}`)
    .map((who) => address.parse(who)))].sort();
  const excluded = new Map<string, string>();
  // The authority address superset also excludes delegated facets and recovery
  // actors. This conservative extra exclusion never establishes eligibility.
  for (const authority of authorities.sources) {
    const bytes = await readReference(authority, reference);
    for (const match of bytes.toString("utf8").matchAll(/0x[0-9a-fA-F]{40}(?![0-9a-fA-F])/g)) {
      excluded.set(match[0].toLowerCase(), `authority-address-superset:${authority.id}`);
    }
  }
  for (const who of [...Object.values(LEGACY), DEV,
    "0xec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8", "0xc379feb4182211abe71a34858265e4bf5ff35e06",
    "0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed", "0x76b60dcf71da2294f8aa034432d925d1eed8cf68",
    "0x082cb14f04d9c485473dedc00d604d7e9abca303", "0x11c17f25e958e4637dd26ca362adeae12e24ed5b",
    "0x2e9c1f705ab967c5af59249203d7495bdabb223b", "0x999dae02d22e5fee1c4508430d5196d31d631009",
    "0xb7d4bb379d361ad442cddee53ea71a33957826a7", "0x20af9a1e21a59a411cd3b0c40e70af9084770b2e"]) {
    excluded.set(who, "admitted source, configured historical wallet, or recovery custody");
  }
  // All fixture-derived recipients, source-acquisition wallets, and hostile actors.
  for (let index = 100; index <= 260; index++) excluded.set(HDNodeWallet.fromPhrase(
    "test test test test test test test test test test test junk", undefined, `m/44'/60'/0'/0/${index}`
  ).address.toLowerCase(), `synthetic-local fixture wallet:${index}`);
  const pin = "0x67e5d17";
  const header = z.object({ hash: z.string() }).passthrough().parse(
    await chain.send("eth_getBlockByNumber", [pin, false]));
  if (header.hash !== "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733"
    || BigInt(quantity.parse(await chain.send("eth_chainId", []))) !== 4663n) {
    throw new ExecutionError("DOMAIN", "funding chain or pinned header differs");
  }
  const token = new Interface([...legacyAbi.fragments, "function decimals() view returns(uint8)",
    "function symbol() view returns(string)", "function positionOf(uint256) view returns((uint256,uint256,uint256,uint256,uint256))"]);
  const code = hex.parse(await chain.send("eth_getCode", [LEGACY.dtf, pin]));
  const decimals = token.decodeFunctionResult("decimals", hex.parse(await chain.send("eth_call",
    [{ to: LEGACY.dtf, data: token.encodeFunctionData("decimals") }, pin])))[0];
  if (code === "0x" || decimals !== 18n) throw new ExecutionError("DOMAIN", "original DTF identity or native18 units differ");
  const nftWallet = address.parse((await chain.call(LEGACY.weighted, legacyAbi, "ownerOf", ["3"]))[0]);
  excluded.set(nftWallet, "NFT three historical holder");
  const nftBefore = (await chain.call(LEGACY.weighted, token, "positionOf", ["3"])).toString();
  const observations = [];
  const budget = 10000n * 10n ** 18n;
  let selected: string | undefined;
  for (const holder of candidates) {
    const reason = excluded.get(holder);
    if (reason) { observations.push({ holder, excluded: reason }); continue; }
    const request = { method: "eth_call", params: [{ to: LEGACY.dtf, data: token.encodeFunctionData("balanceOf", [holder]) }, pin] };
    const returned = hex.parse(await chain.send(request.method, request.params));
    const balance = z.bigint().parse(token.decodeFunctionResult("balanceOf", returned)[0]);
    observations.push({ holder, request, returned, balance: String(balance), coversBudget: balance >= budget });
    if (balance >= budget) { selected = holder; break; }
  }
  await save(join(evidence, "setup-funding-selection.json"), { purpose: "synthetic-local", source,
    chainId: "4663", header, token: LEGACY.dtf, code, codeHash: keccak256(code), decimals: String(decimals),
    budget: String(budget), candidates, exclusions: [...excluded].sort(([a], [b]) => a.localeCompare(b)),
    observations, selected: selected ?? null, compensationExcluded: true, financialApproval: false });
  if (!selected) throw new ExecutionError("STATE", "no eligible witnessed setup donor covers the exact budget");
  const before = await chain.call(LEGACY.dtf, token, "balanceOf", [selected]);
  const devBefore = await chain.call(LEGACY.dtf, token, "balanceOf", [DEV]);
  await chain.fundGas(selected);
  await chain.send("anvil_impersonateAccount", [selected]);
  let receipt;
  try { receipt = await chain.transact(LEGACY.dtf, { from: selected, data: token.encodeFunctionData("transfer", [DEV, budget]) }); }
  finally { await chain.send("anvil_stopImpersonatingAccount", [selected]); }
  const after = await chain.call(LEGACY.dtf, token, "balanceOf", [selected]);
  const devAfter = await chain.call(LEGACY.dtf, token, "balanceOf", [DEV]);
  if (z.bigint().parse(before[0]) - z.bigint().parse(after[0]) !== budget
    || z.bigint().parse(devAfter[0]) - z.bigint().parse(devBefore[0]) !== budget
    || (await chain.call(LEGACY.weighted, token, "positionOf", ["3"])).toString() !== nftBefore
    || address.parse((await chain.call(LEGACY.weighted, legacyAbi, "ownerOf", ["3"]))[0]) !== nftWallet) {
    throw new ExecutionError("STATE", "setup funding delta or untouched NFT three principal differs");
  }
  await save(join(evidence, "setup-funding-transfer.json"), { purpose: "synthetic-local", selected, receipt,
    donorBefore: String(before[0]), donorAfter: String(after[0]), devBefore: String(devBefore[0]), devAfter: String(devAfter[0]),
    budget: String(budget), nftWallet, nftBefore, compensationExcluded: true, publicFunderApproved: false });
  return selected;
}
