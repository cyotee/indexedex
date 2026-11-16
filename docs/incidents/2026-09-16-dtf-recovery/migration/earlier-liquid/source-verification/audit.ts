import { Interface, Transaction, getBytes, keccak256 } from "ethers";
import { z } from "zod";
import { readFile, readdir, stat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { ExecutionError, receipt } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";

const root = dirname(fileURLToPath(import.meta.url));
const producer = resolve(root, "../source");
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
const sha = (bytes: Uint8Array | string) => createHash("sha256").update(bytes).digest("hex");
const check = (ok: boolean, message: string) => {
  if (!ok) throw new ExecutionError("STATE", message);
};
const binding = z.object({ path: z.string(), bytes: z.number(), sha256: z.string(), mode: z.string().optional() });
const seal = z.object({ inputs: z.array(binding), members: z.array(binding) }).passthrough()
  .parse(await json(join(producer, "seal.json")));
const preserved = [];
for (const expected of [...seal.inputs, ...seal.members]) {
  const bytes = await readFile(expected.path);
  const mode = ((await stat(expected.path)).mode & 0o777).toString(8);
  check(bytes.length === expected.bytes && sha(bytes) === expected.sha256
    && (expected.mode === undefined || expected.mode === mode), `binding changed: ${expected.path}`);
  preserved.push({ ...expected, mode });
}
const memberPaths = new Set(seal.members.map((e) => e.path));
const visit = async (directory: string): Promise<string[]> => {
  const found = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, item.name);
    if (item.isDirectory()) found.push(...await visit(path));
    else found.push(path);
  }
  return found;
};
const actualMembers = (await visit(producer)).filter((p) => p !== join(producer, "seal.json"));
check(actualMembers.length === memberPaths.size && actualMembers.every((p) => memberPaths.has(p)), "producer membership changed");
const archivePath = seal.inputs.find((v) => v.path.endsWith("probe-alchemy-retry.source.json"))?.path;
if (!archivePath) throw new ExecutionError("STATE", "archive input missing");
const legacy = z.object({
  contracts: z.record(z.string(), z.object({
    observedCode: hex, codeHash: hex, onchainBytecode: hex.optional(), recompiledBytecode: hex.optional(),
    runtimeMatch: z.string().optional(), abi: z.array(z.unknown()).optional(),
    sources: z.record(z.string(), z.object({ content: z.string() }).passthrough()).optional(),
  }).passthrough()),
}).passthrough().parse(await json(archivePath));
const sourceEvidence = z.object({
  excerpts: z.array(z.object({ file: z.string(), ranges: z.array(z.object({
    first: z.number(), last: z.number(), content: z.string(),
  })) })),
}).passthrough().parse(await json(join(producer, "source-evidence.json")));
const excerpts = [];
for (const group of sourceEvidence.excerpts) {
  const entry = Object.values(legacy.contracts).find((c) => c.sources?.[group.file]);
  const content = entry?.sources?.[group.file]?.content;
  if (!content) throw new ExecutionError("STATE", "actual archived source absent");
  for (const range of group.ranges) {
    const actual = content.split("\n").slice(range.first - 1, range.last).join("\n");
    check(actual === range.content, "source excerpt differs");
    excerpts.push({ file: group.file, first: range.first, last: range.last, bytes: Buffer.byteLength(actual), sha256: sha(actual) });
  }
}
const id = z.object({
  original: z.string(), stranger: z.string(), metadata: z.unknown(),
  bindings: z.array(z.object({ facet: z.string(), code: hex, selector: hex, method: z.string() })),
}).passthrough().parse(await json(join(root, "run-01/identity.json")));
const stripCbor = (code: string) => code.slice(0, -(Number.parseInt(code.slice(-4), 16) + 2) * 2);
const runtimes = id.bindings.map((v) => {
  const archived = legacy.contracts[v.facet];
  check(!!archived && archived.observedCode === v.code && keccak256(v.code) === archived.codeHash
    && archived.onchainBytecode === v.code && !!archived.recompiledBytecode
    && stripCbor(archived.recompiledBytecode) === stripCbor(v.code), "legacy runtime/body mismatch");
  return { ...v, bytes: getBytes(v.code).length, sha256: sha(getBytes(v.code)), keccak256: keccak256(v.code),
    runtimeMatch: archived?.runtimeMatch };
});
const artifact = z.object({
  deployedBytecode: z.object({ object: hex, immutableReferences: z.record(z.string(), z.array(z.object({ start: z.number(), length: z.number() }))) }),
  metadata: z.object({ compiler: z.object({ version: z.string() }), sources: z.record(z.string(), z.object({ keccak256: hex }).passthrough()) }).passthrough(),
}).passthrough().parse(await json(join(producer, "artifacts/EdCustodyProbe.sol/EdCustodyProbe.json")));
for (const [path, metadata] of Object.entries(artifact.metadata.sources)) {
  check(keccak256(await readFile(resolve(root, "../../../../../..", path))) === metadata.keccak256, "compiled source differs");
}
const helper = z.object({ helper: z.string(), code: hex }).parse(await json(join(root, "run-01/helper-runtime.json")));
const expectedRuntime = getBytes(artifact.deployedBytecode.object);
const spans = Object.values(artifact.deployedBytecode.immutableReferences).flat();
for (const span of spans) {
  check(span.length === 20, "unexpected immutable length");
  expectedRuntime.set(getBytes(id.original), span.start);
}
check(Buffer.from(expectedRuntime).equals(Buffer.from(getBytes(helper.code))), "full helper runtime differs");
const frame = z.object({
  type: z.string(), from: z.string(), to: z.string().optional(), input: hex,
  output: hex.optional(), error: z.string().optional(), calls: z.array(z.unknown()).default([]),
}).passthrough();
const flatten = (raw: unknown): z.infer<typeof frame>[] => {
  const value = frame.parse(raw);
  return [value, ...value.calls.flatMap(flatten)];
};
const state = z.object({
  accounts: z.array(z.object({ who: z.string(), ed: z.string(), dtf: z.string() })),
  walletAllowance: z.string(), exitAllowance: z.string(), supply: z.string(), nftLp: z.string(),
});
const witness = z.object({
  raw: hex, transactionHash: hex, receipt, rawReceipt: receipt.optional(), trace: z.unknown(),
  before: state, after: state, request: z.object({ target: z.string().optional(), data: hex }),
});
const abi = new Interface([
  "function pull(uint256,bool)", "function transferFrom(address,address,uint256) returns(bool)",
  "function balanceOf(address) view returns(uint256)",
  "function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256)",
  "error LateFailure()", "error WrongWallet()", "error ERC20InsufficientBalance(address,uint256,uint256)",
]);
const operations = [];
for (const name of ["deploy", "unrelated-inventory", "missing-approval", "wrong-wallet", "approve-exact", "partial",
  "late", "terminal", "approve-empty", "missing-balance", "clear"]) {
  const path = join(root, `run-01/${name}.json`);
  const item = witness.parse(await json(path));
  const tx = Transaction.from(item.raw);
  check(keccak256(item.raw) === item.transactionHash && item.receipt.transactionHash === item.transactionHash
    && tx.from?.toLowerCase() === (name === "wrong-wallet" ? id.stranger.toLowerCase() : id.original)
    && tx.chainId === 4663n && tx.to?.toLowerCase() === item.request.target?.toLowerCase()
    && tx.data === item.request.data && item.receipt.from === tx.from?.toLowerCase(), "signed receipt mismatch");
  check(JSON.stringify(item.rawReceipt) === JSON.stringify(item.receipt), "raw receipt fields differ");
  if (BigInt(item.receipt.status) === 0n) check(item.receipt.logs.length === 0
    && JSON.stringify(item.before) === JSON.stringify(item.after), "failed operation altered economics");
  const frames = flatten(item.trace);
  if (name === "partial" || name === "terminal" || name === "late") {
    const q = z.bigint().parse(abi.decodeFunctionData("pull", tx.data)[0]);
    const pulls = frames.filter((v) => v.type === "CALL" && v.input.startsWith("0x23b872dd"));
    check(pulls.length === 1, "missing exact source pull");
    const pull = pulls[0];
    if (!pull) throw new ExecutionError("STATE", "pull absent");
    check(pull.from === helper.helper && pull.to === "0xaf0e1967c8f755c747615c5427108bc549ca1122"
      && pull.input === abi.encodeFunctionData("transferFrom", [id.original, helper.helper, q])
      && pull.output === abi.encodeFunctionResult("transferFrom", [true]) && !pull.error, "pull caller/calldata/return differs");
    if (name === "late") {
      const reads = frames.filter((v) => v.type === "STATICCALL" && v.input.startsWith("0x70a08231"));
      check(reads.length === 4 && reads[0]?.output !== undefined && reads[1]?.output !== undefined
        && reads[2]?.output !== undefined && reads[3]?.output !== undefined, "late balance reads absent");
      check(BigInt(reads[0]?.output ?? "0") - BigInt(reads[2]?.output ?? "0") === 1n
        && BigInt(reads[3]?.output ?? "0") - BigInt(reads[1]?.output ?? "0") === 1n
        && frame.parse(item.trace).output === abi.encodeErrorResult("LateFailure", []), "not late-after-exact-pull");
    } else {
      const before = item.before.accounts.find((a) => a.who === id.original);
      const after = item.after.accounts.find((a) => a.who === id.original);
      const custodyBefore = item.before.accounts.find((a) => a.who === helper.helper);
      const custodyAfter = item.after.accounts.find((a) => a.who === helper.helper);
      check(!!before && !!after && !!custodyBefore && !!custodyAfter
        && BigInt(before.ed) - BigInt(after.ed) === q && BigInt(custodyAfter.ed) - BigInt(custodyBefore.ed) === q
        && BigInt(item.before.walletAllowance) - BigInt(item.after.walletAllowance) === q, "committed deltas differ");
      check(item.before.supply === item.after.supply && item.before.nftLp === item.after.nftLp
        && item.before.accounts.every((a) => {
          const b = item.after.accounts.find((v) => v.who === a.who);
          return !!b && a.dtf === b.dtf && ([id.original, helper.helper].includes(a.who) || a.ed === b.ed);
        }), "unrelated inventory changed");
    }
  }
  if (name === "wrong-wallet") check(frame.parse(item.trace).output === abi.encodeErrorResult("WrongWallet", [])
    && !frames.some((v) => v.input.startsWith("0x23b872dd")), "wrong wallet reached source pull");
  if (name === "missing-balance") check(frame.parse(item.trace).output === abi.encodeErrorResult("ERC20InsufficientBalance", [id.original, 0n, 1n])
    && item.after.walletAllowance === "1", "missing control not proved");
  operations.push({ name, transactionHash: item.transactionHash, status: item.receipt.status,
    bytes: (await readFile(path)).length, sha256: sha(await readFile(path)),
    receiptBytes: Buffer.byteLength(JSON.stringify(item.rawReceipt)), receiptSha256: sha(JSON.stringify(item.rawReceipt)),
    traceBytes: Buffer.byteLength(JSON.stringify(item.trace)), traceSha256: sha(JSON.stringify(item.trace)) });
}
const exit = witness.parse(await json(join(producer, "run-02/exit-attempt.json")));
const frames = flatten(exit.trace);
const exchange = frames.find((f) => f.type === "CALL" && f.to === "0xaf0e1967c8f755c747615c5427108bc549ca1122"
  && f.input.startsWith("0xd02d3063"));
const disabled = frames.find((f) => f.type === "STATICCALL" && f.input.startsWith("0x4f6c171d"));
check(!!exchange && !!disabled && disabled.output === `0x${"0".repeat(63)}1`
  && frame.parse(exit.trace).output === "0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7"
  && exit.receipt.status === "0x0" && exit.receipt.logs.length === 0
  && JSON.stringify(exit.before) === JSON.stringify(exit.after)
  && keccak256(exit.raw) === exit.transactionHash && Transaction.from(exit.raw).chainId === 4663n, "blocked exit evidence differs");
await save(join(root, "audit.json"), {
  preserved, excerpts, runtimes, helper: { ...helper, bytes: getBytes(helper.code).length, sha256: sha(getBytes(helper.code)),
    compiler: artifact.metadata.compiler, immutableSpans: spans }, operations,
  blockedExit: { transactionHash: exit.transactionHash, exchange, disabled, receipt: exit.receipt,
    sourceCondition: "ED self-token input selects primary burn and withdrawSingle; downstream registry returns disabled for ES.",
    successReturnDecoded: false, replayed: false },
  qualifications: "Raw file SHA-256 and JSON-serialized receipt/trace SHA-256, not original HTTP transport bytes. No legacy rebuild.",
});
