# kit-tts adapter

This module mounts two commands from the independently distributed
[`kittentts-cli`](https://github.com/adhipk/kittentts-cli) project:

- `kit` converts argument or stdin text to speech with KittenTTS, can write a
  WAV file, and lazily supports Chatterbox as an alternate backend.
- `kit-watch` watches one text file and streams its full contents or appended
  text to `kit` after changes.

The external project owns both implementations, their behavioral tests, and
their standalone install and uninstall lifecycle. This module owns only the
ChezMoi manifest, path templates, conditional `~/bin` symlinks, and parent
integration tests. Bootstrap provisions the checkout at
`~/projects/kittentts-cli`; it does not run the project's standalone installer
or create a second copy under `~/.local`.

Disabling or uninstalling this module removes only `~/bin/kit` and
`~/bin/kit-watch`. It preserves the external checkout, model data, and shared
caches. Once disabled, the module folder itself can be deleted without making
unrelated ChezMoi targets unrenderable.

## Requirements and portability

- `uv` runs the inline Python environment declared by the external `kit`
  command.
- `fswatch` is required only by `kit-watch`.
- The first KittenTTS run may download Python packages and model data.
- Playback currently uses macOS `afplay`; `kit --output FILE` does not require
  playback. Chatterbox adds its own optional package and model requirements.

Hugging Face and uv caches are external shared caches, not module-owned state,
so disable, uninstall, and purge never remove them.

## Standalone distribution

Use the external project's `install.sh` and `uninstall.sh` when installing it
without these dotfiles. Those scripts are deliberately not part of the ChezMoi
integration because the parent already owns the stable `~/bin` links.

Run `tests/test_module.sh` here to exercise the parent adapter's enabled,
disabled, executable-link, and source-removal contracts with a disposable
home. Run the external repository's test suite for command behavior.
