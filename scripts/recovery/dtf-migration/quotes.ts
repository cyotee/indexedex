import { AbiCoder, FetchRequest, Interface, JsonRpcProvider, Network, Result, keccak256 } from "ethers";
import { readFile } from "node:fs/promises";
import { z } from "zod";
import { address, hash, hex, PreparationError, uint } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import type { ConfigurationPayload } from "./payloads.js";

const preview = new Interface(["function previewOriginalCredit(uint256,uint256) view returns (uint256)"]);
const quantity = z.string().regex(/^0x[0-9a-fA-F]+$/);
const header = z.object({ number: quantity, hash, parentHash: hash }).passthrough();
export type Quote = {
  readonly originalEth: string;
  readonly originalDtf: string;
  readonly ethCredit: string;
  readonly dtfCredit: string;
  readonly credit: string;
};
export type QuoteEvidence = {
  readonly snapshot: string;
  readonly snapshotId: string;
  readonly blockHash: string;
  readonly quotes: readonly Quote[];
};

// No signer is created. Only these explicit eth_* reads are sent by this module.
export async function quoteOriginals(input: PreparationInput, payloads: ConfigurationPayload): Promise<QuoteEvidence> {
  const url = process.env[input.domain.rpcEnv];
  if (!url) throw new PreparationError("INPUT", `missing RPC environment variable ${input.domain.rpcEnv}`);
  const endpoint = new URL(url);
  if (!["http:", "https:"].includes(endpoint.protocol)) throw new PreparationError("DOMAIN", "HTTP RPC required");
  if (input.purpose === "synthetic-local"
    && !["localhost", "127.0.0.1", "[::1]"].includes(endpoint.hostname)) {
    throw new PreparationError("DOMAIN", "synthetic inputs require loopback RPC");
  }
  const request = new FetchRequest(url);
  request.timeout = 15000;
  const provider = new JsonRpcProvider(request, new Network("dtf-operator", BigInt(input.domain.chainId)),
    { batchMaxCount: 1, staticNetwork: true });
  try {
    const chain = quantity.parse(await provider.send("eth_chainId", []));
    if (BigInt(chain).toString() !== input.domain.chainId) throw new PreparationError("DOMAIN", "wrong chain");
    const blockTag = `0x${BigInt(input.domain.blockNumber).toString(16)}`;
    const before = header.parse(await provider.send("eth_getBlockByNumber", [blockTag, false]));
    if (before.hash !== input.domain.blockHash || BigInt(before.number).toString() !== input.domain.blockNumber) {
      throw new PreparationError("DOMAIN", "wrong canonical block");
    }
    for (const role of ["proxy", "registry", "package", "facet"] as const) {
      if (!input.domain.bindings.some((b) => b.role === role)) throw new PreparationError("DOMAIN", `missing ${role} binding`);
    }
    const proxies = input.domain.bindings.filter((b) => b.role === "proxy");
    if (proxies.length !== 1 || proxies[0]?.address !== input.domain.proxy) {
      throw new PreparationError("DOMAIN", "wrong proxy binding");
    }
    for (const binding of input.domain.bindings) {
      const code = hex.parse(await provider.send("eth_getCode", [binding.address, blockTag]));
      if (code === "0x" || keccak256(code) !== binding.codeHash) {
        throw new PreparationError("DOMAIN", `wrong ${binding.role} code`);
      }
    }
    const artifact = z.object({ abi: z.array(z.unknown()) }).parse(
      JSON.parse(await readFile(input.domain.snapshotArtifact, "utf8")));
    const iface = new Interface(JSON.stringify(artifact.abi));
    const fragment = iface.getFunction("migrationSnapshot");
    const output = fragment?.outputs[0];
    if (!fragment || !output?.components) throw new PreparationError("INPUT", "missing snapshot ABI");
    const encoded = hex.parse(await provider.send("eth_call", [
      { to: input.domain.proxy, data: iface.encodeFunctionData(fragment) }, blockTag,
    ]));
    const snapshot: unknown = iface.decodeFunctionResult(fragment, encoded)[0];
    if (!(snapshot instanceof Result)) throw new PreparationError("QUOTE", "invalid snapshot tuple");
    const id = hash.parse(snapshot.getValue("id"));
    const values = snapshot.toArray();
    const idIndex = output.components.findIndex((p) => p.name === "id");
    if (idIndex < 0) throw new PreparationError("INPUT", "missing snapshot ID ABI");
    values[idIndex] = `0x${"0".repeat(64)}`;
    const sealed = keccak256(AbiCoder.defaultAbiCoder().encode(["string", output],
      ["IndexedEx.frozen-original-credit", values]));
    const source: unknown = snapshot.getValue("source");
    if (!(source instanceof Result) || sealed !== id || id !== input.domain.snapshotId
      || address.parse(snapshot.getValue("consumer")) !== input.domain.proxy
      || address.parse(source.getValue("subject")) !== input.domain.proxy
      || BigInt(snapshot.getValue("chainId")).toString() !== input.domain.chainId
      || BigInt(snapshot.getValue("version")) !== 1n) {
      throw new PreparationError("DOMAIN", "snapshot identity/source mismatch");
    }
    const originals = [...payloads.independent.flatMap((r) => r.entitlements), ...payloads.nfts, ...payloads.weightedLiquid, ...payloads.weightedSy, ...payloads.dtfCustodySe, ...payloads.claimVault, ...payloads.weightedReceipt];
    const pairs = new Map(originals.map((r) => [`${r.originalEth}:${r.originalDtf}`, r]));
    const quotes: Quote[] = [];
    for (const [, original] of [...pairs].sort(([a], [b]) => a.localeCompare(b))) {
      const evaluate = async (eth: string, dtf: string): Promise<string> => {
        const result = hex.parse(await provider.send("eth_call", [{
          to: input.domain.proxy, data: preview.encodeFunctionData("previewOriginalCredit", [eth, dtf]),
        }, blockTag]));
        const decoded: unknown = preview.decodeFunctionResult("previewOriginalCredit", result)[0];
        return z.bigint().transform((v) => uint.parse(v.toString())).parse(decoded);
      };
      const ethCredit = await evaluate(original.originalEth, "0");
      const dtfCredit = await evaluate("0", original.originalDtf);
      const credit = await evaluate(original.originalEth, original.originalDtf);
      if (BigInt(ethCredit) + BigInt(dtfCredit) !== BigInt(credit)) {
        throw new PreparationError("QUOTE", "independent component quote mismatch");
      }
      quotes.push({ originalEth: original.originalEth, originalDtf: original.originalDtf, ethCredit, dtfCredit, credit });
    }
    const after = header.parse(await provider.send("eth_getBlockByNumber", [blockTag, false]));
    if (after.hash !== before.hash) throw new PreparationError("DOMAIN", "block changed during reads");
    return { snapshot: encoded, snapshotId: id, blockHash: before.hash, quotes };
  } catch (error) {
    if (error instanceof PreparationError || error instanceof z.ZodError) throw error;
    // RPC libraries can include private endpoints in errors; retain no resolved URL.
    throw new PreparationError("QUOTE", "read-only RPC/ABI acquisition failed; no payload accepted");
  } finally {
    provider.destroy();
  }
}
