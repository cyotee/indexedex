import { intake, raw, json, sha, check, equal, identities, counters, SOURCE, PHASE, ARCH, V28, V30, V31,
  W, E, WD, ED, WETH, DTF, CORE, ZERO, TRANSFER } from "./intake.mjs";
import { routing, address, Interface } from "./routing.mjs";

const data = await intake();
const originals = [];
for (const [sourceId, path, collection, parent] of [
  ["S008", "evidence/weighted-bonds.csv", W, WD], ["S009", "evidence/earlier-cp-bonds.csv", E, ED]]) {
  for (const original of data.tables.get(path)) {
    const f = original.fields, locator = original.locator;
    const candidates = data.a28.results.map((value, index) => ({ value, index }))
      .filter(x => x.value.tx === f.purchase_tx.toLowerCase());
    check(candidates.length === 1, `unique canonical original ${locator}`);
    const { value: result, index } = candidates[0], tx = result.transactionObservation;
    const recipient = (f.purchase_recipient ?? f.owner).toLowerCase();
    const direct = tx.to === parent && tx.from === recipient && tx.input.startsWith("0x7a3b1181");
    check(result.conflicts.length === 0 && result.receiptObservation.status === "0x1", `accepted receipt ${locator}`);
    originals.push({ sourceId, original, f, locator, collection, parent, recipient, direct, tx, result, index });
  }
}
check(originals.length === 59 && originals.filter(x => x.sourceId === "S008").length === 43 &&
  new Set(originals.map(x => `${x.collection}:${x.f.token_id}`)).size === 59, "complete independently enumerated59");
const routed = await routing(data, originals);
const bond = new Interface(data.ea.contracts[CORE].abi), rows = [];
const earlierChild = new Interface(data.ea.contracts["0x3ab85813785b43b864f9c171f7ac97d6b76c459b"].abi);
const weightedChild = new Interface(data.wa["0x3a07364eaba092472d40f0e6788b8891a31fad4d"].abi);
for (const o of originals) {
  const { f, locator, tx, result, collection, parent, recipient, direct } = o;
  const historical = data.r28.find(x => x.locator === locator);
  const produced = data.producer.rows.find(x => x.original.locator === locator);
  const joined = data.worksheet.references.find(x => x.locator === locator);
  equal(joined.flags, historical.conflicts, `joined flags ${locator}`);
  check(joined.tx === tx.hash && joined.observedRecipient === recipient, `joined historical recipient ${locator}`);
  equal(historical.historicalFields, f, `accepted original fields ${locator}`);
  equal(produced.original, o.original, `producer original fields ${locator}`);
  equal(produced.historical.transaction, tx, `complete transaction ${locator}`);
  equal(produced.historical.receipt, result.receiptObservation, `complete receipt ${locator}`);
  const logs = result.receiptObservation.logs.map((log, offset) => ({ log, offset }));
  const mint = logs.filter(({ log }) => log.address === collection && log.topics[0] === TRANSFER &&
    log.topics.length === 4 && BigInt(log.topics[1]) === 0n && BigInt(log.topics[3]).toString() === f.token_id);
  check(mint.length === 1 && address(mint[0].log.topics[2]) === recipient, `actual historical mint ${locator}`);
  equal(produced.historical.mint, mint[0], `producer mint ${locator}`);
  const abi = collection === W ? weightedChild : earlierChild, name = collection === W ? "BondPurchased" : "NewLock";
  const purchases = logs.filter(({ log }) => log.address === collection && log.topics[0] === abi.getEvent(name).topicHash &&
    BigInt(log.topics[1]).toString() === f.token_id && address(log.topics[2]) === recipient);
  check(purchases.length === 1, `exact source purchase event ${locator}`);
  const event = abi.decodeEventLog(name, purchases[0].log.data, purchases[0].log.topics);
  equal(event[2].toString(), f.original_principal_detf_raw ?? f.original_lp_shares_raw, `source-native purchase basis ${locator}`);
  if (collection === W) {
    equal(event[3].toString(), f.start_timestamp, `purchase start ${locator}`);
    equal(event[4].toString(), f.duration_seconds, `purchase duration ${locator}`);
  }
  let decoded = null;
  if (direct) {
    check(/^0x7a3b1181[0-9a-f]{384}$/.test(tx.input), `six exact words ${locator}`);
    const words = tx.input.slice(10).match(/.{64}/g);
    decoded = { tokenIn: address(`0x${words[0]}`), amountIn: BigInt(`0x${words[1]}`).toString(),
      lockDuration: BigInt(`0x${words[2]}`).toString(), recipient: address(`0x${words[3]}`),
      pretransferred: BigInt(`0x${words[4]}`) === 1n, deadline: BigInt(`0x${words[5]}`).toString() };
    check(BigInt(`0x${words[4]}`) === 0n && [ZERO, recipient].includes(decoded.recipient) &&
      tx.value === "0x0", `payer recipient false pretransfer ${locator}`);
    equal(bond.encodeFunctionData("bond", [decoded.tokenIn, decoded.amountIn, decoded.lockDuration,
      decoded.recipient, decoded.pretransferred, decoded.deadline]).toLowerCase(), tx.input, `ABI reencoding ${locator}`);
  } else check(collection === W && tx.to === "0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789" &&
    tx.input.startsWith("0x1fad948c"), `uninterpreted indirect bundle ${locator}`);
  equal(produced.entry.decoded, decoded, `independent decoded comparison ${locator}`);
  equal(produced.entry.actualHistoricalBinding, routed.routes.get(locator) ?? null, `entry binding ${locator}`);
  const events = logs.filter(({ log }) => [DTF, WETH].includes(log.address) && log.topics[0] === TRANSFER).map(({ log, offset }) => {
    check(log.topics.length === 3 && /^0x[0-9a-f]{64}$/.test(log.data), `fixed asset layout ${locator}:${offset}`);
    const from = address(log.topics[1]), to = address(log.topics[2]);
    const classification = from === recipient && to === parent ? "caller-to-purchase-parent" :
      to === recipient ? "inbound-to-acquiring-wallet-not-assumed-refund" :
      from === recipient ? "other-acquiring-wallet-outflow" :
      to === parent ? "routed-or-reserve-parent-inflow-not-second-input" : "other-endpoints-not-caller-input";
    return { asset: log.address, from, to, amountRaw: BigInt(log.data).toString(), logIndex: BigInt(log.logIndex).toString(),
      receiptOffset: offset, classification, rawLocator: `${V28}/actual/archive.json#results[${o.index}].receiptObservation.logs[${offset}]`, log };
  });
  equal(produced.fixedAssetEvents, events, `every fixed-asset log classification ${locator}`);
  const earlier = collection === E, flags = direct ? [] : ["indirect-purchase-or-different-caller"];
  const inflows = events.filter(x => x.asset === DTF && x.to === parent && x.from !== recipient);
  const se = inflows.filter(x => x.from === "0xb7d4bb379d361ad442cddee53ea71a33957826a7");
  const lp = inflows.filter(x => x.from === "0x923877336b14662cfb5b3a60b14e7d716d54a888");
  const sum = es => es.reduce((n, x) => n + BigInt(x.amountRaw), 0n).toString();
  if (earlier) {
    equal(sum(se), f.routed_dtf_received_by_detf_raw, `saved SE-only routed amount ${locator}`);
    equal(inflows.length, se.length + lp.length, `complete earlier routed endpoint partition ${locator}`);
    if (sum(inflows) !== f.routed_dtf_received_by_detf_raw) flags.push("routed-dtf");
  }
  equal(produced.retainedFlags, flags, `independently reconstructed flags ${locator}`);
  equal(historical.conflicts, flags, `old flags preserved ${locator}`);
  equal(produced.retainedQualifications, historical.qualifications, `old qualifications preserved ${locator}`);
  const components = [WETH, DTF].map(asset => {
    const debits = events.filter(x => x.asset === asset && x.from === recipient);
    const inflows = events.filter(x => x.asset === asset && x.to === recipient);
    const primary = direct && asset === decoded.tokenIn;
    const proposedPaidRaw = earlier ? primary ? decoded.amountIn : "0" : null;
    if (earlier) check(inflows.length === 0 && (primary ? debits.length === 1 &&
      debits[0].to === ED && debits[0].amountRaw === decoded.amountIn : debits.length === 0), `source-restricted token payment ${locator}:${asset}`);
    const p = produced.paidComponents.find(x => x.asset === asset);
    equal(p.unit, "native18", `fixed native units ${locator}:${asset}`);
    equal(p.proposedPaidRaw, proposedPaidRaw, `proposed quantity ${locator}:${asset}`);
    equal(p.observedCallerDebits, debits, `all caller debits ${locator}:${asset}`);
    equal(p.observedCallerInflows, inflows, `all caller inflows ${locator}:${asset}`);
    equal(p.state, earlier ? primary ? "evidenced-proposed-paid-input" : "source-and-call-supported-zero" : "unknown", `component meaning ${locator}:${asset}`);
    if (!earlier) check(p.missing.length > 0, `precise unknown ${locator}:${asset}`);
    return { asset, unit: "native18", proposedPaidRaw, observedDebits: debits, observedInflows: inflows,
      affirmativeZeroReason: earlier && !primary ? "Earlier bound bond calls _settleToPair once; false branch pulls only tokenIn. First bond has no other caller leg; downstream calls spend parent capital. Receipt corroborates no other-asset caller debit or inbound token refund. This is token-input zero, not native/lifetime-cost zero." : null };
  });
  const transferWitnesses = data.tables.get("evidence/transfers.csv").filter(x => x.fields.tx.toLowerCase() === tx.hash);
  const details = data.tables.get("../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv").filter(x => x.fields.tx.toLowerCase() === tx.hash);
  equal(produced.originalTransferWitnesses, transferWitnesses, `all S011 witnesses ${locator}`);
  equal(produced.originalS006Witnesses, details, `all S006 witnesses ${locator}`);
  for (const detail of details) {
    const d = detail.fields;
    const match = events.filter(x => x.asset === DTF && x.logIndex === d.log_index &&
      x.from === d.transfer_from.toLowerCase() && x.amountRaw === d.dtf_wei);
    check(match.length === 1 && d.bond_token_id === f.token_id &&
      d.bond_recipient.toLowerCase() === recipient, `exact S006 purchase witness ${detail.locator}`);
  }
  for (const witness of transferWitnesses) {
    const w = witness.fields;
    const matches = logs.filter(({ log }) => BigInt(log.logIndex).toString() === w.log_index &&
      log.address === w.asset.toLowerCase() && log.topics[0] === TRANSFER &&
      address(log.topics[1]) === w.from.toLowerCase() && address(log.topics[2]) === w.to.toLowerCase());
    check(matches.length === 1, `saved Transfer exists ${witness.locator}`);
    equal(BigInt(w.token_id === "" ? matches[0].log.data : matches[0].log.topics[3]).toString(),
      w.token_id === "" ? w.amount_raw : w.token_id, `saved Transfer units ${witness.locator}`);
  }
  const origins = data.tables.get("conversions.csv").filter(x => x.fields.tx.toLowerCase() === tx.hash);
  equal(produced.economicOriginLinks.map(x => x.original), origins, `complete economic-origin membership ${locator}`);
  const originProofs = origins.map(original => {
    const f = original.fields, ar = data.a30.results.find(x => x.tx === tx.hash);
    equal(ar.receiptObservation, result.receiptObservation, `shared canonical receipt ${locator}`);
    equal(ar.transactionObservation, tx, `shared canonical transaction ${locator}`);
    const output = ar.receiptObservation.logs.filter(log => log.address === f.output_asset.toLowerCase() &&
      log.topics[0] === TRANSFER && log.topics.length === 3 && address(log.topics[2]) === f.recipient.toLowerCase() &&
      BigInt(log.data).toString() === f.output_raw);
    check(output.length === 1 && f.recipient.toLowerCase() === W && f.output_decimals === "9" &&
      f.is_external_recovery === "false", `protocol-held conversion output ${original.locator}`);
    equal(f.output_raw, event[2].toString(), `protocol receipt equals recorded bond principal ${original.locator}`);
    const link = produced.economicOriginLinks.find(x => x.original.locator === original.locator);
    equal(link.review, data.r30.find(x => x.locator === original.locator), `conversion review ${original.locator}`);
    check(link.createsAdditionalContribution === false, `no doubled contribution ${original.locator}`);
    return { original, output: output[0], createsAdditionalContribution: false };
  });
  const current = data.current.rows.find(x => x.locator === locator);
  equal(produced.currentOwnerAndPosition.row, current, `separate same-pin state ${locator}`);
  check(produced.currentOwnerAndPosition.pin === "113279837" && data.current.pin === "113279837", `current pin ${locator}`);
  check(produced.originalAcquiringWallet === recipient && produced.actualTopLevelCaller === tx.from &&
    produced.C0 === null && produced.credit === null && produced.priorCompensation === null &&
    produced.eligibility === "unreviewed" && produced.nativeInternalRefunds.startsWith("unknown"), `authority and unknown boundaries ${locator}`);
  const reason = earlier ? "S1" : direct ? "G1" : "G2";
  const disposition = earlier ? "qualified-original-token-inputs-supported" :
    direct ? "unknown-components-historical-purchase-body-gap" : "unknown-components-indirect-purchase-retained";
  equal(produced.disposition, disposition, `independent disposition ${locator}`);
  rows.push({ verdict: "confirmed", reason, original: o.original, sourceId: o.sourceId, collection, tokenId: f.token_id,
    originalAcquiringWallet: recipient, actualTopLevelCaller: tx.from, transaction: tx,
    archive: V28 + "/actual/archive.json", archiveResultIndex: o.index, acceptedRequestIds: result.requestIds,
    mint: mint[0], purchase: purchases[0], purchaseValues: Array.from(event).map(x => x.toString()),
    decoded, historicalBinding: routed.routes.get(locator) ?? null, fixedAssetEvents: events, components,
    savedRoutedDtfRaw: f.routed_dtf_received_by_detf_raw ?? null, seOnlyEvents: se, reserveLpEvents: lp,
    originalTransferWitnesses: transferWitnesses, originalS006Witnesses: details, flags, qualifications: historical.qualifications,
    economicOrigins: originProofs, currentOwner: current.observations.ownerOf, currentPosition: current.observations,
    currentStateEvidence: `${V31}/observations.json#rows[${data.current.rows.indexOf(current)}]`,
    disposition, nativeInternalRefunds: "unknown", eligibility: "unreviewed", financialApproval: false });
}
check(rows.filter(x => x.reason === "G2").map(x => x.tokenId).join(",") === "19,20,23,42", "all four indirects");
check(rows.reduce((n, x) => n + x.flags.length, 0) === 19, "all19 purchase flags");
check(rows.flatMap(x => x.economicOrigins).length === 2, "exactly two economic-origin pairs");
const witnesses = [{ archive: `${ARCH}/earlier-cp/probe-alchemy-retry.source.json`, member: `contracts.${CORE}.sources.UniswapV4SingleStandardExchangeDETFFacet.sol.content`,
  sha256: sha(data.ea.contracts[CORE].sources["UniswapV4SingleStandardExchangeDETFFacet.sol"].content),
  ranges: [[24832, 24844], [24946, 24995], [25021, 25060], [25105, 25124], [25352, 25415], [25786, 25788]] }];
console.log(JSON.stringify({ verdict: "confirmed", scope: "Complete bounded59-reference token-input interpretation only; NON-ISSUABLE",
  counts: { rows: rows.length, earlier: rows.filter(x => x.reason === "S1").length,
    directWeighted: rows.filter(x => x.reason === "G1").length, indirectWeighted: rows.filter(x => x.reason === "G2").length,
    knownZeroComponents: rows.flatMap(x => x.components).filter(x => x.proposedPaidRaw === "0").length,
    unknownComponents: rows.flatMap(x => x.components).filter(x => x.proposedPaidRaw === null).length },
  sourceWitnesses: witnesses, sourceQualification: routed.sourceQualification, rows, historicalRequests: routed.requests,
  checks: counters, inputIdentities: [...identities.values()], findings: [], pendingOperations: 0 }, null, 2));
