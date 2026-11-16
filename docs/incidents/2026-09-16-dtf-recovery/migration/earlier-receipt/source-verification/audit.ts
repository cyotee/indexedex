import { readFile, readdir, lstat, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface, Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { ExecutionError } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

const home = dirname(fileURLToPath(import.meta.url)), source = join(home, "../source");
const assert = (ok: boolean, detail: string) => {
  if (!ok) throw new ExecutionError("STATE", detail);
};
const load = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
const digest = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
const seal = z.object({
  inputs: z.array(z.object({ path: z.string(), bytes: z.number(), sha256: z.string() })),
  evidence: z.array(z.object({ path: z.string(), bytes: z.number(), sha256: z.string() })),
}).passthrough().parse(await load(join(source, "seal.json")));
const bindings = [];
for (const member of [...seal.inputs, ...seal.evidence.map(e => ({ ...e, path: join(source, e.path) }))]) {
  const bytes = await readFile(member.path), stat = await lstat(member.path);
  assert(bytes.length === member.bytes && digest(bytes) === member.sha256, `sealed identity ${member.path}`);
  bindings.push({ ...member, mode: stat.mode & 511 });
}
const sealBytes = await readFile(join(source, "seal.json"));
bindings.push({ path: join(source, "seal.json"), bytes: sealBytes.length, sha256: digest(sealBytes),
  mode: (await lstat(join(source, "seal.json"))).mode & 511 });
const num = z.string().regex(/^(0|[1-9][0-9]*)$/).transform(BigInt);
const account = z.object({
  who: z.string(), display: num, external: num,
  internal: num.optional(), diagnosticInternal: num.optional(),
}).transform(a => {
  const internal = a.internal ?? a.diagnosticInternal;
  if (internal === undefined) throw new ExecutionError("STATE", "missing diagnostic oracle");
  return { ...a, internal };
});
const book = z.object({ who: z.string(), Q: num, C: num, B: num, allowance: num,
  paid: num.optional(), delivered: num.optional(),
}).transform(b => ({ ...b, paid: b.paid ?? z.bigint().parse(b.delivered) }));
const state = z.object({
  rate: num, total: num.optional(), totalShares: num.optional(),
  totalInternal: num.optional(), diagnosticTotalInternal: num.optional(),
  accounts: z.array(account), books: z.array(book).optional(), ledgers: z.array(book).optional(),
}).transform(s => {
  const books = s.books ?? s.ledgers;
  if (!books) throw new ExecutionError("STATE", "missing ledgers");
  return { ...s, total: s.total ?? z.bigint().parse(s.totalShares),
    totalInternal: s.totalInternal ?? z.bigint().parse(s.diagnosticTotalInternal), books };
});
const entry = z.object({
  raw: z.string(), before: state, after: state,
  receipt: z.object({ transactionHash: z.string(), from: z.string(), to: z.string().nullable(),
    status: z.string(), logs: z.array(z.object({ address: z.string(), topics: z.array(z.string()), data: z.string() }).passthrough()) }).passthrough(),
  trace: z.unknown(),
});
const trace = z.object({ input: z.string(), to: z.string().optional(), output: z.string().optional(),
  error: z.string().optional(), calls: z.array(z.unknown()).optional() }).passthrough();
const flatten = (raw: unknown): readonly z.infer<typeof trace>[] => {
  const node = trace.parse(raw);
  return [node, ...(node.calls ?? []).flatMap(flatten)];
};
const abi = new Interface(["function pull(uint256,bool)", "event Pulled(uint256,uint256,uint256,uint256)"]);
const ER = "0x4ac89ad061a531fa62ddceed53520c2750113b01", S = 10n ** 9n, U = 10n ** 27n;
const pulls = [], failures = [], signatures = [];
for (const directory of [join(source, "run-03"), join(source, "run-05"), join(home, "runtime-01")]) {
  for (const file of (await readdir(directory)).filter(f => f.endsWith(".json")).sort()) {
    const path = join(directory, file), raw = await load(path);
    if (!z.object({ raw: z.string() }).safeParse(raw).success) continue;
    const e = entry.parse(raw), tx = Transaction.from(e.raw);
    assert(keccak256(e.raw) === e.receipt.transactionHash && tx.chainId === 4663n
      && tx.from?.toLowerCase() === e.receipt.from.toLowerCase()
      && (tx.to?.toLowerCase() ?? null) === e.receipt.to, `signed transaction ${path}`);
    signatures.push({ path, sha256: digest(await readFile(path)), hash: e.receipt.transactionHash, nonce: tx.nonce,
      signer: tx.from, target: tx.to, calldata: tx.data, status: e.receipt.status });
    if (BigInt(e.receipt.status) === 0n) {
      const serial = (v: unknown) => JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? String(x) : x);
      assert(serial(e.before) === serial(e.after) && e.receipt.logs.length === 0, `failed economic state ${path}`);
      const late = trace.parse(e.trace).output === "0x96ecf629";
      if (late) assert(flatten(e.trace).some(t => t.to === ER && t.input.startsWith("0x23b872dd")
        && t.error === undefined && t.output === "0x" + "0".repeat(63) + "1"), `late failure preceded custody ${path}`);
      failures.push({ path, hash: e.receipt.transactionHash, lateAfterSuccessfulPull: late });
      continue;
    }
    if (!tx.data.startsWith(abi.getFunction("pull")?.selector ?? "missing")) continue;
    const n = z.bigint().parse(abi.decodeFunctionData("pull", tx.data)[0]);
    const w0 = e.before.accounts.find(a => a.who === e.receipt.from), w1 = e.after.accounts.find(a => a.who === e.receipt.from);
    const m0 = e.before.accounts.find(a => a.who === e.receipt.to), m1 = e.after.accounts.find(a => a.who === e.receipt.to);
    const b0 = e.before.books.find(b => b.who === e.receipt.to), b1 = e.after.books.find(b => b.who === e.receipt.to);
    if (!w0 || !w1 || !m0 || !m1 || !b0 || !b1) throw new ExecutionError("STATE", `endpoint ${path}`);
    const ds = w0.external - w1.external, dm = m1.external - m0.external;
    const L = ((ds > dm ? ds : dm) - 1n) * S + 1n, H1 = ((ds < dm ? ds : dm) + 1n) * S;
    const rLow = n * U / H1 + 1n, rHigh = n * U / L;
    assert(L > 0n && rLow === rHigh && rLow === e.before.rate && rLow === e.after.rate, `rate uniqueness ${path}`);
    const q = n * U / rLow, c = q === b0.Q ? b0.C : b0.C * q / b0.Q;
    assert(q > 0n && q <= b0.Q && c > 0n && w0.internal - w1.internal === q
      && m1.internal - m0.internal === q, `exact custody ${path}`);
    assert(b0.Q - b1.Q === q && b0.C - b1.C === c && b1.B - b0.B === q
      && b1.paid - b0.paid === c && b0.allowance - b1.allowance === n, `remaining credit ${path}`);
    assert(m0.internal - b0.B === m1.internal - b1.B && e.before.totalInternal === e.after.totalInternal
      && e.before.total === e.after.total, `unbooked and supply ${path}`);
    const event = e.receipt.logs.find(l => l.address === e.receipt.to);
    if (!event) throw new ExecutionError("STATE", "missing helper event");
    const decoded = abi.parseLog(event);
    assert(decoded !== null && decoded.args[0] === n && decoded.args[1] === rLow
      && decoded.args[2] === q && decoded.args[3] === c, `actual event ${path}`);
    pulls.push({ path, hash: e.receipt.transactionHash, n, q, c, ds, dm, rLow, rHigh,
      unbooked: m1.internal - b1.B, Q: b1.Q, C: b1.C });
  }
}
// Brute-force actual rates and endpoint fractions independently of the inverse formula.
let vectors = 0, singletons = 0;
for (let scale = 1n; scale <= 7n; scale++) for (let n = 1n; n <= 20n; n++) {
  for (let r = 1n; r <= 31n; r++) for (let f = 0n; f < scale; f++) for (let g = 0n; g < scale; g++) {
    const t = n * 101n / r, sender = t + f + 3n * scale, recipient = g + 3n * scale;
    const ds = sender / scale - (sender - t) / scale, dm = (recipient + t) / scale - recipient / scale;
    const L = ((ds > dm ? ds : dm) - 1n) * scale + 1n, H1 = ((ds < dm ? ds : dm) + 1n) * scale;
    if (L > 0n) {
      const rl = n * 101n / H1 + 1n, rh = n * 101n / L;
      assert(L <= t && t < H1 && rl <= r && r <= rh, "inverse theorem");
      if (rl === rh) { assert(n * 101n / rl === t, "singleton transfer"); singletons++; }
      for (let candidate = 1n; candidate <= 37n; candidate++) {
        const movement = n * 101n / candidate;
        assert((movement >= L && movement < H1) === (candidate >= rl && candidate <= rh), "floor inverse off-by-one");
      }
    }
    vectors++;
  }
}
const artifact = z.object({ deployedBytecode: z.object({ object: z.string(),
  immutableReferences: z.record(z.string(), z.array(z.object({ start: z.number(), length: z.number() }))) }),
  metadata: z.object({ compiler: z.object({ version: z.string() }),
    sources: z.record(z.string(), z.object({ keccak256: z.string() }).passthrough()) }).passthrough(),
}).passthrough().parse(await load(join(source, "build/ReceiptCustodyProbe.sol/ReceiptCustodyProbe.json")));
for (const [path, metadata] of Object.entries(artifact.metadata.sources)) {
  assert(keccak256(await readFile(path)) === metadata.keccak256, `compiler source ${path}`);
}
const runtimes = [];
for (const directory of [join(source, "run-03"), join(source, "run-05"), join(home, "runtime-01")]) {
  for (const file of (await readdir(directory)).filter(f => f.endsWith("-runtime.json"))) {
    const record = z.object({ helper: z.string(), code: z.string(), units: num, credit: num })
      .parse(await load(join(directory, file)));
    const actual = Buffer.from(record.code.slice(2), "hex"), expected = Buffer.from(artifact.deployedBytecode.object.slice(2), "hex");
    assert(actual.length === expected.length, "runtime length");
    const masked = new Set<number>(), spans = [];
    for (const [id, references] of Object.entries(artifact.deployedBytecode.immutableReferences)) {
      for (const span of references) {
        const observed = actual.subarray(span.start, span.start + span.length).toString("hex");
        const value = id === "304" ? signatures.find(s => s.target === null && s.path === join(directory, file.replace("-runtime", "")))?.signer
          : id === "305" ? record.units : id === "306" ? record.credit : undefined;
        if (value === undefined || value === null) throw new ExecutionError("STATE", "unknown immutable");
        assert(BigInt("0x" + observed) === BigInt(value), `actual immutable ${id}`);
        for (let i = span.start; i < span.start + span.length; i++) masked.add(i);
        spans.push({ id, ...span, observed });
      }
    }
    assert(actual.every((b, i) => masked.has(i) || b === expected[i]), "runtime outside declared immutables");
    runtimes.push({ path: join(directory, file), helper: record.helper, keccak256: keccak256(actual), spans });
  }
}
await writeFile(join(home, "audit.json"), JSON.stringify({
  status: "INDEPENDENT_AUDIT_PASS", bindings, producerSealSha256: digest(sealBytes),
  signatures, pulls, failures, vectors, singletons, runtimes, compiler: artifact.metadata.compiler,
}, (_, x: unknown) => typeof x === "bigint" ? x.toString() : x, 2) + "\n", { flag: "wx" });
console.log("INDEPENDENT_AUDIT_PASS");
