# Apple Release Setup

The repository has two GitHub Actions workflows:

- `iOS CI`: runs tests on every push and pull request.
- `TestFlight Upload`: manually archives the release build and uploads it to App Store Connect.

## Required GitHub Secrets

Add these in GitHub: `Settings` -> `Secrets and variables` -> `Actions`.

| Secret | Value |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID. |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect issuer ID. |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64 encoded contents of the `.p8` API key file. |

To encode the `.p8` key on macOS:

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

## Running A TestFlight Upload

1. Open GitHub Actions.
2. Select `TestFlight Upload`.
3. Click `Run workflow`.
4. Set `upload` to `YES`.

The workflow uses the App Store Connect export method and uploads an internal-only TestFlight build.

## Apple/Xcode Cloud Connection

Xcode Cloud must be connected inside App Store Connect or Xcode with your Apple Developer account. After you connect this GitHub repository there, use the same scheme:

- Project: `Athkariapp.xcodeproj`
- Scheme: `Athkariapp`
- Test command equivalent: `xcodebuild test -project Athkariapp.xcodeproj -scheme Athkariapp`

The GitHub workflow remains useful as an independent CI gate even if Xcode Cloud is enabled.
