import { AbiCoder, FetchRequest, Interface, JsonRpcProvider, Network, Result, keccak256 } from "ethers";
import { z } from "zod";
import { address, hash, hex, PreparationError, uint } from "./schema.js";
import type { FileRef, PreparationInput } from "./schema.js";
import type { ConfigurationPayload } from "./payloads.js";
import { configurationKinds, nftContributionOriginals } from "./payloads.js";
import { authenticateClaimedSy } from "./claimed-sy.js";
import type { CensusScope } from "./claimed-sy.js";
import { canonical, pointerValue, readBoundFile } from "./provenance.js";
import { canonicalReceipt } from "./execution-rpc.js";
import { rpcLog } from "./execution-schema.js";
import type { Receipt } from "./execution-schema.js";

const preview = new Interface(["function previewOriginalCredit(uint256,uint256) view returns (uint256)"]);
const quantity = z.string().regex(/^0x[0-9a-fA-F]+$/);
const header = z.object({ number: quantity, hash, parentHash: hash }).passthrough();
export type Quote = {
  readonly bookId: string;
  readonly originalEth: string;
  readonly originalDtf: string;
  readonly ethCredit: string;
  readonly dtfCredit: string;
  readonly credit: string;
};
export type QuoteEvidence = {
  readonly book: string;
  readonly bookId: string;
  readonly blockHash: string;
  readonly quotes: readonly Quote[];
};
export const quoteEvidenceSchema = z.object({
  book: hex, bookId: hash, blockHash: hash,
  quotes: z.array(z.object({
    bookId: hash, originalEth: uint, originalDtf: uint, ethCredit: uint, dtfCredit: uint, credit: uint,
  }).strict().readonly()).readonly(),
}).strict().readonly();

export function manualBook(iface: Interface, encoded: string, domain: PreparationInput["domain"]) {
  const output = iface.getFunction("migrationWeightedPricing")?.outputs[0];
  if (!output?.components) throw new PreparationError("INPUT", "missing manual book ABI");
  const decoded: unknown = AbiCoder.defaultAbiCoder().decode([output], encoded)[0];
  if (!(decoded instanceof Result)) throw new PreparationError("DOMAIN", "invalid manual book");
  const values = decoded.toArray();
  const index = output.components.findIndex((p) => p.name === "id");
  if (index < 0) throw new PreparationError("INPUT", "missing manual book ID ABI");
  values[index] = `0x${"0".repeat(64)}`;
  const id = keccak256(AbiCoder.defaultAbiCoder().encode(["string", output],
    ["IndexedEx.manual-weighted-original-credit", values]));
  if (id !== decoded.getValue("id") || String(decoded.getValue("version")) !== "2"
    || String(decoded.getValue("chainId")) !== domain.chainId
    || address.parse(decoded.getValue("consumer")) !== domain.proxy
    || AbiCoder.defaultAbiCoder().encode([output], [decoded]) !== encoded) {
    throw new PreparationError("DOMAIN", "manual book identity/domain mismatch");
  }
  return decoded;
}

async function authenticateBookLoad(input: PreparationInput, provider: Pick<JsonRpcProvider, "send">,
  iface: Interface, bookId: string, setter: Receipt, observation: string, bundle?: FileRef): Promise<void> {
  const source = input.sources.find((s) => s.id === "allocation-abi");
  if (!source) throw new PreparationError("DOMAIN", "overwritten book requires its bound loader ABI and canonical load");
  const artifact = z.object({ abi: z.array(z.unknown()) }).parse(
    JSON.parse((await readBoundFile(source.path, bundle ?? input.bundle)).toString("utf8")));
  const allocation = new Interface(JSON.stringify(artifact.abi));
  const topics = iface.fragments.filter((f) => f.type === "event")
    .map((f) => iface.getEvent(f.format("sighash"))).filter((e) => e?.name.endsWith("Configured")).map((e) => e?.topicHash);
  if (!topics.length) throw new PreparationError("DOMAIN", "overwritten book requires bound configuration events");
  const logs = z.array(rpcLog).parse(await provider.send("eth_getLogs", [{
    address: input.domain.proxy, fromBlock: setter.blockNumber, toBlock: observation, topics: [topics],
  }]));
  for (const txHash of new Set(logs.map((l) => l.transactionHash))) {
    const mined = await canonicalReceipt(provider, txHash);
    if (!mined || BigInt(mined.status) !== 1n || mined.to !== input.domain.proxy
      || BigInt(mined.blockNumber) < BigInt(setter.blockNumber) || BigInt(mined.blockNumber) > BigInt(observation)
      || (mined.blockHash === setter.blockHash && BigInt(mined.transactionIndex) <= BigInt(setter.transactionIndex))) continue;
    const tx = z.object({ hash, to: address, from: address, input: hex, value: quantity, chainId: quantity,
      blockHash: hash, transactionIndex: quantity }).passthrough().parse(await provider.send("eth_getTransactionByHash", [txHash]));
    if (tx.hash !== txHash || tx.to !== input.domain.proxy || tx.from !== mined.from
      || tx.blockHash !== mined.blockHash || tx.transactionIndex !== mined.transactionIndex
      || BigInt(tx.chainId).toString() !== input.domain.chainId) throw new PreparationError("DOMAIN", "book-load canonical transaction differs");
    const call = allocation.parseTransaction({ data: tx.input, value: BigInt(tx.value) });
    if (!call || !call.name.startsWith("configure") || call.fragment.inputs.length !== 2
      || call.fragment.inputs[1]?.type !== "bytes32" || call.args[1] !== bookId) continue;
    const parameter = call.fragment.inputs[0]?.arrayChildren;
    const rows = z.array(z.instanceof(Result)).parse(call.args[0]);
    if (!parameter || !rows.length
      || allocation.encodeFunctionData(call.fragment, [rows, bookId]) !== tx.input) {
      throw new PreparationError("DOMAIN", "book-load calldata is not the complete canonical array and scalar");
    }
    const eventName = call.name === "configureIndependentAllocations" ? "IndependentAllocationConfigured"
      : ["configureNftEntitlements", "configureNftContributionEntitlements"].includes(call.name) ? "NftEntitlementConfigured"
      : call.name === "configureClaimedSyEntitlements" ? "WeightedSyEntitlementConfigured"
      : call.name.slice("configure".length, -1) + "Configured";
    const events = mined.logs.filter((l) => l.address === input.domain.proxy).flatMap((l) => {
      const event = iface.parseLog({ topics: [...l.topics], data: l.data });
      return event?.name.endsWith("Configured") ? [event] : [];
    });
    const separate = call.name === "configureNftContributionEntitlements";
    const expected = rows.map((row) => keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", parameter, ...(separate ? ["bool"] : [])],
      [input.domain.chainId, input.domain.proxy, bookId, row, ...(separate ? [true] : [])])));
    if (events.length !== expected.length || events.some((event, i) =>
      event.name !== eventName || event.args.getValue("configurationId") !== expected[i])) {
      throw new PreparationError("DOMAIN", "book-load ordered configuration preimages differ");
    }
    for (const binding of input.domain.bindings) {
      if (keccak256(hex.parse(await provider.send("eth_getCode", [binding.address, mined.blockNumber]))) !== binding.codeHash) {
        throw new PreparationError("DOMAIN", "book-load executing code differs");
      }
    }
    return;
  }
  throw new PreparationError("DOMAIN", "overwritten book lacks a subsequent canonical accepted configuration");
}

export async function authenticateBooks(input: PreparationInput, provider: Pick<JsonRpcProvider, "send">, iface: Interface, bundle?: FileRef) {
  const books = new Map<string, Result>();
  for (const evidence of input.books) {
    if (books.has(evidence.bookId)) throw new PreparationError("DOMAIN", "duplicate manual book");
    const book = manualBook(iface, evidence.encodedBook, input.domain);
    if (book.getValue("id") !== evidence.bookId) throw new PreparationError("DOMAIN", "manual book identity mismatch");
    const mined = await canonicalReceipt(provider, evidence.setTransactionHash);
    const tx = z.object({ hash, to: address, input: hex, blockHash: hash,
      transactionIndex: quantity }).passthrough().parse(
      await provider.send("eth_getTransactionByHash", [evidence.setTransactionHash]));
    const setter = new Interface([`function setMigrationWeightedPricing(${bookInputs(iface)}) returns(bytes32)`,
      "event MigrationWeightedPricingSet(bytes32 indexed bookId)"]);
    if (!mined || BigInt(mined.status) !== 1n || mined.to !== input.domain.proxy
      || BigInt(mined.blockNumber) < BigInt(input.domain.deploymentBlockNumber)
      || tx.to !== input.domain.proxy || tx.hash !== evidence.setTransactionHash
      || tx.blockHash !== mined.blockHash || tx.transactionIndex !== mined.transactionIndex
      || tx.input !== setter.encodeFunctionData("setMigrationWeightedPricing", [book.getValue("inputs")])) {
      throw new PreparationError("DOMAIN", "manual book setter receipt/calldata mismatch");
    }
    for (const binding of input.domain.bindings) {
      const code = hex.parse(await provider.send("eth_getCode", [binding.address, mined.blockNumber]));
      if (keccak256(code) !== binding.codeHash) throw new PreparationError("DOMAIN", "manual setter executing code differs");
    }
    const events = mined.logs.filter((l) => l.address === input.domain.proxy
      && l.topics[0] === setter.getEvent("MigrationWeightedPricingSet")?.topicHash);
    if (events.length !== 1 || events.some((l) =>
      setter.parseLog({ topics: [...l.topics], data: l.data })?.args[0] !== evidence.bookId)) {
      throw new PreparationError("DOMAIN", "manual book setter event mismatch");
    }
    const tag = `0x${BigInt(evidence.observationBlockNumber).toString(16)}`;
    const before = header.parse(await provider.send("eth_getBlockByNumber", [tag, false]));
    if (before.hash !== evidence.observationBlockHash || BigInt(before.number).toString() !== evidence.observationBlockNumber
      || BigInt(before.number) < BigInt(mined.blockNumber)) throw new PreparationError("DOMAIN", "book observation header mismatch");
    const actual = hex.parse(await provider.send("eth_call", [{
      to: input.domain.proxy, data: iface.encodeFunctionData("migrationWeightedPricing"),
    }, tag]));
    if (actual !== evidence.encodedBook) {
      // An end-of-block B getter cannot attest A. Authenticate A's exact setter
      // and a later successful expected-A load in the canonical transaction order.
      manualBook(iface, actual, input.domain);
      await authenticateBookLoad(input, provider, iface, evidence.bookId, mined, tag, bundle);
    }
    if (header.parse(await provider.send("eth_getBlockByNumber", [tag, false])).hash !== before.hash) {
      throw new PreparationError("DOMAIN", "book observation changed");
    }
    books.set(evidence.bookId, book);
  }
  return books;
}

export function bookInputs(iface: Interface): string {
  const inputs = iface.getFunction("migrationWeightedPricing")?.outputs[0]?.components?.find((p) => p.name === "inputs");
  if (!inputs) throw new PreparationError("INPUT", "missing manual pricing Inputs ABI");
  return inputs.format("full");
}

export async function authenticateDeployment(input: PreparationInput, provider: Pick<JsonRpcProvider, "send">, bundle?: FileRef) {
  const proof = input.domain.deploymentProof;
  const source = input.sources.find((s) => s.id === proof.sourceId);
  if (!source) throw new PreparationError("PROVENANCE", "missing deployment source proof");
  const saved = pointerValue(JSON.parse((await readBoundFile(source.path, bundle ?? input.bundle)).toString("utf8")), proof.pointer);
  const transactionHash = z.object({ transactionHash: hash }).passthrough().parse(saved).transactionHash;
  const mined = await canonicalReceipt(provider, transactionHash);
  const event = new Interface(["event NewVault(address indexed vault,address indexed package,bytes32 vaultFeeIds,bytes32 indexed contentsId,bytes4[] vaultTypes,address[] tokens)"]);
  const registry = input.domain.bindings.find((b) => b.role === "registry")?.address;
  const pkg = input.domain.bindings.find((b) => b.role === "package")?.address;
  if (!mined || canonical(mined) !== canonical(saved) || BigInt(mined.status) !== 1n
    || BigInt(mined.blockNumber).toString() !== input.domain.deploymentBlockNumber
    || mined.blockHash !== input.domain.deploymentBlockHash
    || !mined.logs.some((l) => {
      if (l.address !== registry) return false;
      const parsed = event.parseLog({ topics: [...l.topics], data: l.data });
      return parsed?.name === "NewVault" && String(parsed.args[0]).toLowerCase() === input.domain.proxy
        && String(parsed.args[1]).toLowerCase() === pkg;
    })) throw new PreparationError("DOMAIN", "deployment receipt does not register bound proxy");
}
// No signer is created. Only these explicit eth_* reads are sent by this module.
export async function quoteOriginals(input: PreparationInput, payloads: ConfigurationPayload, bundle?: FileRef,
  acquisition: "quotes" | "evidence" | "historical-evidence" = "quotes"): Promise<QuoteEvidence> {
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
      JSON.parse((await readBoundFile(input.domain.pricingArtifact, bundle ?? input.bundle)).toString("utf8")));
    const iface = new Interface(JSON.stringify(artifact.abi));
    const fragment = iface.getFunction("migrationWeightedPricing");
    const output = fragment?.outputs[0];
    if (!fragment || !output?.components) throw new PreparationError("INPUT", "missing manual pricing ABI");
    const saved = input.books.find((b) => b.bookId === input.domain.bookId);
    if (!saved) throw new PreparationError("DOMAIN", "manual book identity mismatch: evidence missing");
    let encoded: string;
    let census: CensusScope;
    switch (acquisition) {
      case "quotes":
        census = "current";
        encoded = hex.parse(await provider.send("eth_call", [
          { to: input.domain.proxy, data: iface.encodeFunctionData(fragment) }, blockTag,
        ]));
        break;
      case "evidence": census = "current"; encoded = saved.encodedBook; break;
      case "historical-evidence": census = "historical"; encoded = saved.encodedBook; break;
      default: {
        const unreachable: never = acquisition;
        throw new PreparationError("INPUT", unreachable);
      }
    }
    const book = manualBook(iface, encoded, input.domain);
    const id = hash.parse(book.getValue("id"));
    if (id !== input.domain.bookId) throw new PreparationError("DOMAIN", "manual book identity mismatch");
    await authenticateDeployment(input, provider, bundle);
    const books = await authenticateBooks(input, provider, iface, bundle);
    if (!books.has(id)) throw new PreparationError("DOMAIN", "current manual book evidence missing");
    await authenticateClaimedSy(input, provider, { bundle, census });
    if (acquisition !== "quotes") {
      if (header.parse(await provider.send("eth_getBlockByNumber", [blockTag, false])).hash !== before.hash) {
        throw new PreparationError("DOMAIN", "block changed during evidence authentication");
      }
      return { book: encoded, bookId: id, blockHash: before.hash, quotes: [] };
    }
    const originals = [];
    for (const key of configurationKinds) {
      for (const [i, row] of payloads[key].entries()) {
        const directive = input[key][i]?.pricing;
        if (!directive || !books.has(directive.bookId)) throw new PreparationError("DOMAIN", "row manual book evidence missing");
        if (directive.kind === "retain") continue;
        if (directive.bookId !== id) throw new PreparationError("DOMAIN", "load book differs from pinned current book");
        originals.push(...("recipient" in row ? row.entitlements : "collection" in row ? nftContributionOriginals(row) : [row]));
      }
    }
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
      quotes.push({ bookId: id, originalEth: original.originalEth, originalDtf: original.originalDtf, ethCredit, dtfCredit, credit });
    }
    const after = header.parse(await provider.send("eth_getBlockByNumber", [blockTag, false]));
    if (after.hash !== before.hash) throw new PreparationError("DOMAIN", "block changed during reads");
    return { book: encoded, bookId: id, blockHash: before.hash, quotes };
  } catch (error) {
    if (error instanceof PreparationError || error instanceof z.ZodError) throw error;
    // RPC libraries can include private endpoints in errors; retain no resolved URL.
    throw new PreparationError("QUOTE", "read-only RPC/ABI acquisition failed; no payload accepted");
  } finally {
    provider.destroy();
  }
}
