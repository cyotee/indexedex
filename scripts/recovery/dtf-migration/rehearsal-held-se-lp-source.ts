import { HDNodeWallet, Interface, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { address, heldSeLpSources, hex } from "./schema.js";
import { ExecutionError } from "./execution-schema.js";
import { DEV } from "./execution-rpc.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { save } from "./rehearsal-data.js";

const donor = "0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b";
const collector = "0x20af9a1e21a59a411cd3b0c40e70af9084770b2e";
const collectorFacet = "0xf7a99a0aed1a4252c71c99fdd2a5b3250a41f669";
const tokenFacet = "0x1d17aca0e0717d90cea916372070a1be4652223f";
const protectedTokens = [...heldSeLpSources, "0xb7d4bb379d361ad442cddee53ea71a33957826a7",
  "0xee5576fa1bcaa380e591d01245f406f3f384eb01"] as const;
const abi = new Interface([
  "function owner() view returns(address)", "function facetAddress(bytes4) view returns(address)",
  "function pullFee(address,uint256,address) returns(bool)",
  "function balanceOf(address) view returns(uint256)", "function totalSupply() view returns(uint256)",
  "function transfer(address,uint256) returns(bool)", "function decimals() view returns(uint8)",
]);
const wallet = (index: number) => HDNodeWallet.fromPhrase(
  "test test test test test test test test test test test junk", undefined, `m/44'/60'/0'/0/${index}`);

/** Disposable-fork donor simulation only. Migration and the operator gain no collector authority. */
export async function acquireHeldSeLp(chain: RehearsalChain, evidence: string) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18571", "18573"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "held SE/LP acquisition requires the fixed owned loopback18571");
  }
  const originalWallet = wallet(201).address.toLowerCase();
  const uint = async (source: string, method: string, args: readonly unknown[] = []) =>
    z.bigint().parse((await chain.call(source, abi, method, args))[0]);
  const authority = async () => {
    const owner = address.parse((await chain.call(collector, abi, "owner"))[0]);
    const facet = address.parse((await chain.call(collector, abi, "facetAddress", ["0x45e94ee3"]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [collector, "latest"]));
    const facetCode = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    const ownerCode = hex.parse(await chain.send("eth_getCode", [owner, "latest"]));
    if (owner !== donor || ownerCode !== "0x" || facet !== collectorFacet
      || keccak256(code) !== "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601"
      || keccak256(facetCode) !== "0x7ae5c353c623b635938a7bb3ebc07cb3eda6469b2cd9dbf76c8bed336ff0b5cb") {
      throw new ExecutionError("DOMAIN", "admitted collector EOA-owner/code/routing differs");
    }
    return { owner, ownerCode, collector, code, facet, facetCode };
  };
  const holdings = async () => {
    const values = [];
    for (const source of protectedTokens) values.push({ source,
      collector: String(await uint(source, "balanceOf", [collector])),
      donor: String(await uint(source, "balanceOf", [donor])),
      original: String(await uint(source, "balanceOf", [originalWallet])),
      supply: String(await uint(source, "totalSupply")) });
    return values;
  };
  const beforeAuthority = await authority();
  for (const who of [originalWallet, wallet(202).address.toLowerCase()]) {
    if (await chain.send("eth_getCode", [who, "latest"]) !== "0x") throw new ExecutionError("DOMAIN", "held signer is not an EOA");
    await chain.transact(who, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  }
  const rows = [];
  for (const source of heldSeLpSources) {
    if (await uint(source, "decimals") !== 18n || await uint(source, "balanceOf", [originalWallet]) !== 0n) {
      throw new ExecutionError("DOMAIN", "held fixed-source unit or initial controlled inventory differs");
    }
    const facets = [];
    for (const selector of ["0x23b872dd", "0x095ea7b3", "0xa9059cbb", "0x70a08231", "0xdd62ed3e"]) {
      const facet = address.parse((await chain.call(source, abi, "facetAddress", [selector]))[0]);
      const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
      if (facet !== tokenFacet || keccak256(code) !== "0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50") {
        throw new ExecutionError("DOMAIN", "held admitted ERC20 routing differs");
      }
      facets.push({ selector, facet, code });
    }
    const before = await holdings();
    const sourceCode = hex.parse(await chain.send("eth_getCode", [source, "latest"]));
    if (keccak256(sourceCode) !== "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601") {
      throw new ExecutionError("DOMAIN", "held source proxy runtime differs");
    }
    const sourceOwner = source === heldSeLpSources[0] ? null
      : address.parse((await chain.call(source, abi, "owner"))[0]);
    const expectedOwner = source === heldSeLpSources[1]
      ? "0xaf0e1967c8f755c747615c5427108bc549ca1122" : "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
    if (sourceOwner !== null && (sourceOwner !== expectedOwner
      || await chain.send("eth_getCode", [sourceOwner, "latest"]) === "0x")) {
      throw new ExecutionError("DOMAIN", "physical LP owner is not the authenticated legacy contract");
    }
    const units = 10020n;
    const collectorBefore = await uint(source, "balanceOf", [collector]);
    const ownerBefore = await uint(source, "balanceOf", [donor]);
    let release = null;
    await chain.send("anvil_impersonateAccount", [donor]);
    try {
      if (source !== heldSeLpSources[0]) {
        if (collectorBefore < units) throw new ExecutionError("STATE", "qualified LP donor inventory unavailable");
        const mined = await chain.transact(collector, { from: donor,
          data: abi.encodeFunctionData("pullFee", [source, units, donor]) });
        release = { provenance: "impersonated existing EOA collector-owner release to itself; not claimant/Migration authority",
          transaction: await chain.send("eth_getTransactionByHash", [mined.transactionHash]),
          receipt: await chain.send("eth_getTransactionReceipt", [mined.transactionHash]),
          trace: await chain.send("debug_traceTransaction", [mined.transactionHash, { tracer: "callTracer" }]),
          stateDiff: await chain.send("debug_traceTransaction", [mined.transactionHash, { tracer: "prestateTracer", tracerConfig: { diffMode: true } }]) };
        if (await uint(source, "balanceOf", [collector]) !== collectorBefore - units
          || await uint(source, "balanceOf", [donor]) !== ownerBefore + units) {
          throw new ExecutionError("STATE", "qualified LP owner release delta differs");
        }
      }
      const personalBefore = await uint(source, "balanceOf", [donor]);
      const mined = await chain.transact(source, { from: donor, data: abi.encodeFunctionData("transfer", [originalWallet, units]) });
      if (await uint(source, "balanceOf", [donor]) !== personalBefore - units
        || await uint(source, "balanceOf", [originalWallet]) !== units) {
        throw new ExecutionError("STATE", "personal donor transfer delta differs");
      }
      const after = await holdings();
      if (hex.parse(await chain.send("eth_getCode", [source, "latest"])) !== sourceCode
        || (sourceOwner !== null && address.parse((await chain.call(source, abi, "owner"))[0]) !== sourceOwner)) {
        throw new ExecutionError("STATE", "source code or legacy owner changed");
      }
      for (const prior of before) {
        const current = after.find((row) => row.source === prior.source);
        if (!current || current.supply !== prior.supply
          || (prior.source !== source && JSON.stringify(current) !== JSON.stringify(prior))) {
          throw new ExecutionError("STATE", "donor operation changed supply or unrelated holdings");
        }
      }
      rows.push({ source, sourceCode, sourceOwner, originalWallet, units: String(units - 7n), facets, release, before, after,
        donation: { provenance: "impersonated personal-holder transfer; no donor-key/public-consent claim",
          transaction: await chain.send("eth_getTransactionByHash", [mined.transactionHash]),
          receipt: await chain.send("eth_getTransactionReceipt", [mined.transactionHash]),
          trace: await chain.send("debug_traceTransaction", [mined.transactionHash, { tracer: "callTracer" }]) } });
    } finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
  }
  const afterAuthority = await authority();
  if (JSON.stringify(beforeAuthority) !== JSON.stringify(afterAuthority)) throw new ExecutionError("STATE", "donor authority changed");
  await save(join(evidence, "held-se-lp-acquisition.json"), { rows, beforeAuthority, afterAuthority,
    signerDerivations: [201, 202], originalComponents: "synthetic code-proof inputs only; donated holdings are not historical allocations" });
  return rows.map(({ source, originalWallet, units }) => ({ source, originalWallet, units }));
}
