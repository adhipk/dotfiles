# Pandoc 3.12.1 source materials: partial, release acceptance blocked

The supplied material contains the complete Pandoc repository snapshot at release tag commit `e51c9c6054c8f4ec5c3209d5abe10939dfe2963e`, plus separate copies of upstream build recipes, package descriptions and license notices. The commit-addressed tar archive has locally measured SHA256 `4aa4cc2d42b149ed39d861fbbb23d636a65f41c4b5ff2ca812e42dfcb502a729`. This pins retrieved bytes; upstream has not supplied that checksum as a source-release attestation. The official binary ZIP digests in the manifest were checked against upstream GitHub release asset digest metadata.

This is useful source/provenance distribution material. It does **not** establish that the complete corresponding source for the shipped statically linked official binaries has been supplied. Public release remains blocked on the missing records below. This document reports engineering evidence and does not give legal assurance.

## Verified primary inputs

- [Release 3.12.1](https://github.com/jgm/pandoc/releases/tag/3.12.1) and [GitHub release metadata](https://api.github.com/repos/jgm/pandoc/releases/tags/3.12.1) identify the release and both binary archive digests.
- [Immutable source commit](https://github.com/jgm/pandoc/tree/e51c9c6054c8f4ec5c3209d5abe10939dfe2963e) includes the library, CLI, Lua engine, server and embedded data files. The whole snapshot is distributed in the materials ZIP, not merely a link or a license file.
- [Tagged macOS build script](https://github.com/jgm/pandoc/blob/e51c9c6054c8f4ec5c3209d5abe10939dfe2963e/macos/make_macos_release.sh) invokes Cabal with embedded data, server, Lua and HTTP enabled, strips the executable, and prepares installation materials. [Tagged macOS Makefile](https://github.com/jgm/pandoc/blob/e51c9c6054c8f4ec5c3209d5abe10939dfe2963e/macos/Makefile) signs and packages it.
- [Release-candidate workflow](https://github.com/jgm/pandoc/blob/e51c9c6054c8f4ec5c3209d5abe10939dfe2963e/.github/workflows/release-candidate.yml) declares Intel macOS, GHC 9.10 and Cabal 3.14 without exact patch versions. Its source text does not establish that this workflow produced either final official ZIP; it does not contain an ARM job.
- [Cabal project](https://github.com/jgm/pandoc/blob/e51c9c6054c8f4ec5c3209d5abe10939dfe2963e/cabal.project) declares local packages and dependency constraints. The build script runs `cabal update`; this checkout has no Cabal freeze, resolved build plan or index-state. `stack.yaml` has a resolver and extra dependencies, but the macOS recipe invokes Cabal, so treating that Stack configuration as an official-binary dependency lock would be unsupported.
- Upstream [COPYING.md](https://github.com/jgm/pandoc/blob/e51c9c6054c8f4ec5c3209d5abe10939dfe2963e/COPYING.md) and [COPYRIGHT](https://github.com/jgm/pandoc/blob/e51c9c6054c8f4ec5c3209d5abe10939dfe2963e/COPYRIGHT) are retained. [GNU GPL version 2, section 3](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) describes source distribution including compilation/installation scripts and source for included modules. A top-level source archive plus notices is insufficient evidence of the binary's complete included-module source closure.

## Associated declared build inputs

`declared-dependencies.json` inventories direct Cabal package declarations and version ranges from all four package descriptions. The exact descriptions are included and the entire repository is available in the accompanying tar archive. The generated inventory is **not** a resolved or transitive dependency list. It may include test/build condition branches; inspecting the full Cabal files remains necessary.

The recipe also depends on the actual GHC/Cabal installation, the chosen Hackage index and package-description revisions, linked Haskell runtime/libraries, Lua/C components, platform toolchain/SDK, and any non-system libraries selected by the resolved build. `otool -L` showing only macOS libraries would not reveal all statically linked components. A successful `--version` and a matching binary archive digest do not recover those missing inputs.

## Exact unresolved evidence

For **both official architecture ZIPs**, obtain the binary digest → build execution → commit/toolchain binding; exact compiler/Cabal/SDK versions; Cabal plan/freeze, index-state and package revisions; full resolved source archives with checksum/license inventory for linked dependencies, including non-system C/Lua components; and compilation/installation instructions tied to that closure. Assemble and review those materials before changing source completeness or the `gpl-corresponding-source` acceptance record.

If upstream cannot provide the missing records, the coherent alternative is to produce our own Pandoc binaries from the pinned release source with an explicitly locked toolchain and fully captured dependency closure, distribute those sources/recipes with them, and rerun packaging, signing and desktop acceptance. That changes the shipped binaries and their provenance; the existing official ZIP pins cannot be carried over.

No upstream maintainer was contacted and no binary rebuild or dependency closure resolution was performed in this task. Public GitHub runs returned for this exact commit during this investigation showed Nightly/docx workflows; none supplied a verified final ARM+Intel release-build binding. Absence from that query is limited evidence, not proof that no private/local build record exists.

## Reproduce the partial material

Run `python3 scripts/assemble-pandoc-source.py` or supply the exact downloaded tar with `--archive PATH`. The script rejects byte/checksum mismatch and existing output destinations, includes all source files in the original archive, copies the verified recipe/notices, records checksums and creates `dist/pandoc-source-materials.zip` plus its SHA256 file. `--require-complete` deliberately fails after assembly while this provenance remains partial. Nothing is installed or published.
