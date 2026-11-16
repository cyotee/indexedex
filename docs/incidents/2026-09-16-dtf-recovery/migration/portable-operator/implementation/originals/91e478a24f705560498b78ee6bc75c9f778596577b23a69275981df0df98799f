import { Interface, Result } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { claimedSyEvidenceId, stakingClaim, stakingSource } from "./claimed-sy.js";
import { claimedSigned } from "./rehearsal-claimed-sy-source.js";
import { interfaceFile, save, sourceFile } from "./rehearsal-data.js";
import { prepareDomain } from "./preparation.js";
import { address, claimedSyCertificate, PreparationError, preparationInput, heldSeLpSources } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { ExecutionError } from "./execution-schema.js";
import { DEV } from "./execution-rpc.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { canonical } from "./provenance.js";

const token = new Interface([
  "function balanceOf(address) view returns(uint256)", "function totalSupply() view returns(uint256)",
  "function allowance(address,address) view returns(uint256)", "function approve(address,uint256) returns(bool)",
]);
const bonds = new Interface([
  "function ownerOf(uint256) view returns(address)", "function balanceOf(address) view returns(uint256)",
  "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
  "function isMigrationPosition(uint256) view returns(bool)",
]);
function tuple(value: unknown): Result {
  if (!(value instanceof Result)) throw new ExecutionError("STATE", "claimed SY tuple missing");
  return value;
}

/** Reconcile the real gate before any configuration transaction, not only a schema mock. */
export async function checkClaimedSyIntake(chain: RehearsalChain, input: PreparationInput, evidence: string) {
  const selected = input.weightedSy.filter((row) => row.claimedOrigin);
  const first = selected[0];
  const second = selected[1];
  if (!first?.claimedOrigin || !second?.claimedOrigin) throw new ExecutionError("STATE", "two complete originals required");
  const nonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
  const cases = [
    { name: "incomplete", certificate: { ...second.claimedOrigin, members: second.claimedOrigin.members.slice(0, -1) } },
    { name: "duplicate", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m) => ({ ...m, transactionHash: second.claimedOrigin?.members[0]?.transactionHash })) } },
    { name: "wrong-output", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m, i) => i === 0 ? { ...m, receivedSy: String(BigInt(m.receivedSy) + 1n) } : m) } },
    { name: "noncanonical", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m) => ({ ...m, blockHash: `0x${"f".repeat(64)}` })) } },
    { name: "tampered-signature", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m) => ({ ...m, rawSignedTransaction: first.claimedOrigin?.members[0]?.rawSignedTransaction })) } },
  ];
  const observations = [];
  for (const test of cases) {
    const certificate = claimedSyCertificate.parse(test.certificate);
    const original = { ...second.original, evidenceId: claimedSyEvidenceId(input.domain, second.original, certificate) };
    const changed = { original, claimedOrigin: certificate };
    const path = join(evidence, `claimed-intake-${test.name}.json`);
    await save(path, changed);
    const candidate = preparationInput.parse({ ...input,
      sources: [...input.sources, await sourceFile(`claimed-negative-${test.name}`, path)],
      weightedSy: input.weightedSy.map((row) => row.original.originalId === original.originalId
        ? { ...changed, proof: { sourceId: `claimed-negative-${test.name}`, pointer: "" } } : row),
    });
    let rejected = false;
    try { await prepareDomain(candidate); }
    catch (error) {
      if (!(error instanceof PreparationError)) throw error;
      observations.push({ case: test.name, code: error.code, reason: error.message });
      rejected = true;
    }
    if (!rejected) throw new ExecutionError("STATE", `claimed intake ${test.name} unexpectedly passed`);
  }
  const { claimedOrigin: _missing, ...ordinary } = second;
  const flatIndex = input.weightedSy.findIndex(row => row.original.originalId === second.original.originalId);
  for (const [name, pointer] of [
    ["missing-certificate", ordinary.proof.pointer],
    ["nested-proof-downgrade", `${ordinary.proof.pointer}/original`],
    ["flat-proof-downgrade", `/weightedSy/${flatIndex}`],
  ]) {
    const candidate = preparationInput.parse({ ...input, weightedSy: input.weightedSy.map((row) =>
      row.original.originalId === second.original.originalId
        ? { ...ordinary, proof: { ...ordinary.proof, pointer } } : row) });
    try {
      await prepareDomain(candidate);
      throw new ExecutionError("STATE", "missing claimed evidence fell back to ordinary SY");
    } catch (error) {
      if (!(error instanceof PreparationError) || error.code !== "PROVENANCE") throw error;
      observations.push({ case: name, code: error.code, reason: error.message });
    }
  }
  if (nonce !== await chain.send("eth_getTransactionCount", [DEV, "latest"])) {
    throw new ExecutionError("STATE", "claimed intake rejection broadcast a configuration");
  }
  await save(join(evidence, "claimed-intake-rejections.json"), { nonceBefore: nonce, nonceAfter: nonce, observations });
}

/** Same-wallet EOA custody/funding; no claimed-origin receiver callback is asserted. */
export async function exerciseClaimedSy(context: {
  readonly chain: RehearsalChain; readonly input: PreparationInput; readonly manifest: ExecutionManifest;
  readonly evidence: string; readonly phase: "stage1" | "partial" | "terminal";
}) {
  const { chain, input, manifest, evidence, phase } = context;
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const parent = manifest.proxy;
  const bond = address.parse((await chain.call(parent, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(parent, migration, "rebasingClaimToken"))[0]);
  const n = async (target: string, method: string, args: readonly unknown[] = []) =>
    z.bigint().parse((await chain.call(target, token, method, args))[0]);
  const inventory = async (asset: string) =>
    z.bigint().parse((await chain.call(parent, recovery, "migrationRecoveryInventory", [asset]))[0]);
  for (const row of input.weightedSy) {
    const certificate = row.claimedOrigin;
    if (!certificate) continue;
    const original = row.original;
    const wallet = original.originalWallet;
    const index = certificate.members.length === 1 ? 231 : 232;
    const send = async (data: string, to = parent, status = 1n, gas = 20000000n) =>
      claimedSigned(chain, evidence, { index, to, data, status, gas });
    const state = async () => tuple((await chain.call(parent, migration, "weightedSySurrender", [original.originalId]))[0]);
    const config = tuple((await chain.call(parent, migration, "weightedSyEntitlement", [original.originalId]))[0]);
    const c0 = z.bigint().parse(config.getValue("credit"));
    const loaded = tuple(config.getValue("original"));
    if (loaded.getValue("evidenceId") !== original.evidenceId || loaded.getValue("originalUnits") !== BigInt(original.originalUnits)
      || loaded.getValue("originalEth") !== BigInt(original.originalEth)
      || loaded.getValue("originalDtf") !== BigInt(original.originalDtf)
      || address.parse(loaded.getValue("originalWallet")) !== wallet) {
      throw new ExecutionError("STATE", "certificate and actual loaded original differ");
    }
    const protectedInventory = async () => {
      const values = [];
      for (const asset of [LEGACY.dtf, LEGACY.detf, LEGACY.receipt,
        "0xaf0e1967c8f755c747615c5427108bc549ca1122", "0x4ac89ad061a531fa62ddceed53520c2750113b01",
        ...heldSeLpSources]) values.push(String(await n(asset, "balanceOf", [parent])), String(await inventory(asset)));
      values.push(String((await chain.call(parent, recovery, "migrationRecoveryGons"))[0]),
        String((await chain.call(parent, recovery, "migrationEarlierReceiptInternalShares"))[0]));
      return values.join("|");
    };
    const economic = async () => [
      (await state()).toString(), String(await n(certificate.sy, "balanceOf", [wallet])),
      String(await n(certificate.sy, "balanceOf", [parent])), String(await inventory(certificate.sy)),
      String(await n(certificate.sy, "allowance", [wallet, parent])),
      String(await n(parent, "totalSupply")), String(await n(parent, "balanceOf", [receipt])),
      String((await chain.call(receipt, legacyAbi, "gonsOf", [bond]))[0]),
      (await chain.call(bond, bonds, "balanceOf", [wallet])).toString(),
      String((await chain.call(stakingSource, stakingClaim, "balanceOf", [wallet]))[0]),
      String((await chain.call(stakingSource, stakingClaim, "totalSupply"))[0]), await protectedInventory(),
    ].join("|");
    const deadline = await chain.timestamp() + 3600n;
    const observations = [];
    if (phase === "stage1") {
      await send(token.encodeFunctionData("approve", [parent, original.originalUnits]), certificate.sy);
      const before = await economic();
      const failed = await send(migration.encodeFunctionData("surrenderMigrationWeightedSy",
        [original.originalId, original.originalUnits, 0, deadline]), parent, 0n);
      if (before !== await economic()) throw new ExecutionError("STATE", "claimed Stage1 rejection changed state");
      observations.push({ kind: "stage1-rejection", transactionHash: failed.mined.transactionHash });
    } else {
      await chain.transact(parent, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
      const before = await state();
      const remaining = z.bigint().parse(before.getValue("remainingUnits"));
      const credit = z.bigint().parse(before.getValue("remainingCredit"));
      const q = phase === "terminal" ? remaining : BigInt(original.originalUnits) / 3n;
      const expected = q === remaining ? credit : credit * q / remaining;
      if (expected <= 0n) throw new ExecutionError("STATE", "claimed credit must be positive");
      await send(token.encodeFunctionData("approve", [parent, q]), certificate.sy);
      if (phase === "partial") {
        const saved = await economic();
        const minimumFailure = await send(migration.encodeFunctionData("surrenderMigrationWeightedSy",
          [original.originalId, q, expected + 1n, deadline]), parent, 0n);
        if (saved !== await economic()) throw new ExecutionError("STATE", "claimed minimum rejection changed state");
        const failed = await send(migration.encodeFunctionData("surrenderMigrationWeightedSy",
          [original.originalId, q, expected, deadline]), parent, 0n, 750000n);
        const frames: unknown[] = [];
        const visit = (raw: unknown): void => {
          const frame = z.object({ to: address, input: z.string(), calls: z.array(z.unknown()).default([]) }).passthrough().parse(raw);
          frames.push(frame);
          for (const child of frame.calls) visit(child);
        };
        visit(failed.trace);
        const exchange = new Interface(["function exchangeIn(address,uint256,address,uint256,address,bool,uint256)"]);
        const funding = exchange.encodeFunctionData("exchangeIn", [parent, expected, receipt, expected, bond, false,
          BigInt(z.object({ timestamp: z.string() }).passthrough().parse(
            await chain.send("eth_getBlockByNumber", [failed.mined.blockNumber, false])).timestamp)]);
        if (!frames.some((raw) => {
          const frame = z.object({ to: address, input: z.string() }).passthrough().parse(raw);
          return frame.to === receipt && frame.input === funding;
        }) || saved !== await economic()) throw new ExecutionError("STATE", "failure did not reach actual child funding and restore later books");
        observations.push({ kind: "late-funding-rollback", transactionHash: failed.mined.transactionHash,
          minimumFailure: minimumFailure.mined.transactionHash, rawWeightStillConsumed: true });
      }
      const floor = await protectedInventory();
      const supply = await n(parent, "totalSupply");
      const backing = await n(parent, "balanceOf", [receipt]);
      const balance = await n(certificate.sy, "balanceOf", [wallet]);
      const held = await n(certificate.sy, "balanceOf", [parent]);
      const booked = await inventory(certificate.sy);
      const result = await send(migration.encodeFunctionData("surrenderMigrationWeightedSy",
        [original.originalId, q, expected, deadline]));
      const event = result.mined.logs.filter((l) => l.address === parent).map((l) =>
        migration.parseLog({ topics: [...l.topics], data: l.data })).find((e) => e?.name === "MigrationWeightedSySurrendered");
      if (!event) throw new ExecutionError("STATE", "missing claimed-origin surrender event");
      const id = z.bigint().parse(event.args[5]);
      const position = tuple((await chain.call(bond, bonds, "positionOf", [id]))[0]);
      const divisor = z.bigint().parse(tuple((await chain.call(receipt, legacyAbi, "stakingState"))[0]).getValue("gonsPerUnit"));
      const timestamp = BigInt(z.object({ timestamp: z.string() }).passthrough().parse(
        await chain.send("eth_getBlockByNumber", [result.mined.blockNumber, false])).timestamp);
      const after = await state();
      if (event.args[0] !== original.originalId || event.args[1] !== config.getValue("configurationId")
        || address.parse(event.args[2]) !== wallet || event.args[3] !== q || event.args[4] !== expected
        || address.parse((await chain.call(bond, bonds, "ownerOf", [id]))[0]) !== wallet
        || position.getValue("principal") !== expected || position.getValue("claimedPrincipal") !== 0n
        || position.getValue("stakingGons") !== expected * divisor || position.getValue("startTimestamp") !== timestamp
        || position.getValue("vestingDuration") !== 7776000n
        || (await chain.call(bond, bonds, "isMigrationPosition", [id]))[0] !== true
        || await n(parent, "totalSupply") !== supply + expected || await n(parent, "balanceOf", [receipt]) !== backing + expected
        || await n(certificate.sy, "balanceOf", [wallet]) !== balance - q
        || await n(certificate.sy, "balanceOf", [parent]) !== held + q || await inventory(certificate.sy) !== booked + q
        || after.getValue("remainingUnits") !== remaining - q || after.getValue("remainingCredit") !== credit - expected
        || z.bigint().parse(after.getValue("deliveredCredit")) + z.bigint().parse(after.getValue("remainingCredit")) !== c0
        || await protectedInventory() !== floor) throw new ExecutionError("STATE", "claimed-origin exact custody credit funding or conservation differs");
      observations.push({ kind: "surrender", transactionHash: result.mined.transactionHash, quantity: String(q),
        credit: String(expected), bondTokenId: String(id), start: String(timestamp), duration: "7776000",
        remainingUnits: String(after.getValue("remainingUnits")), remainingCredit: String(after.getValue("remainingCredit")) });
    }
    const remaining = z.bigint().parse((await state()).getValue("remainingUnits"));
    if (await n(certificate.sy, "balanceOf", [wallet]) !== remaining + BigInt(certificate.review.unrelatedSyFloor)
      || (await chain.call(stakingSource, stakingClaim, "balanceOf", [wallet]))[0] !== BigInt(certificate.review.unrelatedWeightFloor)) {
      throw new ExecutionError("STATE", "earlier source claims or unrelated floors changed");
    }
    await save(join(evidence, `claimed-sy-${index}-${phase}.json`), { original, certificate,
      originalCredit: String(c0), configurationId: config.getValue("configurationId"), observations,
      authority: "synthetic reviewed originals; actual direct controlled signatures; ordinary-SY callback tests are shared-path only",
      actualLoadedOriginal: canonical(loaded.toArray().map((v) => typeof v === "bigint" ? String(v) : v)) });
  }
}
