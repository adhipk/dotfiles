# Third-party distribution notices

Original Dotfiles host, SDK, and repository code is licensed under Apache-2.0.
The root LICENSE and NOTICE are distributed with the native app. Existing files
with their own copyright/license notices keep those notices and terms.

## Native distribution

- The Swift host, service runner, author CLI, and Markdown clipboard worker are
  built from this repository using Apple's Swift toolchain and macOS frameworks.
  System frameworks remain provided by macOS; this app does not redistribute macOS.
- Pandoc is an independent executable included in the Markdown utility package.
  Its GPL license, upstream copyright notices, version, checksums, download/source
  provenance accompany the generated package. Source download links are included;
  the source assembly script produces a separate checksummed distribution archive.
  The exact linked dependency/toolchain closure is not yet attested. See
  release/vendor/pandoc-source/SOURCE_PROVENANCE.md for primary-source findings. Its license
  does not change the license of this repository's original code. Before public
  distribution the release acceptance record must document review of the full
  corresponding-source requirements for the actual binary and dependencies.
  Downloading the Pandoc source archive alone is not proof of that review.

## Desktop integration distribution

Homebrew packages and pinned utility projects are installed from their upstream
sources rather than copied into the native app. Each upstream project owns its
license, releases, and notices. The consumer profile and dependency manifest
identify requested projects and versions. Review those manifests and existing
configuration licenses before accepting the public release license gate.

The native app ships local executable adapters, not copies of yabai, skhd,
Ghostty, tmux, Tuxedo, Kit TTS, Yazi, Neovim, or other external tools. Optional
consumer profile installation obtains these separately and preserves their
upstream licenses and notices. Repository configuration includes Neovim and
skill files with separate license notices; retain their original notices.

This inventory records distribution boundaries. The clean-device release
acceptance document records completed third-party license/source review.
