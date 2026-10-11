# Grok — can this PRD be implemented without another owner decision?

- **File judged:** `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md`
- **Answer:** Yes. No requirement in this draft leaves two incompatible implementations where the wrong one recreates an `exchangeIn` self-call or rejects an ordinary holder. The cited source matches the sentences that settle those choices.

## What the text already settles

- Vault-held redemption passes `address(this)` and does not call `exchangeIn`. Legacy V4 inherits `_executeZapOutExactIn` through `UniswapV4StandardExchangeOutBase`, so that path is a direct internal call. V3 vault-held already `delegatecall`s `executeZapOutExactIn` and does not call `exchangeIn`; that shape stays.
- Ordinary redemption passes the original caller and burns that caller. It does not move those shares onto the vault and then set `pretransferred=true`. The base `delegatecall` to `exchangeIn` with `pretransferred=false` stays only where a family override does not flip the flag or external-call `exchangeIn`.
- The `msg.sender == address(this) && !pretransferred` branch in `_secureShareDelivery` is deleted. A real false flag still pulls from the original caller. A real true flag still runs `requirePretransferCaller` and credits only unbooked value. That check is not applied to ordinary redemption.
- The V3 flag-based burn in `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-49` receives a holder argument. That edit is not permission to external-call `exchangeIn` instead.
- `README.md:56` stops describing a proxy self-call. The rest of that README is out of scope.
- A later search hit that externally calls `exchangeIn` from yield redemption uses the same rules. A view `previewExchangeIn` is not that hit. The idle quote at `UniswapV4StandardExchangeInBase.sol:137-139` is therefore not an owner question.

## Residual risks that are not questions

- V3 has two zap-out functions. Ordinary SY currently reaches the exact-in delegate, while the named flag burn is the exact-out delegate. The required outcome still picks one function and a holder argument: ordinary SY passes the original caller into the exact-in settlement, and the exact-out burn also gains a holder so it no longer infers the holder from the flag. Treating the file list as exclusive could send ordinary SY through the exact-out function. That would change quote shape. It would not, by itself, recreate the self-call or the `EOAPretransferNotAllowed` rejection if the flag stays false.
- Adding the holder only on the internal V4 function, and leaving the public four-argument delegate passing `address(this)` after a real pull, preserves existing `exchangeIn`. Changing the public selector is unnecessary. Neither choice is a self-call.
- The ordinary-success test must use a code-less holder. The draft does not say whether that holder has approved the vault. The burn-holder acceptance rules out a pull that then burns the vault. Allowance setup in the test is not an owner decision.
- This draft does not upgrade live instances. That is a stated non-goal, not an open implementation choice.
