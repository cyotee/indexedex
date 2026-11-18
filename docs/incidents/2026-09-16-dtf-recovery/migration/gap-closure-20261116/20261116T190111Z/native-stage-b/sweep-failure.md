# Stage B sweep failure

The owned Anvil stayed at chain 31337 with a 32,000,000 gas limit.

Stage A mined, including the 1 ether owner purchase. Compensation bond 3 and paid bond 4 are owned by the dev account. Cutover timestamp 1802636186 was mined.

The script bundle cannot complete sweepDust inside one 32,000,000-gas call. Two direct sweepDust transactions were mined and both reverted RateProviderFailed():

- 0xf21e2f52d87ba937ae4b5b42bb9258298c96f18b1fc778f0460ca2a5af5fe439 used 31,391,954 of a 31,900,000 limit
- 0xc91925c928944848c78533e66932e55c530bff6a81d2422e5834321ace7a4c79 used 31,483,922 of a 31,999,999 limit

The node ceiling was not raised. Activation and the principal claim did mine. The old donation books were not swept.
