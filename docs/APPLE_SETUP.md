# Apple setup: what you actually need

**No Foundation Models API key, model-provider account, or `.env` file is required
for this project's on-device inference.** The app accesses the system model using
`SystemLanguageModel.default` and `LanguageModelSession`. You do not create an
Apple model, download weights into this repository, or train an adapter to run it.

Apple explains that on-device framework features work without setting up an account
or obtaining API keys: [Apple framework overview video](https://developer.apple.com/videos/play/wwdc2025/360/).

## Requirements by use case

| What you want to do | What you need |
| --- | --- |
| Run the deterministic CLI demo | Mac with a working Swift compiler; no Apple account or model |
| Run the manual native macOS sandbox | macOS 13+ and a compatible build; no model key |
| Build the live model integration | Xcode 26+ / Swift 6.2+ and a Mac OS version supported by that Xcode release |
| Run live inference on a Mac | An Apple Intelligence-compatible Mac, macOS 26+, and an available on-device model |
| Run live inference on iPhone | Apple Intelligence-compatible iPhone, iOS 26+, and an available on-device model |
| Install a development build on your own iPhone | Apple Account in Xcode, a selected signing team, and automatic signing |
| Distribute through TestFlight or the App Store | Apple Developer Program membership and the normal signing/distribution setup |

For example, iPhone 15 Pro / Pro Max and iPhone 16 models support Apple Intelligence;
an ordinary iPhone 15 does not. Apple silicon Macs with M1 or later support Apple
Intelligence, subject to OS, language, region, and model availability. The app's
runtime check is authoritative for whether inference is available right now.
[Apple's current device requirements](https://support.apple.com/en-us/121115).

The initial development machine was an Intel Mac running macOS 13.7.8. It can run
the manual sandbox, but cannot run the Apple on-device model. Generating a key or
paying for a developer membership does not make that hardware eligible.

## Enable and verify the model

1. Update your eligible target device to a supported OS, at least version 26 for
   this app's Foundation Models integration.
2. Enable Apple Intelligence in Settings/System Settings if your OS requires it.
   Ensure your language and region are supported.
3. Allow the system model download to finish. Wi-Fi, power, and free device storage
   may be needed. The app does not download a model itself.
4. Build with Xcode 26+ and run the app. Check the availability message at the top.
5. Choose a day, type a complete focus-block request, and use **Interpret with
   Apple Foundation Models**. Review the extracted result before approval.

Model availability can change while the app is running. The extraction path checks
it again each time. See [Apple's availability guidance](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models).

## iPhone signing is separate from model access

A free Apple developer account can test apps on personal devices through Xcode,
with Personal Team provisioning limits. Select your Apple Account under Xcode's
Accounts settings, then choose your team in **Signing & Capabilities** for the
generated iOS target. Use automatic signing and a unique bundle identifier if
Xcode requests one. You do not need to manually generate an App Store Connect
`.p8` key for this local workflow.

Paid membership is for distribution features such as TestFlight/App Store,
not for unlocking this app's on-device inference.
[Apple program comparison](https://developer.apple.com/programs/),
[Personal Team account details](https://developer.apple.com/help/account/basics/about-your-developer-account).

## Troubleshooting

| App/build message | Next step |
| --- | --- |
| Manual sandbox / model unavailable on this build | Rebuild with Xcode 26+ and run on OS 26+ |
| Device not eligible | Use an Apple Intelligence-compatible device; a key cannot fix this |
| Model not ready | Check Apple Intelligence settings and allow the system download to finish |
| Unsupported language or region | Check Apple's availability requirements for your device and OS |
| Signing/provisioning failure | Select a team and unique bundle identifier in Xcode; this is separate from model access |
| No free slot | Widen the time window, shorten the duration, or reduce the reminder lead |

This version only writes to its local sandbox. Calendar/Reminders permissions are
not requested. Real-model semantic quality and physical-device behavior remain
unmeasured even though the integration and simulator app compile in CI.
