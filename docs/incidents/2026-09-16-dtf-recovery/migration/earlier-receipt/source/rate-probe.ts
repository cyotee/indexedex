import { Interface, keccak256 } from "ethers";
import { z } from "zod";
import { hash, hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { DEV } from "../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import {
  ER, ED, DTF, UNIT, abi, original, node, chain, number, check,
  persist, signed, deploy, fund, fundGas, snapshot, diagnosticInternal,
} from "./probe-runtime.js";

// This follow-up executes only the unfinished rate-movement obligation.
const candidates = [
  "0xbedf78eb17a054d972c85ce222e2175f19899cd6",
  "0x082cb14f04d9c485473dedc00d604d7e9abca303",
  "0x230f95db9644c5b3608ba676d18426d03e435b1d",
  "0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed",
] as const;
try {
  const header = z.object({ hash }).passthrough().parse(await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
  check(header.hash === "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733", "wrong pin");
  const code = hex.parse(await chain.send("eth_getCode", ["0x25e611fb63eb904776678286ef5cbe2a931b4f9a", "latest"]));
  check(keccak256(code) === "0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc", "wrong ER runtime");
  await persist("identity", { header, metadata: await chain.send("anvil_metadata", []), code, original });
  await fundGas();
  const rate0 = await number(ER, "redemptionRate");
  await fund(original, 10000n);
  const Q0 = 10000n * UNIT / rate0;
  const helper = await deploy("deploy-rate", Q0, 1000001n);
  await fund(helper, 1n);
  const unrelated = await diagnosticInternal(helper);
  await signed("approve-rate", { to: ER, data: abi.encodeFunctionData("approve", [helper, 10000n]) });
  await signed("before-movement-pull", { to: helper, data: abi.encodeFunctionData("pull", [1n, false]) });
  const available = [];
  for (const who of candidates) available.push({ who,
    code: await chain.send("eth_getCode", [who, "latest"]),
    dtf: String(await number(DTF, "balanceOf", [who])),
    ed: String(await number(ED, "balanceOf", [who])),
    wd: String(await number("0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", "balanceOf", [who])),
  });
  await persist("real-donor-balances", available);
  // Acquire real DTF through the existing admitted weighted-liquid swap.
  // WD here is a funding input only, never the ER eligible unit or custody substitute.
  const donor = candidates[1];
  const WD = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
  const wdInput = 100000000n;
  const donation = 100n * 10n ** 18n;
  check(await number(WD, "balanceOf", [donor]) >= wdInput, "real WD donor lacks bounded amount");
  check(await chain.send("eth_getCode", [donor, "latest"]) === "0x", "donor must be EOA");
  await chain.transact(donor, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  await chain.send("anvil_impersonateAccount", [donor]);
  try {
    await persist("wd-acquisition", await chain.transact(WD, { from: donor,
      data: abi.encodeFunctionData("transfer", [original, wdInput]) }));
  } finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
  await signed("wd-approval", { to: WD, data: abi.encodeFunctionData("approve", [WD, wdInput]) });
  const exchange = new Interface(["function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256)"]);
  await signed("dtf-acquisition", { to: WD, data: exchange.encodeFunctionData("exchangeIn",
    [WD, wdInput, DTF, donation, original, false, await chain.timestamp() + 3600n]) });
  check(await number(DTF, "balanceOf", [original]) >= donation, "genuine swap did not acquire DTF");
  const beforeMove = await snapshot();
  // The actual ER rate trace reads DTF.balanceOf(ES), not idle DTF at LP.
  // Plain DTF transfer changes that real valuation input without invoking an ES exit.
  const ES = "0xb7d4bb379d361ad442cddee53ea71a33957826a7";
  const dtfBefore = await number(DTF, "balanceOf", [ES]);
  await signed("real-reserve-donation", { to: DTF, data: abi.encodeFunctionData("transfer", [ES, donation]) });
  check(await number(DTF, "balanceOf", [ES]) - dtfBefore === donation, "actual source valuation input did not change");
  const rate1 = await number(ER, "redemptionRate");
  await persist("rate-movement", { before: beforeMove, after: await snapshot(),
    rate0: String(rate0), rate1: String(rate1), token: DTF, destination: ES, donation: String(donation) });
  check(rate1 !== rate0, "real reserve DTF donation did not move ER rate");
  const changed = await signed("changed-rate-pull", { to: helper, data: abi.encodeFunctionData("pull", [1n, false]) });
  const q1 = UNIT / rate1;
  check(await number(helper, "bookedInternal") === UNIT / rate0 + q1, "booked units did not follow actual rates");
  check(await diagnosticInternal(helper) - await number(helper, "bookedInternal") === unrelated,
    "rate movement booked old fraction");
  check(await number(helper, "originalUnits") === Q0 && await number(helper, "originalCredit") === 1000001n,
    "rate movement repriced original");
  await signed("changed-rate-late-rollback", {
    to: helper, data: abi.encodeFunctionData("pull", [1n, true]), expected: 0n,
  });
  await persist("result", { disposition: "RATE_PROOF_COMPLETE", rate0: String(rate0), rate1: String(rate1),
    q1: String(q1), unrelated: String(unrelated), receipt: changed.receipt, final: await snapshot(),
    productionImplementation: false, syntheticOriginalCredit: true });
  console.log("RATE_PROOF_COMPLETE");
} finally {
  chain.close();
  await node.close();
  await persist("cleanup", { pid: node.pid, stopped: true, port: 18568,
    subscriptionsClosed: true, allImpersonationsStopped: true, checkpointCreated: false });
}
