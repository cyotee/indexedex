# prepaid-credit-refund-sweep — RESULT

Status: CONFIRMED (mechanism executes on HEAD 2ba07631). Severity: low. The owner documents and accepts this as UNSUPPORTED_USE (D12/D18/D28, IStandardExchangeOut NatSpec), and it only hits a victim who does a non-atomic pretransfer.

Family tested: RebasingAware ERC4626 custody vault (HEAD), using the project's TestBase_RebasingAwareERC4626.
Run: forge test test/apex_audit/prepaid-refund-sweep/PrepaidRefundSweep.t.sol -vvv -> 4/4 PASS

## Setup
- Alice (an honest LP) deposits 500k. The victim contract wallet deposits 100k.
- In tx1 the victim transfers half its shares (worth 50k assets) to the vault, as step 1 of a 2-step pretransferred withdraw.

## Attack
- In tx2 an unprivileged attacker deploys a Sweeper contract. It holds no capital.
- The Sweeper calls `exchangeOut(share, maxAmountIn=uint.max, asset, amountOut=1, self, true, now)`.
- credit = min(selfBal, max) = all resting shares. The vault burns about 1 wei worth of shares and refunds `credit - burned` to msg.sender (RebasingAwareStandardExchangeTarget.sol:136).
- The Sweeper then redeems those shares.

## Results
- Attacker profit: 50,000e18 assets, which is 100% of the resting value. victim loss = 50,000e18. Alice's value delta = 0 (no LP loss).
- The victim's step-2 exchangeOut then reverts.
- Variant: the victim deposits with receiver=vault, which requireReceiver(..,false) allows. The exact-in `exchangeIn(share, resting, asset, 0, attackerEOA, true)` then pays all 50k to the attacker EOA.
- Control: an EOA caller reverts with EOAPretransferNotAllowed. The gate is only a code-size check, so any deployed contract (or an EIP-7702 delegated EOA) passes.
- The `test_control_atomicIntegratorSafe` test proves almost nothing. It only checks that the vault holds no resting shares when no pretransfer was made. It does not exercise an atomic transfer-and-consume.

## Caveats
- This is pure victim-to-attacker theft of value that is resting unbooked. No protocol or LP funds are lost.
- It needs a third party to leave shares on the vault across transactions (a two-step integrator, a multisig, or a misdirected transfer/deposit).
- The live vault 0x2E9C1F70... runs baseline bytecode, which the owner already records as exposed. It was not forked here.
- Other families (Slipstream, Wings, hooks, etc.) were not executed. For AMM token sides, "booked" means the synced reserves, so this is the same as UniV2 skim.

## Fix suggestion
Do not refund the excess credit to msg.sender. Either revert when credit > needed (require an exact pretransfer), or attribute the pretransfer per sender with transient storage (TSTORE) set and consumed in the same transaction.
