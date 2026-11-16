import { intake, json, OUT, ARCH, V28, V30, V31, CORE, ED, WD, W, DTF, WETH, TRANSFER,
  ZERO, fact, addressWord, table, sha } from "./common.mjs";

const data = await intake();
const observed = await json(`${OUT}/observe-02.stdout`);
const transfers = table(data.input, "evidence/transfers.csv");
const details = table(data.input, "../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv");
const conversions = table(data.input, "conversions.csv");
const rows = [];
const earlierSource = data.ea.contracts[CORE].sources["UniswapV4SingleStandardExchangeDETFFacet.sol"].content;
const sourceWitnesses = [
  { id: "earlier-entry", archive: `${ARCH}/earlier-cp/probe-alchemy-retry.source.json`,
    member: `contracts.${CORE}.sources.UniswapV4SingleStandardExchangeDETFFacet.sol.content`,
    sourceSha256: sha(earlierSource), ranges: [[25352, 25403], [25021, 25035], [25105, 25124],
      [25046, 25060], [24832, 24844], [24946, 24995]],
    reasoning: "Nonpayable bond: one caller token pull; false pulls amountIn and measures delta; true credits reserve surplus without proving payer. Nested SE and reserve spend protocol-held capital, not another caller input. No caller refund branch in this reachable parent path." },
  { id: "weighted-compatible-not-bound", archive: `${ARCH}/weighted/probe.sources.json`,
    member: "0x4886f86cd0dfff8b8a836f858925ed4de3a2b291.sources",
    rangesBySuffix: { "UniswapV4DetfTarget.sol": [[548, 638], [645, 709]],
      "UniswapV4DetfCommon.sol": [[391, 403], [413, 460], [481, 547]] },
    reasoning: "Archived exchange-facet source imports shared target, including internal first-bond multi-leg pulls. ExchangeFacet exposes only exchangeIn, not bond. This is not authentication of the historical purchase facet." },
];
for (const row of data.rows) {
  const f = row.original.fields, tx = row.result.transactionObservation;
  const route = observed.rows.find(x => x.locator === row.original.locator) ?? null;
  const fixedAssetEvents = row.result.receiptObservation.logs.flatMap((log, offset) => {
    if (![DTF, WETH].includes(log.address) || log.topics[0] !== TRANSFER) return [];
    fact(log.topics.length === 3 && /^0x[0-9a-f]{64}$/.test(log.data), `ERC20 layout: ${tx.hash}:${offset}`);
    const from = addressWord(log.topics[1]), to = addressWord(log.topics[2]);
    let classification = "other-endpoints-not-caller-input";
    if (from === row.recipient && to === row.parent) classification = "caller-to-purchase-parent";
    else if (to === row.recipient) classification = "inbound-to-acquiring-wallet-not-assumed-refund";
    else if (from === row.recipient) classification = "other-acquiring-wallet-outflow";
    else if (to === row.parent) classification = "routed-or-reserve-parent-inflow-not-second-input";
    return [{ asset: log.address, from, to, amountRaw: BigInt(log.data).toString(),
      logIndex: BigInt(log.logIndex).toString(), receiptOffset: offset, classification,
      rawLocator: `${V28}/actual/archive.json#results[${row.resultIndex}].receiptObservation.logs[${offset}]`, log }];
  });
  const components = [WETH, DTF].map(asset => {
    const debit = fixedAssetEvents.filter(x => x.asset === asset && x.from === row.recipient);
    const refund = fixedAssetEvents.filter(x => x.asset === asset && x.to === row.recipient);
    return { asset, unit: "native18", proposedPaidRaw: null, state: "unknown",
      observedCallerDebits: debit, observedCallerInflows: refund,
      missing: row.direct ? ["historical-purchase-implementation-not-authenticated"] : ["indirect-inner-invocation-and-payer-not-authenticated-by-this-lane"] };
  });
  const earlierSupported = row.parent === ED && row.direct && route?.canonicalHeaderMatches &&
    route.proxyMatches && route.loupeMatches && route.facet === CORE && route.facetMatches && route.pairToken === DTF;
  if (earlierSupported) {
    fact([DTF, WETH].includes(row.decoded.tokenIn), `unexpected earlier input: ${row.original.locator}`);
    for (const component of components) {
      const primary = component.asset === row.decoded.tokenIn;
      fact(component.observedCallerInflows.length === 0, `possible refund requires review: ${row.original.locator}`);
      fact(primary ? component.observedCallerDebits.length === 1 &&
        component.observedCallerDebits[0].to === ED &&
        component.observedCallerDebits[0].amountRaw === row.decoded.amountIn :
        component.observedCallerDebits.length === 0, `caller payment mismatch: ${row.original.locator}`);
      component.proposedPaidRaw = primary ? row.decoded.amountIn : "0";
      component.state = primary ? "evidenced-proposed-paid-input" : "source-and-call-supported-zero";
      component.missing = [];
      component.reasoning = primary ?
        "Historical bound nonpayable bond calls _settleToPair -> _pullToken(false) once for tokenIn/amountIn. Exact caller-to-parent Transfer matches; no acquiring-wallet token inflow/refund. Nested capital and LP settlement are not paid again." :
        "Historical bound entry pulls only the other named input token once; pretransferred=false, no first-bond other-leg pull in this generation, no caller native-value or wrapping branch. Complete receipt has no debit/inflow in this component; zero is supported by that source/call restriction, not the empty log list alone.";
      component.sourceWitnesses = ["earlier-entry"];
    }
  }
  const originalClaimLinks = conversions.filter(x => x.fields.tx.toLowerCase() === tx.hash).map(original => {
    const review = data.r30.find(x => x.locator === original.locator);
    fact(review && review.conflicts.length === 0, `conversion join: ${original.locator}`);
    return { original, review, role: "protocol-held-funded-bond-backing-not-second-purchase-contribution",
      economicOrigin: `${row.collection}:${f.token_id}:${tx.hash}`, createsAdditionalContribution: false };
  });
  const state = data.state.rows.find(x => x.locator === row.original.locator);
  fact(state, `same-pin state missing: ${row.original.locator}`);
  rows.push({
    status: "NON-ISSUABLE-REVIEW-OBSERVATION", chainId: 4663,
    key: `4663:${row.collection}:${f.token_id}`, sourceId: row.sourceId, collection: row.collection,
    tokenId: f.token_id, original: row.original,
    sourceCutoff: data.input.sources.evidenceCutoff,
    historical: { transaction: tx, archive: `${V28}/actual/archive.json`, archiveResultIndex: row.resultIndex,
      requestIds: row.result.requestIds, mint: row.mint, sourceEvents: row.review.sourceEvents,
      receipt: row.result.receiptObservation },
    entry: { direct: row.direct, selector: tx.input.slice(0, 10), decoded: row.decoded,
      exactReencoded: row.direct, actualHistoricalBinding: route,
      interpretation: earlierSupported ? "authenticated-earlier-bond" :
        row.direct ? "bond-shaped-static-call-deployed-purchase-body-unbound" : "outer-bundle-not-interpreted" },
    originalAcquiringWallet: row.recipient, actualTopLevelCaller: tx.from,
    currentOwnerAndPosition: { pin: data.state.pin, evidence: `${V31}/observations.json`, row: state },
    futureSurrenderControl: "requires-configured-original-wallet-and-actual-control-at-surrender-not-approved-here",
    paidComponents: components, nativeTopLevelValueRaw: BigInt(tx.value).toString(),
    nativeInternalRefunds: "unknown-not-derived-from-WETH-event-layout-or-outer-value",
    fixedAssetEvents, originalTransferWitnesses: transfers.filter(x => x.fields.tx.toLowerCase() === tx.hash),
    originalS006Witnesses: details.filter(x => x.fields.tx.toLowerCase() === tx.hash),
    economicOriginLinks: originalClaimLinks,
    retainedFlags: row.review.conflicts, retainedQualifications: row.review.qualifications,
    routedFlagMeaning: row.parent === ED && row.review.conflicts.includes("routed-dtf") ?
      "broader-nonpayer-parent-inflow-versus-saved-SE-only-routed-component-not-erroneous-saved-field" : null,
    savedRoutedDtfRaw: f.routed_dtf_received_by_detf_raw ?? null,
    eligibility: "unreviewed", priorCompensation: null, credit: null, C0: null,
    disposition: earlierSupported ? "qualified-original-token-inputs-supported" :
      row.direct ? "unknown-components-historical-purchase-body-gap" : "unknown-components-indirect-purchase-retained",
  });
}
fact(rows.length === 59 && rows.reduce((n, r) => n + r.retainedFlags.length, 0) === 19, "59 rows / 19 flags");
fact(rows.flatMap(x => x.economicOriginLinks).length === 2, "two NFT/protocol-conversion pairs");
console.log(JSON.stringify({ version: "phase32-qualified-purchase-inputs-v1", status: "NON-ISSUABLE-REVIEW-OBSERVATIONS",
  scope: "59 named purchases only; no financial approval, allocation, native-history completeness or full-plan acceptance",
  sourceWitnesses, rows, counts: { weighted: rows.filter(x => x.sourceId === "S008").length,
    earlier: rows.filter(x => x.sourceId === "S009").length, direct: rows.filter(x => x.entry.direct).length,
    supported: rows.filter(x => x.disposition === "qualified-original-token-inputs-supported").length,
    flags: rows.reduce((n, x) => n + x.retainedFlags.length, 0), originPairs: rows.flatMap(x => x.economicOriginLinks).length },
  inputBindings: data.bindings, frozenDeclarations: data.input.bindings,
  historicalRoutingCapture: `${OUT}/observe-02.stdout` }, null, 2));
