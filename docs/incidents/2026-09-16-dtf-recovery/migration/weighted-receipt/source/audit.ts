import { readFile, readdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface, Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { ExecutionError, receipt } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { LEGACY } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";

const here = dirname(fileURLToPath(import.meta.url));
const run = join(here, "run-04");
const load = async (name: string): Promise<unknown> => JSON.parse(await readFile(join(run, name), "utf8"));
const check = (condition: boolean, message: string) => {
  if (!condition) throw new ExecutionError("STATE", message);
};
const snapshot = z.object({
  state: z.array(z.string()),
  accounts: z.array(z.object({ who: z.string(), gons: z.string(), native: z.string(), wd: z.string() })),
  helperAllowance: z.string(), recipientAllowance: z.string(),
});
const witness = z.object({
  raw: z.string(), data: z.string(), nonce: z.number(), before: snapshot, after: snapshot, receipt,
  trace: z.unknown(),
}).passthrough();
const boundary = z.object({
  Q0: z.string(), k0: z.string(), k1: z.string(), remaining: z.string(), residue: z.string(),
  maxNative: z.string(), C0: z.string(), partialCredit: z.string(), lastTransferCredit: z.string(),
  remainingCredit: z.string(),
}).passthrough().parse(await load("boundary.json"));
const Q0 = BigInt(boundary.Q0), k0 = BigInt(boundary.k0), k1 = BigInt(boundary.k1);
const remaining = Q0 - k1, maxNative = remaining / k1, residue = remaining % k1;
const C0 = BigInt(boundary.C0), c1 = C0 * k1 / Q0, c2 = (C0 - c1) * maxNative * k1 / remaining;
check(Q0 === 101n * k0 && k1 < k0 && residue > 0n && residue < k1
  && residue === BigInt(boundary.residue) && C0 - c1 - c2 === 1n, "boundary arithmetic differs");
const signed = [];
const failures = [];
for (const name of (await readdir(run)).filter((name) => name.startsWith("signed-")).sort()) {
  const entry = witness.parse(await load(name));
  const transaction = Transaction.from(entry.raw);
  check(transaction.chainId === 4663n && transaction.from?.toLowerCase() === entry.receipt.from
    && transaction.nonce === entry.nonce && transaction.data === entry.data
    && keccak256(entry.raw) === entry.receipt.transactionHash, "signed receipt binding differs " + name);
  if (BigInt(entry.receipt.status) === 0n) {
    check(JSON.stringify(entry.before) === JSON.stringify(entry.after) && entry.receipt.logs.length === 0,
      "rollback differs " + name);
    failures.push({ name, hash: entry.receipt.transactionHash, trace: entry.trace });
  }
  signed.push({ name, hash: entry.receipt.transactionHash, status: entry.receipt.status,
    signer: transaction.from, nonce: transaction.nonce, gasUsed: entry.receipt.gasUsed });
}
const errors = new Interface(["error LateFailure(uint256 receivedGons)", "error ProtectedGons(uint256 actualDebit,uint256 bookedGons)"]);
const rootTrace = z.object({ output: z.string() }).passthrough();
const decodedFailures = [];
for (const failed of failures) {
  const trace = rootTrace.parse(failed.trace);
  if (trace.output.startsWith(errors.getError("LateFailure")?.selector ?? "missing")) {
    const moved = z.bigint().parse(errors.decodeErrorResult("LateFailure", trace.output)[0]);
    check(moved > 0n, "late failure did not follow actual successful receipt custody");
    decodedFailures.push({ kind: "late-after-pull", hash: failed.hash, movedGonsBeforeRevert: String(moved) });
  }
  if (trace.output.startsWith(errors.getError("ProtectedGons")?.selector ?? "missing")) {
    const [debit, booked] = [...errors.decodeErrorResult("ProtectedGons", trace.output)].map((x) => z.bigint().parse(x));
    if (debit === undefined || booked === undefined) throw new ExecutionError("STATE", "bad error tuple");
    check(debit > booked, "protected-gon rollback did not cross actual boundary");
    decodedFailures.push({ kind: "unbooked-retirement", hash: failed.hash, debit: String(debit), booked: String(booked) });
  }
}
check(decodedFailures.length === 2, "missing actual late pull or protected retirement rollback");
const pull = z.object({ before: snapshot, after: snapshot, receipt }).passthrough().parse(await load("synchronized-pull.json"));
const identity = z.object({ original: z.string(), recipient: z.string(), roles: z.array(z.string()) })
  .passthrough().parse(await load("identity.json"));
const account = (state: z.infer<typeof snapshot>, who: string) => {
  const found = state.accounts.find((entry) => entry.who === who);
  if (!found) throw new ExecutionError("STATE", "account missing " + who);
  return found;
};
const roleGrowth = [...new Set(identity.roles)].map((who) => ({
  who, before: account(pull.before, who), after: account(pull.after, who),
  addedGons: String(BigInt(account(pull.after, who).gons) - BigInt(account(pull.before, who).gons)),
}));
check(roleGrowth.some((role) => BigInt(role.addedGons) > 0n), "no actual role-growth witness");
check(BigInt(account(pull.before, identity.original).gons) - BigInt(account(pull.after, identity.original).gons) === k1
  && BigInt(account(pull.after, identity.recipient).gons) - BigInt(account(pull.before, identity.recipient).gons) === k1,
"measured ordinary custody differs");
const sourceLogs = pull.receipt.logs.filter((log) => log.address === LEGACY.receipt);
const output = {
  disposition: "not-ready", Q0: String(Q0), k0: String(k0), k1: String(k1),
  q1: String(k1), firstCredit: String(c1), remainingQ: String(remaining),
  lastRepresentableNative: String(maxNative), lastCredit: String(c2),
  residualGons: String(residue), residualCredit: String(C0 - c1 - c2),
  terminalCounterexample: { Q: String(residue), C: "1", nativeFloor: "0", minimumPositiveGons: String(k1) },
  original: identity.original, recipient: identity.recipient,
  synchronizedPull: { hash: pull.receipt.transactionHash, before: pull.before, after: pull.after, sourceLogs },
  roleGrowth, signed, decodedFailures, signedCount: signed.length,
  failedCount: failures.length, allFailedEconomicStatesEqual: true,
  limits: "No Migration WS implementation, C0 quote, funded bond or operator acceptance is claimed.",
};
await save(join(here, "proof.json"), output);
console.log("SOURCE_AUDIT_PASSED", signed.length, "signed receipts;", failures.length, "atomic failures");
