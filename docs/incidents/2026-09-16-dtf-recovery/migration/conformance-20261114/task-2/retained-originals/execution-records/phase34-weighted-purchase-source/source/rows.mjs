import { dirname } from "node:path";
import { P32, WETH, DTF, PARENT, NFT, FACET, ZERO, TRANSFER, Interface, id,
  check, equal, address, wire, counts, keccak256 } from "./evidence.mjs";

const loupe = new Interface(["function facetAddress(bytes4) view returns(address)"]);
const purchased = new Interface(["event BondPurchased(uint256 indexed tokenId,address indexed recipient,uint256 principal,uint256 startTimestamp,uint256 vestingDuration)"]);
const liveTopic = id("ReserveLive(uint256,uint256)");
const hook = "0x46e068c2393e189fbc86632f67210af253a42aa8";
const staking = "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c";
const source = "recovered-package.json#/sources/";
const target = "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol";
const common = target.replace("Target", "Common");
const locators = {
  entry: `${source}${target}/content:548-578`,
  leading: `${source}${target}/content:618-638`,
  fullBook: `${source}${target}/content:645-684`,
  otherPayment: `${source}${target}/content:836-842`,
  pull: `${source}${common}/content:391-403`,
  nested: `${source}${common}/content:413-460`,
  principal: `${source}${target}/content:597-616,699-709`,
  dust: `${source}${common}/content:481-547,551-682`,
};

async function historical(data, row) {
  const retained = data.observed32.rows.find(x => x.locator === row.original.locator);
  check(retained, `historical row ${row.tokenId}`);
  const actual = {};
  const witnesses = [];
  for (const key of ["header", "proxy", "loupeRoute", "loupeCode", "route", "facetCode"]) {
    const e = data.hm32.find(x => x.id === retained.requests[key]);
    check(e, `historical capture ${key}`);
    actual[key] = await wire(e, `${P32}/source`);
    witnesses.push({ role: key, ...e });
    equal(e.params.at(-1), key === "header" ? false : row.transaction.blockNumber, `numeric historical pin ${key}`);
  }
  const entries = Object.fromEntries(witnesses.map(e => [e.role, e]));
  equal(entries.header.params, [row.transaction.blockNumber, false], "header numeric params");
  equal(actual.header.hash, row.transaction.blockHash, "historical header hash");
  equal(actual.header.transactions[Number(BigInt(row.transaction.transactionIndex))], row.transaction.hash, "historical block membership");
  equal(entries.proxy.params, [PARENT, row.transaction.blockNumber], "proxy code request");
  equal(keccak256(actual.proxy), "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601", "accepted proxy code");
  equal(entries.loupeRoute.params, [{ to: PARENT, data: loupe.encodeFunctionData("facetAddress", ["0xcdffacc6"]) }, row.transaction.blockNumber], "loupe route request");
  const loupeAddress = address(actual.loupeRoute);
  equal(loupeAddress, "0x343590ed92498739225e351c27133bc2c11b91b9", "accepted loupe address");
  equal(entries.loupeCode.params, [loupeAddress, row.transaction.blockNumber], "loupe code request");
  equal(keccak256(actual.loupeCode), "0x4ec4e7a53c6dac358a2d8af7dab6581dfd26f01fc76d02333d7caec7a44a39f4", "accepted loupe bytes");
  equal(entries.route.params, [{ to: PARENT, data: loupe.encodeFunctionData("facetAddress", ["0x7a3b1181"]) }, row.transaction.blockNumber], "bond route request");
  equal(address(actual.route), FACET, "actual purchase facet");
  equal(entries.facetCode.params, [FACET, row.transaction.blockNumber], "facet code request");
  equal(actual.facetCode, data.pkg.runtimeBytecode.onchainBytecode, "complete historical runtime equals published runtime");
  return { numericBlock: row.transaction.blockNumber, blockHash: row.transaction.blockHash,
    facet: FACET, runtimeKeccak256: keccak256(actual.facetCode), witnesses,
    qualification: "selected block-end routes, not transaction-prefix or universal transitive execution proof" };
}

async function canonical(data, result) {
  const responses = [];
  const entries = [];
  for (const reqId of result.requestIds) {
    const e = data.hm28.find(x => x.id === reqId);
    check(e, `accepted request ${reqId}`);
    entries.push(e);
    responses.push(await wire(e, `${dirname(data.p28)}/http`));
  }
  const [tx, receipt, byHash, byNumber] = responses;
  equal(entries.map(e => e.method), ["eth_getTransactionByHash", "eth_getTransactionReceipt", "eth_getBlockByHash", "eth_getBlockByNumber"], "accepted canonical method order");
  equal(entries.map(e => e.params), [[result.tx], [result.tx], [tx.blockHash, false], [tx.blockNumber, false]], "accepted canonical parameters");
  equal(tx, result.transactionObservation, "raw transaction");
  equal(receipt, result.receiptObservation, "raw complete receipt");
  equal(byHash, byNumber, "canonical header equality");
  equal(receipt.status, "0x1", "purchase success");
  equal(tx.hash, result.tx, "transaction hash");
  for (const key of ["blockHash", "blockNumber", "transactionIndex", "from", "to"])
    equal(tx[key], receipt[key], `transaction receipt ${key}`);
  equal(receipt.transactionHash, tx.hash, "receipt transaction");
  equal(byHash.hash, tx.blockHash, "block hash");
  equal(byHash.number, tx.blockNumber, "block number");
  equal(byHash.transactions[Number(BigInt(tx.transactionIndex))], tx.hash, "exact block membership");
  check(byHash.transactions.filter(x => x === tx.hash).length === 1, "unique member");
  let priorIndex = -1n;
  for (const log of receipt.logs) {
    counts.receiptLogs++;
    for (const key of ["blockHash", "blockNumber", "transactionIndex"]) equal(log[key], tx[key], `log ${key}`);
    equal(log.transactionHash, tx.hash, "log transaction");
    check(log.removed === false && BigInt(log.logIndex) > priorIndex, "complete ordered log");
    priorIndex = BigInt(log.logIndex);
    check(/^0x[0-9a-f]{40}$/.test(log.address) && /^0x([0-9a-f]{2})*$/.test(log.data), "log address/data");
    check(log.topics.every(x => /^0x[0-9a-f]{64}$/.test(x)), "log topics");
  }
  return { tx, receipt, acceptedRawWitnesses: entries };
}

export async function derive(data) {
  const originals = data.tables.get("evidence/weighted-bonds.csv");
  equal(originals.length, 43, "complete S008");
  equal(data.tables.get("evidence/earlier-cp-bonds.csv").length, 16, "complete S009 context");
  const direct = [], indirect = [];
  for (const original of originals) {
    const f = original.fields, tokenId = f.token_id;
    const prior = data.prior.rows.find(x => x.sourceId === "S008" && x.tokenId === tokenId);
    check(prior, `prior row ${tokenId}`);
    equal(original.fields, prior.original.fields, `all original fields ${tokenId}`);
    const index = data.a28.results.findIndex(x => x.tx === f.purchase_tx);
    const result = data.a28.results[index];
    check(result && result.conflicts.length === 0, "accepted unique purchase");
    const { tx, receipt, acceptedRawWitnesses } = await canonical(data, result);
    equal(tx.blockNumber, `0x${BigInt(f.purchase_block).toString(16)}`, "original block");
    const payer = f.purchase_recipient.toLowerCase();
    const logs = receipt.logs.map((log, receiptOffset) => ({ log, receiptOffset }));
    const mint = logs.filter(x => x.log.address === NFT && x.log.topics[0] === TRANSFER &&
      x.log.topics.length === 4 && address(x.log.topics[1]) === ZERO && BigInt(x.log.topics[3]).toString() === tokenId);
    check(mint.length === 1 && address(mint[0].log.topics[2]) === payer, "unique correct mint");
    const purchases = logs.filter(x => x.log.address === NFT && x.log.topics[0] === purchased.getEvent("BondPurchased").topicHash);
    check(purchases.length === 1, "one purchase, no repeated purchase action");
    const decodedEvent = purchased.decodeEventLog("BondPurchased", purchases[0].log.data, purchases[0].log.topics);
    equal([decodedEvent[0], decodedEvent[2], decodedEvent[3], decodedEvent[4]].map(String),
      [tokenId, f.original_principal_detf_raw, f.start_timestamp, f.duration_seconds], "purchase event terms");
    equal(decodedEvent[1].toLowerCase(), payer, "purchase recipient");
    if (tx.to !== PARENT || tx.from !== payer || tx.input.slice(0, 10) !== "0x7a3b1181") {
      equal(prior.reason, "G2", "indirect boundary");
      indirect.push({ tokenId, original, priorDisposition: prior.disposition, proposedWeth18: null, proposedDtf18: null,
        flags: prior.flags, transaction: tx, mint: mint[0], purchase: purchases[0], acceptedRawWitnesses,
        reason: "G2 unchanged; no bundle decoding, payer-authority experiment or phase29 retry" });
      continue;
    }
    check(tx.input.length === 394 && tx.value === "0x0", "six words and no outer value");
    const decoded = data.abi.decodeFunctionData("bond", tx.input);
    equal(data.abi.encodeFunctionData("bond", decoded).toLowerCase(), tx.input, "exact ABI round trip");
    const words = tx.input.slice(10).match(/.{64}/g);
    equal(address(`0x${words[0]}`), decoded[0].toLowerCase(), "independent input address");
    equal(BigInt(`0x${words[1]}`).toString(), decoded[1].toString(), "independent input amount");
    check(decoded[4] === false && BigInt(`0x${words[4]}`) === 0n, "false pretransfer");
    check(decoded[3].toLowerCase() === payer || decoded[3].toLowerCase() === ZERO, "resolved recipient");
    const transfers = logs.filter(x => x.log.topics[0] === TRANSFER && x.log.topics.length === 3).map(x => ({
      asset: x.log.address, from: address(x.log.topics[1]), to: address(x.log.topics[2]),
      amountRaw: BigInt(x.log.data).toString(), logIndex: BigInt(x.log.logIndex).toString(), ...x }));
    const fixed = transfers.filter(x => [WETH, DTF].includes(x.asset));
    const debits = fixed.filter(x => x.from === payer);
    const inflows = fixed.filter(x => x.to === payer);
    check(inflows.length === 0 && debits.every(x => x.to === PARENT), "complete wallet payment/refund scope");
    const lead = debits.filter(x => x.asset === decoded[0].toLowerCase() && x.amountRaw === decoded[1].toString());
    check(lead.length === 1 && [WETH, DTF].includes(decoded[0].toLowerCase()), "one exact leading caller payment");
    const live = logs.filter(x => x.log.address === PARENT && x.log.topics[0] === liveTopic);
    const first = live.length === 1;
    check(live.length <= 1 && (first ? tokenId === "3" && debits.length === 2 : debits.length === 1), "first/ordinary payment scope");
    if (first) {
      equal(live[0].log.topics.length, 1, "ReserveLive event ABI");
      equal(BigInt(`0x${live[0].log.data.slice(2, 66)}`).toString(), tokenId, "ReserveLive first ID");
      const extra = debits.find(x => x !== lead[0]);
      check(extra.asset === DTF && extra.amountRaw === "362893857600000000000", "actual extra DTF, never zero");
      for (const debit of debits) check(fixed.some(x => x.from === PARENT && x.to === hook && x.asset === debit.asset && x.amountRaw === debit.amountRaw), "each actual first payment forwarded to reserve");
    }
    const savedTransfers = data.tables.get("evidence/transfers.csv").filter(x => x.fields.tx === tx.hash);
    for (const s of savedTransfers) {
      const sf = s.fields, hit = logs.find(x => BigInt(x.log.logIndex).toString() === sf.log_index && x.log.address === sf.asset);
      check(hit && hit.log.topics[0] === TRANSFER, `S011 witness ${s.locator}`);
      equal(address(hit.log.topics[1]), sf.from, "saved from"); equal(address(hit.log.topics[2]), sf.to, "saved to");
      equal(hit.log.topics.length === 4 ? BigInt(hit.log.topics[3]).toString() : BigInt(hit.log.data).toString(), sf.token_id || sf.amount_raw, "saved units");
    }
    const savedS006 = data.tables.get("../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv").filter(x => x.fields.tx === tx.hash);
    equal(savedS006.map(x => ({ locator: x.locator, fields: x.fields })),
      prior.originalS006Witnesses.map(x => ({ locator: x.locator, fields: x.fields })), "all S006 original witnesses");
    for (const s of savedS006) {
      const sf = s.fields, hit = fixed.find(x => x.logIndex === sf.log_index);
      check(hit && hit.asset === DTF && hit.from === sf.transfer_from.toLowerCase() && hit.amountRaw === sf.dtf_wei, `S006 payment ${s.locator}`);
      equal(sf.bond_token_id, tokenId, "S006 NFT identity");
    }
    const components = [WETH, DTF].map(asset => {
      const events = debits.filter(x => x.asset === asset);
      const raw = events.reduce((s, x) => s + BigInt(x.amountRaw), 0n).toString();
      return { asset, unit: "native18", proposedCallerPaidRaw: raw, events, observedTokenRefunds: [],
        role: events.length ? (asset === lead[0].asset ? "leading-priced-bond-payment" : "first-full-book-other-leg-protocol-capital") : "no-caller-payment-on-live-one-pull-path",
        affirmativeZeroReason: events.length ? null : { source: locators, completeCalldata: tx.input,
          reason: "No ReserveLive on successful source-bound purchase excludes first branch; live non-LP path has exactly one caller pull. Nested approvals spend parent assets. Complete receipt has no other-asset caller debit or inflow." },
        approvedOriginalCapitalRaw: null };
    });
    const row = { tokenId, original, payer, paymentRecipient: PARENT, transaction: tx, archive: data.p28, archiveResultIndex: index,
      acceptedRawWitnesses, mint: mint[0], purchase: purchases[0], completeReceipt: receipt, calldataWords: words,
      decoded: { tokenIn: decoded[0].toLowerCase(), amountIn: decoded[1].toString(), duration: decoded[2].toString(),
        recipient: decoded[3].toLowerCase(), pretransferred: false, deadline: decoded[5].toString() },
      branch: first ? "first-full-book" : "live-ordinary", reserveLive: live, components, fixedAssetTransfers: fixed,
      protocolTokenTransfers: transfers.filter(x => x.asset === PARENT || x.asset === staking || x.asset === hook),
      originalTransferWitnesses: savedTransfers, originalS006Witnesses: savedS006,
      flags: prior.flags, priorQualifications: prior.qualifications, economicOrigins: prior.economicOrigins,
      currentOwner: prior.currentOwner, currentPosition: prior.currentPosition, currentStateEvidence: prior.currentStateEvidence,
      sourceLocators: locators, originalCostDtf18: null, originalCostWeth18: null,
      nativeInternalRefunds: null, netOriginalCapital: null, priorCompensation: null, approvedE0: null, approvedD0: null, approvedC0: null,
      financialApproval: false, eligibility: null,
      limits: "Gross caller-paid token observations only. No approved NFT cost, native net cost, prior-credit or descendant-control inference." };
    row.historicalBinding = await historical(data, row);
    direct.push(row);
  }
  equal(direct.length, 39, "39 direct rows");
  equal(indirect.map(x => x.tokenId), ["19", "20", "23", "42"], "four G2 unchanged");
  return { direct, indirect, earlierUnchanged: data.earlier.rows.filter(x => x.sourceId === "S009") };
}
