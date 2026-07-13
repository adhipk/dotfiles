# unescape-cli adapter module

This module exposes the two commands from the separately managed
`~/projects/unescape-cli` checkout:

- `unescape-buffer` is the Node.js streaming implementation.
- `unescape-string` is the Bash and sed implementation.

The module owns only two path templates, its manifest, documentation, and its
contract test. The parent repository contributes two conditional symlink
adapters under `home/bin`. Disabling the single `modules.unescapeCli` data key
removes both links while preserving the external checkout.

The checkout must exist at `~/projects/unescape-cli`, with both commands under
`bin/`. The dependency bootstrap owns provisioning and pinning that checkout;
this adapter does not copy or modify it. A compatible parent can remove this
module safely after disabling it because the adapters do not evaluate their
in-module path templates while disabled.
