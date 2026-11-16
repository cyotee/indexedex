import { join } from "node:path";
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { Interface, keccak256, zeroPadValue } from "ethers";
import { z } from "zod";
import { Rpc, check, save, hex, address, abi, T, V, Y, DONOR, call, numberAt, wallet, signed } from "./common.js";
import type { Book } from "./admission.js";

export const probeAbi = new Interface([
  "constructor(address,address,address,address)",
  "function ping()", "function fail()", "function claim(uint256) returns(uint256)",
  "function catchClaim(uint256) returns(bool,bytes)", "function doubleClaim(uint256,uint256)",
  "function claimThenRevert(uint256)", "function approveCustody(uint256)",
  "function take(uint256,bool)", "function fullWallet() view returns(address)",
  "function splitWallet() view returns(address)", "function relayer() view returns(address)",
  "function custody() view returns(address)",
  "function setRejectReceipt(bool)",
  "function onERC721Received(address,address,uint256,bytes) returns(bytes4)",
]);
export async function book(rpc: Rpc, claimant: string, custody: string, tag = "latest"): Promise<Book> {
  const n = (target: string, method: string, args: readonly unknown[] = []) =>
    numberAt(rpc, target, method, args, tag);
  return {
    weight: await n(T, "balanceOf", [claimant]),
    weightSupply: await n(T, "totalSupply"),
    shares: await n(V, "balanceOf", [T]),
    vaultSupply: await n(V, "totalSupply"),
    walletSy: await n(Y, "balanceOf", [claimant]),
    vaultSy: await n(Y, "balanceOf", [V]),
    sySupply: await n(Y, "totalSupply"),
    custodySy: await n(Y, "balanceOf", [custody]),
    allowance: await n(Y, "allowance", [claimant, custody]),
    booked: await n(custody, "booked", [claimant]),
    rewards: await n(T, "rewards", [claimant]),
    donorWeight: await n(T, "balanceOf", [DONOR]),
    relayerSy: await n(Y, "balanceOf", [wallet(0).address]),
    walletShares: await n(V, "balanceOf", [claimant]),
  };
}
export async function identities(rpc: Rpc) {
  const result = [];
  for (const [target, methods] of [
    [T, ["withdrawClaim", "reassign", "balanceOf", "totalSupply", "rewards", "phase", "claimVault"]],
    [V, ["redeem", "balanceOf", "totalSupply", "asset", "decimals"]],
    [Y, ["transfer", "transferFrom", "approve", "allowance", "balanceOf", "totalSupply", "decimals"]],
  ] as const) {
    const code = hex.parse(await rpc.send("eth_getCode", [target, "latest"]));
    check(keccak256(code) === "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601", "proxy runtime");
    const routes = [];
    for (const method of methods) {
      const fn = abi.getFunction(method);
      check(fn, "ABI selector");
      const facet = address.parse(await call(rpc, target, "facetAddress", [fn.selector]));
      const runtime = hex.parse(await rpc.send("eth_getCode", [facet, "latest"]));
      check(runtime !== "0x", "used route absent");
      routes.push({ method, selector: fn.selector, facet, runtime, runtimeHash: keccak256(runtime) });
    }
    result.push({ target, code, codeHash: keccak256(code), routes });
  }
  check(await numberAt(rpc, T, "phase") === 2n && address.parse(await call(rpc, T, "claimVault")) === V
    && address.parse(await call(rpc, V, "asset")) === Y && await numberAt(rpc, V, "decimals") === 19n
    && await numberAt(rpc, Y, "decimals") === 9n, "source phase units backing");
  return result;
}
const artifactSchema = z.object({
  bytecode: z.object({ object: hex }),
  deployedBytecode: z.object({ object: hex, immutableReferences: z.record(z.string(),
    z.array(z.object({ start: z.number(), length: z.number() }))) }),
  metadata: z.unknown(),
}).passthrough();
export async function deploy(rpc: Rpc, name: string, args: readonly string[]) {
  const path = fileURLToPath(new URL(`out/DelegatedSourceProbe.sol/${name}.json`, import.meta.url));
  const bytes = await readFile(path, "utf8");
  const artifact = artifactSchema.parse(JSON.parse(bytes));
  const deployAbi = name === "SourceCustody" ? new Interface(["constructor(address,address)"]) : probeAbi;
  const encoded = deployAbi.encodeDeploy(args);
  const initcode = artifact.bytecode.object + encoded.slice(2);
  const result = await signed(rpc, 0, { data: initcode });
  check(result.receipt.status === "0x1" && result.receipt.contractAddress, "fixture deployment failed");
  const target = result.receipt.contractAddress;
  const runtime = hex.parse(await rpc.send("eth_getCode", [target, "latest"]));
  let expected = artifact.deployedBytecode.object;
  const immutables = [];
  for (const [id, spans] of Object.entries(artifact.deployedBytecode.immutableReferences)) {
    const values = spans.map(({ start, length }) => {
      check(length === 20, "Solar address immutable span must be 20 bytes");
      const value = `0x${runtime.slice(2 + start * 2, 2 + (start + length) * 2)}`;
      check(args.some(arg => zeroPadValue(arg, length).toLowerCase() === value), "immutable not a constructor address");
      expected = expected.slice(0, 2 + start * 2) + value.slice(2) + expected.slice(2 + (start + length) * 2);
      return { start, length, value };
    });
    check(new Set(values.map(v => v.value)).size === 1, "inconsistent immutable spans");
    immutables.push({ id, values });
  }
  check(runtime === expected, "compiled runtime differs outside verified constructor immutables");
  const getters = name === "SourceCustody" ? ["fullWallet", "splitWallet"] : ["fullWallet", "splitWallet", "relayer", "custody"];
  for (const [i, method] of getters.entries()) {
    const actual = address.parse(probeAbi.decodeFunctionResult(method, hex.parse(await rpc.send("eth_call",
      [{ to: target, data: probeAbi.encodeFunctionData(method) }, "latest"])))[0]);
    check(actual === args[i]?.toLowerCase(), "constructor identity getter differs");
  }
  await save(join(rpc.directory, `deployment-${name}.json`), {
    target, args, encoded, initcode, initcodeHash: keccak256(initcode),
    runtime, runtimeHash: keccak256(runtime), artifactPath: path,
    artifactSha256: createHash("sha256").update(bytes).digest("hex"),
    immutables, metadata: artifact.metadata, transactionHash: result.transaction.hash,
  });
  return target;
}
