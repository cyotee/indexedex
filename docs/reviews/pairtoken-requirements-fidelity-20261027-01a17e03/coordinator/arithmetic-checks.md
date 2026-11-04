# Coordinator arithmetic checks

Exact BigInt arithmetic only; no compiled target, project tests or runtime calls. These checks are not exhaustive equivalence proof.

{
  "spacing60": [
    "-887220",
    "887220"
  ],
  "pairedQuote": [
    "333",
    "100",
    "234"
  ],
  "zapCap": "1000",
  "zapMeasuredHalf": "499",
  "payout": "999",
  "liquidityOut": "4995",
  "idle": [
    "10",
    "9"
  ],
  "protocol": [
    "250",
    "125"
  ],
  "feeAbove100pct": {
    "fees": "100",
    "rate": "20000",
    "attempt": "200",
    "reservation": "1000",
    "balanceAfter": "900"
  }
}

Genesis: floor(sqrt(2000*2000)) = 2000 exactly, split into 1000 dead shares and 1000 recipient shares.

The fee-above-100-percent example has balanceAfter 900 and reservation 1000; checked idle subtraction would underflow, causing transaction rollback on that path. No deployed fee rate or reachability is asserted.

