# Uniswap V3 Standard Exchange — Adversarial Test Plan

Living checklist for plan §10 P0/P1.

| ID | Theme | Status |
|----|-------|--------|
| A1 | Donation idle inventory | covered |
| A3 | Fee donation timing | covered |
| B1 | Spot manip | covered |
| C1 | Reentrancy exchangeIn | covered |
| C2 | Reentrancy exchangeOut | covered |
| C3 | Reentrancy import | covered |
| C4 | Callback reentry | covered |
| D1 | Callback spoof | covered |
| D2 | Import without auth | covered |
| D3 | Import wrong pool | covered |
| D4 | Second import | covered |
| E1 | Round-trip conservation | covered |
| E2 | Zero / deadline | covered |
| E3 | Slippage atomic | covered |
| E4 | Residual free inventory | covered |
| F1 | Disable | covered |
| F2 | Factory spoof | covered |
| H1 | Extreme width | covered |
| H2 | Zero liq import | covered |
| H3 | Empty NFT second import | covered |
