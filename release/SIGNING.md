# Signing credentials for the release candidate

The release is prepared without credentials. Development builds are ad-hoc signed;
they are not notarized public candidates. Create the stable tag only after the
acceptance gate passes.

## GitHub Actions

The `Signed release candidate` workflow uses the `release-signing` environment.
Add these environment secrets when the certificate is available:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64 of an exported Developer ID Application certificate and its private key |
| `DEVELOPER_ID_P12_PASSWORD` | Export password for that certificate |
| `DEVELOPER_ID_IDENTITY` | Exact `Developer ID Application: …` identity |
| `NOTARY_APPLE_ID` | Apple account permitted to notarize for the team |
| `NOTARY_APP_PASSWORD` | App-specific password for that account |
| `APPLE_TEAM_ID` | Developer team identifier |

Supply secrets through GitHub settings, never through repository files or PR text.
The workflow imports the certificate into a temporary keychain, masks its generated
password, notarizes each architecture, and removes the keychain afterward. It
uploads candidate artifacts and does not publish a release. Supply the full
validated source commit and the source-build artifact input described by the
workflow; both CI tiers must have passed for that exact candidate commit.

## Local candidate

Import the certificate into Keychain and create a notarytool Keychain profile.
Pass its name through `DOTFILES_NOTARY_PROFILE`; the script uses that existing
profile and does not store credentials in source. Build with
`python3 scripts/build-app.py --sign 'Developer ID Application: …'` and the
reviewed Pandoc source artifact, then run `make release-candidate-check` before
`bash scripts/notarize-app.sh`.

Signing does not replace desktop acceptance. Complete [ACCEPTANCE.md](ACCEPTANCE.md)
on clean Macs for both distributed architectures, then run the final
`make release-verify` with those records and both candidate artifact directories.
