# Build for iPhone

The shared SwiftUI application is configured in `project.yml`. XcodeGen generates
the Xcode project; generated project files and signing settings stay untracked.

1. Use a Mac with Xcode 26+ and install [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. From the repository root, run `xcodegen generate`.
3. Open `Rehearsal.xcodeproj` and select the Rehearsal target.
4. In Signing & Capabilities, choose your own development team and, if necessary,
   a unique bundle identifier. Keep automatic signing settings local.
5. Choose your iPhone and run. The manual sandbox requires iOS 16+.
6. For live inference use iOS 26+, a compatible Apple Intelligence device, and an
   available system model. The app reports availability; an arbitrary iPhone is
   not sufficient. No model API key is needed.

The app does not request calendar permission because v0.1 only simulates writes.
Building or signing the application does not enable Apple Intelligence on an
ineligible device. Physical-device validation remains pending.

The generated iOS project references the local `RehearsalCore` package. It compiles
the shared app sources; the macOS package executable is not used as an iOS binary.
