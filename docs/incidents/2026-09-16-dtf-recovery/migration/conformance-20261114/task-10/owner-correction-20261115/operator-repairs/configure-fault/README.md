# Configure post-mining interruption repair

This directory contains fresh repair evidence. The manual channel uses the
existing execution fixture behind a local transport adapter. It executes the
production CLI, signer, subscription, receipt authentication and journal.
Transport receipts are synthetic fixture facts, not Anvil or historical chain
proof. Task 10 must still supply its resumed real-chain interruption witness.

Each attempt retains the command, output, exit and source fingerprints.
Earlier failures remain evidence.
