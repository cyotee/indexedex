import { readFile, writeFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { ExecutionError } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const here = dirname(fileURLToPath(import.meta.url));
const json = async (name: string): Promise<unknown> => JSON.parse(await readFile(join(here, name), "utf8"));
function proof(value: boolean, message: string): asserts value {
  if (!value) throw new ExecutionError("STATE", message);
}
const event = z.object({ address: z.string(), name: z.string(), values: z.array(z.string()) });
const routeEntry = z.object({ file: z.string(), hash: z.string(), signer: z.string(), status: z.string(),
  before: z.record(z.string(), z.string()), after: z.record(z.string(), z.string()),
  output: z.string().optional(), events: z.array(event) }).passthrough();
const receipts = z.object({
  run: z.string(), deployment: z.record(z.string(), z.unknown()),
  resumes: z.array(z.record(z.string(), z.unknown())),
  activation: z.record(z.string(), z.unknown()), acquired: z.array(z.record(z.string(), z.unknown())),
  route: z.array(routeEntry), economics: z.array(z.object({
    phase: z.string(), originalCredit: z.string(), original: z.record(z.string(), z.unknown()),
    observations: z.array(z.record(z.string(), z.unknown())),
    linked: z.array(z.object({ key: z.string(), hash: z.string(), status: z.string(), events: z.array(event) })),
  })), verifiedSignedCompletions: z.number(), fixtureReceipts: z.number(),
}).parse(await json("receipt-audit.json"));
const bindings = z.object({
  checked: z.array(z.object({ group: z.string(), path: z.string(), sha256: z.string() }).passthrough()),
  artifacts: z.array(z.record(z.string(), z.unknown())), distinctMetadataSources: z.number(),
  runtimeCount: z.number(), dependencies: z.array(z.record(z.string(), z.unknown())),
}).parse(await json("binding-audit.json"));
const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
const wallet = "0xd96eb0f2e106ea7c0a939e9c460a17ace65fecff";
const zero = "0x0000000000000000000000000000000000000000";
function transfer(events: readonly z.infer<typeof event>[], token: string, from: string, to: string, amount: bigint) {
  proof(events.some((row) => row.name === "Transfer" && row.address === token
    && row.values[0]?.toLowerCase() === from && row.values[1]?.toLowerCase() === to
    && row.values[2] === amount.toString()), `missing exact ${token} Transfer ${from} -> ${to}: ${amount}`);
}
const sourceLogs = [];
for (const item of receipts.route) {
  if (BigInt(item.status) !== 1n) continue;
  const deposit = item.events.find((row) => row.address === vault && row.name === "Deposit");
  const withdraw = item.events.find((row) => row.address === vault && row.name === "Withdraw");
  if (deposit) {
    const [sender, owner, assetsString, sharesString] = deposit.values;
    const assets = BigInt(z.string().parse(assetsString));
    const shares = BigInt(z.string().parse(sharesString));
    proof(sender?.toLowerCase() === wallet && owner !== undefined && item.output?.length === 66
      && BigInt(item.output) === shares, "deposit return/mint log mismatch");
    transfer(item.events, sy, wallet, vault, assets);
    transfer(item.events, vault, zero, owner.toLowerCase(), shares);
    proof(BigInt(z.string().parse(item.before["walletSy"])) - BigInt(z.string().parse(item.after["walletSy"])) === assets
      && BigInt(z.string().parse(item.after["vaultSy"])) - BigInt(z.string().parse(item.before["vaultSy"])) === assets
      && BigInt(z.string().parse(item.after["supply"])) - BigInt(z.string().parse(item.before["supply"])) === shares,
    "deposit logs disagree with native payment/supply deltas");
    sourceLogs.push({ kind: "deposit", hash: item.hash, sender, owner, assets: String(assets), shares: String(shares) });
  }
  if (withdraw) {
    const [sender, receiver, owner, assetsString, sharesString] = withdraw.values;
    const assets = BigInt(z.string().parse(assetsString));
    const shares = BigInt(z.string().parse(sharesString));
    proof(sender?.toLowerCase() === wallet && owner?.toLowerCase() === wallet && receiver?.toLowerCase() === wallet
      && item.output?.length === 66 && BigInt(item.output) === assets, "redemption return/receiver mismatch");
    transfer(item.events, vault, wallet, zero, shares);
    transfer(item.events, sy, vault, wallet, assets);
    proof(BigInt(z.string().parse(item.before["walletShares"])) - BigInt(z.string().parse(item.after["walletShares"])) === shares
      && BigInt(z.string().parse(item.before["supply"])) - BigInt(z.string().parse(item.after["supply"])) === shares
      && BigInt(z.string().parse(item.after["walletSy"])) - BigInt(z.string().parse(item.before["walletSy"])) === assets
      && BigInt(z.string().parse(item.before["vaultSy"])) - BigInt(z.string().parse(item.after["vaultSy"])) === assets,
    "redemption logs disagree with measured burn/payment");
    sourceLogs.push({ kind: "redeem", hash: item.hash, owner, receiver, assets: String(assets), shares: String(shares) });
  }
}
const surrender = receipts.economics.flatMap((phase) => phase.observations.filter((row) => row["kind"] === "surrender"));
proof(surrender.length === 2, "missing actual partial/final surrender");
const first = surrender[0];
const last = surrender[1];
proof(first !== undefined && last !== undefined, "missing native economic rows");
const partial = receipts.economics.find((phase) => phase.phase === "partial");
proof(partial !== undefined, "missing partial phase");
const q0 = BigInt(z.string().parse(partial.original["originalUnits"]));
const c0 = BigInt(partial.originalCredit);
const q1 = BigInt(z.string().parse(first["quantity"]));
proof(BigInt(z.string().parse(first["credit"])) === c0 * q1 / q0
  && BigInt(z.string().parse(first["credit"])) + BigInt(z.string().parse(last["credit"])) === c0
  && BigInt(z.string().parse(last["quantity"])) === q0 - q1
  && last["remainingUnits"] === "0" && last["remainingCredit"] === "0"
  && first["duration"] === "7776000" && last["duration"] === "7776000"
  && BigInt(z.string().parse(last["startTimestamp"])) > BigInt(z.string().parse(first["startTimestamp"])),
"independent remaining-C/Q or fresh-clock arithmetic differs");
for (const phase of receipts.economics.filter((item) => item.phase !== "stage1")) {
  const surrendered = phase.observations.find((row) => row["kind"] === "surrender");
  const recovered = phase.observations.find((row) => row["kind"] === "redemption");
  proof(surrendered !== undefined && recovered !== undefined, "missing surrender/recovery");
  const q = BigInt(z.string().parse(surrendered["quantity"]));
  const output = BigInt(z.string().parse(recovered["syReceived"]));
  const mined = phase.linked.find((row) => row.key === "redeemTransaction");
  proof(mined !== undefined, "missing own-share redemption receipt");
  const parent = z.string().parse(recovered["fixedDestination"]);
  transfer(mined.events, vault, parent, zero, q);
  transfer(mined.events, sy, vault, parent, output);
  proof(mined.events.some((row) => row.name === "MigrationRecoveryConverted"
    && row.values[0]?.toLowerCase() === vault && row.values[1]?.toLowerCase() === sy
    && row.values[2] === String(q) && row.values[3] === String(output)), "single native SY booking event differs");
}
const snapshots = [];
for (const item of bindings.checked.filter((row) => row.group === "sources")) {
  const copy = join(dirname(here), "implementation-e1", "final-source-snapshot", item.path);
  proof(fingerprint(await readFile(copy)) === item.sha256, `snapshot/source mismatch: ${item.path}`);
  snapshots.push({ path: item.path, sha256: item.sha256 });
}
await writeFile(join(here, "reviewed-summary.json"), JSON.stringify({
  run: receipts.run, sourceLogs, surrenderArithmetic: { q0: String(q0), c0: String(c0), partial: first, final: last },
  economics: receipts.economics.map(({ linked: _linked, ...rest }) => rest),
  resumes: receipts.resumes, activation: receipts.activation, deployment: receipts.deployment,
  metadataSources: bindings.distinctMetadataSources, runtimeCount: bindings.runtimeCount,
  artifacts: bindings.artifacts, dependencies: bindings.dependencies, sourceSnapshots: snapshots,
  signedCompletions: receipts.verifiedSignedCompletions, fixtureReceipts: receipts.fixtureReceipts,
}, null, 2) + "\n", { flag: "wx" });
console.log("Independent decoded log, C/Q arithmetic, snapshot and bounded-summary checks passed");
