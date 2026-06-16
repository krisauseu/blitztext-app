# Blitztext App (Offline-First Fork)

This is a modified fork of the original [Blitztext App by cmagnussen](https://github.com/cmagnussen/blitztext-app). 

In this version, **all speech transcription has been moved entirely offline** to maximize speed and eliminate API latency on Apple Silicon Macs. The optional OpenAI API is now exclusively used for smart text transformations and translations.

## What It Does

- **Blitztext**: Record speech and transcribe it 100% locally using WhisperKit/CoreML.
- **Blitztext+**: Record speech, transcribe it locally, then use an LLM API to clean up the rough draft.
- **Blitztext Translate (New)**: Record speech, transcribe it locally, and instantly translate it into a target language of your choice (e.g., Norwegian, French, Spanish, etc.) via API before pasting.

## What It Does

- **Blitztext**: record speech and transcribe it.
- **Blitztext+**: record speech, transcribe it, then turn the rough draft into cleaner writing.
- **Blitztext Translate**: Record speech, transcribe it locally, and instantly translate it into a target language via the OpenAI API. You can select the destination language directly from the menu bar dropdown before triggering the workflow.
- **Blitztext :)**: add fitting emojis to dictated text.

## Important Preview Notes

- macOS only (optimized for Apple Silicon M-series chips).
- **100% Local Transcription:** Audio transcription is exclusively performed on-device using WhisperKit/CoreML. No audio data or raw transcriptions are sent to OpenAI for the base workflow.
- **Optional API Features:** An OpenAI API key is only required if you use the advanced workflows (Blitztext+ or the Translator).
- `./build.sh` creates a locally ad-hoc-signed development app.- Not production ready.
- No warranty and no support guarantee.

You are welcome to use, fork, adapt, and share this project under the license terms.

The intent is not to ship a one-click finished app. The intent is to make a real AI workflow understandable: clone it, build it, read the code, change it, break it, fix it, and suggest improvements. If you only want to download something and never look inside, this preview will probably feel rough. If you want to learn how a small native macOS AI app is put together, you are in the right place.

## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/online-mode.png" alt="Blitztext online transcription mode" width="420"></td>
    <td><img src="docs/screenshots/local-mode.png" alt="Blitztext secure local transcription mode" width="420"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/local-model-picker.png" alt="Blitztext local model picker" width="420"></td>
    <td><img src="docs/screenshots/settings-customize.png" alt="Blitztext settings and customization view" width="420"></td>
  </tr>
</table>

## Requirements

- macOS 14 or newer
- Xcode 16 or newer (Swift 5.10), with Command Line Tools installed and selected for `xcodebuild`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project
- For local transcription: a WhisperKit CoreML model in:
  `~/Library/Application Support/Blitztext/models/whisperkit/`
- For text improvement, translation, and emoji workflows: an OpenAI API key with access to `gpt-4o-mini`

The build also pulls one Swift Package dependency automatically:

- [`argmax-oss-swift`](https://github.com/argmaxinc/argmax-oss-swift) (WhisperKit) — used for local on-device transcription.

Install XcodeGen if needed:

```bash
brew install xcodegen
```

## Build And Run

```bash
git clone https://github.com/cmagnussen/blitztext-app.git
cd blitztext-app
./build.sh --run
```

For a local install into `/Applications`:

```bash
./build.sh --install --run
```

The generated `.app` is ad-hoc signed for local development only. Do not treat it as a trusted redistributable binary. A public binary release would need Developer ID signing and notarization.

On first launch, install a WhisperKit CoreML model for local transcription. If you want to use Blitztext+, Blitztext Translate, or Blitztext :), paste your own OpenAI API key in the settings. The API key is only needed for text transformation workflows.

For a slower, more explicit walkthrough, see [docs/setup.md](docs/setup.md).

## Permissions

Blitztext asks for:

- **Microphone**: to record your voice.
- **Accessibility**: to paste the result back into the app you were using.

If you do not grant Accessibility permission, you can still copy results manually.

Full Disk Access is not required. If auto-paste does not work even though transcription succeeds, open **System Settings -> Privacy & Security -> Accessibility**, enable Blitztext there, restart Blitztext, and try again with the cursor focused in a text field. If macOS shows multiple Blitztext entries, remove or disable the old ones and grant the permission to the app you just built or installed.

##Data Flow in this Fork:

Transcription:        Your Mac (Voice) -> WhisperKit/CoreML (On-Device) -> Local Text
Text Improvement:     Local Text -> OpenAI Chat Completions API -> Refined Text
Translation:          Local Text -> OpenAI Chat Completions API -> Translated Text

The app stores your OpenAI API key in the user's macOS Keychain.

Read [docs/privacy.md](docs/privacy.md) before using the preview with sensitive content.

## Project Structure

```text
BlitztextMac/
  App/          App lifecycle and paste handling
  Features/     Workflows, menu bar UI, settings
  Services/     Recording, OpenAI calls, hotkeys, local storage
  Views/        Shared SwiftUI views
build.sh        Local build script
docs/           Setup, privacy, roadmap, preflight, landing page notes
```

## Local Models

Local transcription is the default path. The app does not bundle a model; choose one in the app and click install. The menu bar UI lets you select the local WhisperKit model used for all dictation workflows.

See [docs/local-models.md](docs/local-models.md).

## Customizing the Translator

By default, the menu bar dropdown supports **German, English, French, Spanish, and Norwegian**. 

Since Blitztext is designed to be fully hackable, adding your own target language is straightforward. If you want to add another language (e.g., Italian or Japanese), simply open the source code, locate the language array in the menu bar feature view, add your desired language to the list, and rebuild the app using:

```bash
./build.sh --install --run
```
## Contributing

Contributions are welcome, especially if they make the preview easier to build, understand, or fork.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Support And Roadmap

This preview has no formal support promise. See [SUPPORT.md](SUPPORT.md) for how to ask for help without sharing secrets.

The current direction is documented in [ROADMAP.md](ROADMAP.md). Maintainer-facing release checks live in [docs/open-source-preflight.md](docs/open-source-preflight.md).

## License

Code is released under the MIT License. See [LICENSE](LICENSE).

Project names, logos, and app icons are not automatically granted as trademarks or brand assets. See [TRADEMARKS.md](TRADEMARKS.md).

## Legal / Disclaimer

This is a private, experimental, and non-commercial open-source fork. It is provided as-is under the MIT License without any warranty, liability, or support guarantees. 

This fork is not affiliated with, operated by, or endorsed by Blackboat Internet GmbH or the original creators of the Blitztext App. No data is collected by the maintainer of this fork.
