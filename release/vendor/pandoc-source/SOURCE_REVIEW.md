# Own ARM source capture review

The isolated ARM build completed in 943 seconds on macOS 15.7.7 with GHC 9.10.3, Cabal 3.14.2.0, Xcode 16.4 build 16F6 and SDK 15.5. It used unchanged Pandoc commit `e51c9c6054c8f4ec5c3209d5abe10939dfe2963e`, selected Hackage revisions and disabled repositories for final compilation.

Raw binary SHA256: `e69153bb7dcdeba9328c492b9857fa16465f2a612a52529ae24a78c74ca15b9a`.

Source distribution SHA256: `a2cc065cc5d816e173e548e50a032730e3c09639f8e08f2a68cc4fda5e946237` (`pandoc-own-source-arm64.zip`). These identify this local execution, not future remote builds. Absolute paths/build metadata can cause rebuilt artifact hashes to differ.

Standalone validation passed: ARM architecture, macOS minimum 13.0, only macOS system dylibs, correct version and HTML→GFM conversion with temporary HOME and system-only PATH. No GHC installation is needed to run that binary. The root development app packaging step separately verifies the raw bytes, signs its copied dependency and records the signed-byte digest.

## Captured source coverage

All 234 original planned Hackage source tarballs and selected `.cabal` files were hash-checked against the secure plan, with original plan/freeze and final local plan/freeze retained. The full pinned compiler source covers the 28 observed boot package names/versions and includes GMP 6.3.0 and libffi 3.4.6 source archives. The runtime inventory identifies C/Lua source in 35 Hackage archives. GPL-declared skylighting 0.15 and texmath 0.13.3.1 retain full upstream LICENSE files; the complete Pandoc source includes its GPL/COPYRIGHT material.

The captured declarations contain BSD3/BSD-3-Clause, BSD2/BSD-2-Clause, MIT, ISC, Apache-2.0 and GPL-2 labels. Captured source archives retain all upstream files, not just declarations. This is an engineering source inventory and does not provide blanket legal assurance. Both architecture artifacts still need remote execution binding and reviewed source/license acceptance before publication.

## Explicit notice gap: erf 2.0.0.0

[Primary Hackage package](https://hackage-content.haskell.org/package/erf-2.0.0.0) and its uploaded source package declare BSD-3-Clause/BSD3. The exact captured archive hash is `24f0b79c7e1d25cb2cd44c2258d7a464bf6db8079775b50b60b54a254616b337`; selected `.cabal` hash is `11c5d3747d17b589009cbe9656ca792e4b5b2560d4aa44f6f1e80044794b1a8b`.

The complete archive contains only `Setup.hs`, `erf.cabal` and `src/Data/Number/Erf.hs` (plus directories). Its metadata names Lennart Augustsson as **Author** and **Maintainer**, but supplies no `copyright`, `license-file`, homepage or source-repository field. Neither source file includes a copyright/license notice. No primary repository/tag with a full notice was identified in this investigation; the guessed `augustss/erf` endpoint returned 404. That failed guess does not prove no repository exists.

Do not turn the Author field into an invented copyright statement or substitute an arbitrary third-party distribution notice. Retain the exact metadata/source and record this specific missing upstream full notice/copyright in source/license review. Clarification from the upstream copyright holder or a documented professional release decision remains necessary to close notice acceptance. No maintainer message has been sent.

## Happy library supplement

`happy-lib-2.2` declares BSD-2-Clause and copyright `(c) Andy Gill, Simon Marlow`, without a separate license-file in its source tar. The same captured 2.2 release also includes `happy-2.2/LICENSE` with the complete Happy license and its additional GLR copyright notices. That file's SHA256 is `079dc8e9d7f062d789196fd8733ee252ebadeb265726f70fef14753b52432bbc`; it is included at `closure/licenses/happy-2.2/LICENSE` in the source distribution.

The Happy source archive hash is `2e9345c99a61bc29b5a1b9d5c1ea791cbea219499a4c01ed71f33c3af34a5eb0`; happy-lib source archive hash is `d2e0662b12b52008787c380b94acd4f6ed0a0af04bb0d433ed8c4ac00f1e3003`. This supplement preserves actual upstream text and attribution; no notice text was invented.
