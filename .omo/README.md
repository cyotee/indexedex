# IndexedEx language servers

## TypeScript and JavaScript: project-local

The root dev dependency `typescript-language-server` is pinned to 5.3.0 and
uses the existing TypeScript 5.9.2 compiler. Restore dependencies with the
repository's normal `npm ci` workflow; npm and Yarn lockfiles are maintained.

`.omo/lsp-client.json` selects Native's built-in TypeScript server. Start OmO
from the IndexedEx root so it resolves the project-local executable. Use the
ordinary Native LSP tools.

## Solidity: user-level Foundry registration

At the owner's revised request on 2026-10-24, Solidity is registered in
`~/.omo/lsp-client.json` using `forge lsp --stdio` for `.sol` files. The
existing Foundry installation supplies the language server; no additional
Solidity package or MCP server is required in this repository.

Use Native LSP tools directly for Solidity. Foundry reads the target project's
configuration and remappings. The former project MCP declaration, custom
adapter, adapter tests and adapter-only direct dependencies have been removed.

A fresh OmO Native 5.1.44 session successfully reported an intentional Solidity
type error and resolved IndexedEx's `IFacet` usage through the Crane remapping.
The removed `indexedex-lsp` MCP tools were absent from that session's catalog.
These checks verify the direct integration; they do not establish a maximum
cold-indexing time. The earlier generic-MCP timing issue is not a reason to
restore the removed adapter.

Start a fresh OmO session to discard any previously loaded project MCP tools.
Biome for JSON/CSS is separate and was not added by this setup.
