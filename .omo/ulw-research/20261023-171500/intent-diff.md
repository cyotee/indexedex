# Intent diff

| intent_id | expected truth | observed reality | diff | violated invariant | intent source | supporting observations | status | claims |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | A two-token fee-earning position cannot become one token without a swap or an external price | unknown | open | single-token quote | user goal 2026-10-23 | none yet | unknown | |
| E2 | A view rate that reads same-pool spot can be moved inside the deposit transaction | unknown | open | rate must not be spot-manipulable | APEX-2026-012 discussion | none yet | unknown | |
| E3 | Production vaults exist with ERC-20 shares and a documented NAV | scoping search names Arrakis, Gamma, ICHI, Charm, Steer | not yet read from primary docs | primary-source backing | user search request | O1 | unknown | |
| E4 | ICHI quotes a conservative share price rather than spot liquidation | not yet read | open | quote basis | prior thread summary | none yet | unknown | |
| E5 | Bunni v2 was exploited and is not a live pattern | not yet read from a postmortem | open | do not recommend a dead design | prior thread summary | none yet | unknown | |
