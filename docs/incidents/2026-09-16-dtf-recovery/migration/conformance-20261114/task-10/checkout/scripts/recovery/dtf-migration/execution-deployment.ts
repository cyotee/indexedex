import { AbiCoder, Result, keccak256 } from "ethers";
import { z } from "zod";
import type { ExecutionDomain } from "./execution-domain.js";
import { registryAbi } from "./execution-domain.js";
import type { Rpc } from "./execution-rpc.js";
import { ExecutionError } from "./execution-schema.js";
import { address, hex } from "./schema.js";

function tuple(value: unknown): Result {
  if (!(value instanceof Result)) throw new ExecutionError("STATE", "missing deployment construction tuple");
  return value;
}

/** Reconcile preparation at its receipt block, even after final construction. */
export async function capturePreparation(rpc: Rpc, domain: ExecutionDomain, at: string) {
  const { manifest: m, abis } = domain;
  if (!m.deployment) throw new ExecutionError("DOMAIN", "preparation requires full deployment arguments");
  const parameter = abis.pkg.getFunction("prepareSyChildren")?.inputs[0];
  const constructionType = abis.pkg.getFunction("syConstruction")?.outputs[0];
  if (!parameter || !constructionType?.components) throw new ExecutionError("DOMAIN", "missing construction ABI");
  const coder = AbiCoder.defaultAbiCoder();
  const constructionId = keccak256(coder.encode(["uint256", "address", parameter],
    [m.chainId, m.package, m.deployment]));
  const construction = tuple((await rpc.call(m.package, abis.pkg, "syConstruction", [m.deployment], at))[0]);
  const syPackage = address.parse((await rpc.call(m.package, abis.pkg, "syPackage", [], at))[0]);
  const dependencies = tuple((await rpc.call(m.package, abis.pkg, "preparationDependencies", [], at))[0]);
  if (construction.getValue("constructionId") !== constructionId
    || address.parse(construction.getValue("parent")) !== m.proxy
    || address.parse(dependencies.getValue("syPackage")) !== syPackage) {
    throw new ExecutionError("STATE", "construction differs from full bound arguments");
  }
  const prepared = tuple((await rpc.call(syPackage, abis.syPackage, "preparation", [constructionId], at))[0]);
  const hashArgs = (name: string) => {
    const component = constructionType.components?.find((value) => value.name === name);
    if (!component) throw new ExecutionError("DOMAIN", "missing child argument ABI");
    return keccak256(coder.encode([component], [construction.getValue(name)]));
  };
  const expected = {
    parentPackage: m.package, constructionId, parent: m.proxy,
    bond: address.parse(construction.getValue("bond")),
    bondPackage: address.parse(dependencies.getValue("bondPackage")),
    receipt: address.parse(construction.getValue("receipt")),
    bondArgsHash: hashArgs("bondArgs"), rawArgsHash: hashArgs("rawArgs"),
    stakingArgsHash: hashArgs("stakingArgs"),
  };
  if (prepared.getValue("completed") !== true
    || Object.entries(expected).some(([key, value]) => String(prepared.getValue(key)).toLowerCase() !== value)) {
    throw new ExecutionError("STATE", "preparation state differs from canonical construction");
  }
  const rawSy = address.parse(prepared.getValue("rawSy"));
  const stakingSy = address.parse(prepared.getValue("stakingSy"));
  if (rawSy === stakingSy) throw new ExecutionError("STATE", "prepared SY identities overlap");
  for (const account of [m.proxy, expected.receipt]) {
    if (hex.parse(await rpc.send("eth_getCode", [account, at])) !== "0x") {
      throw new ExecutionError("STATE", "preparation published a parent or receipt");
    }
  }
  const parents = z.array(address).parse((await rpc.call(m.registry, registryAbi, "vaultsOfPackage", [m.package], at))[0]);
  if (parents.includes(m.proxy)) throw new ExecutionError("STATE", "preparation published parent discovery");
  await rpc.call(syPackage, abis.syPackage, "validateBond",
    [expected.bond, expected.bondPackage, construction.getValue("bondArgs"), false,
      "0x0000000000000000000000000000000000000000"], at);
  for (const [child, name, argsHash] of [
    [rawSy, "rawArgs", expected.rawArgsHash], [stakingSy, "stakingArgs", expected.stakingArgsHash],
  ] as const) {
    if (address.parse((await rpc.call(syPackage, abis.syPackage, "authorizedChild", [argsHash], at))[0]) !== child) {
      throw new ExecutionError("STATE", "prepared child authorization differs");
    }
    // Package validator checks exact factory args, registry, zero supply/backing and removed hooks.
    await rpc.call(syPackage, abis.syPackage, "validateChild", [child, construction.getValue(name)], at);
  }
  return { ...expected, syPackage, rawSy, stakingSy, completed: "true" };
}
