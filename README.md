# adaptive-friction-kit-demo-app

**A payment review screen where the "Confirm" button has an opinion about whether someone is on the phone telling you what to type.**

This is the companion app for [`adaptive-friction-kit`](https://github.com/rajatslakhina/adaptive-friction-kit) — the policy layer between iOS 27 Trust Insights' *is this authenticated user likely being coached?* signal and a sensitive flow. The app is deliberately tiny: one `@main`, one configuration, one screen from the library. Everything interesting lives in the package, which this project consumes as a **version-pinned remote Swift package**, exactly the way a real app would.

## Why this matters

The library's README makes five claims about how a coaching-risk signal should be wired into a flow. This app is where you can watch each of them happen:

- Tap **Review & send** with the signal at *High* and the app's own evidence at "new payee" only: the ladder shows the floor at *Proceed* and the decision at *Out-of-band verify*. The signal raised friction above what the app would have done alone.
- Switch the signal to *Unknown*: the decision drops to the floor and no lower. "No evidence" is the floor, never a discount.
- Leave *Prior model present* on and set the prior model to *Unknown* while the current says *High*: the **Shadow** row says the prior model would relax to *Proceed*, and the ledger's relaxations count goes up. The **Promotion verdict** stays *insufficient* until 73 comparisons — the point at which zero disagreements would clear a 5% tolerance on the 95% Wilson upper bound.
- Switch availability to *Timeout*: the simulated evaluator takes 10 s, the policy's deadline is 1.5 s, and the screen shows the floor with *deadline expired* after ~1.5 s. Nothing is left unreported, because a cancelled evaluation produced nothing — and a timeout is not remembered, so the next tap tries the evaluator again.
- Switch availability to *Not authorized*: the decision is the floor, the basis reads *app risk only · not authorized · cooldown 60 s*, and the next tap says *(remembered)* — the evaluator was not called again. The policy holds that memory for the reported 60 s cooldown, which is why this is the last step: tap **Forget remembered unavailability** (the app's stand-in for "the user re-authorized") to get the evaluator back without waiting or relaunching.

The **Ledgers** section is the consumption contract made visible: *Evaluations reported* rises by one per fused decision, *Outstanding* returns to 0, and *Discarded unreported* stays at 0 — the number that would go up if any code path ever dropped an `InsightEvaluation` without reporting it.

## Screenshots

**No screenshots exist in this repository.** The run that produced it could not launch the app on a Simulator: computer-use access to Xcode and the Simulator is refused during scheduled runs (three attempts, the third for the Simulator alone, all returned "can't be approved during a scheduled run"). There is no `Demo/Screenshots/` directory, and nothing below describes an image.

What *was* verified is stated exactly in [Verification](#verification). "Compiles for the iOS Simulator" and "ran on the iOS Simulator" are different claims; only the first is made here.

## How to run it

```
git clone https://github.com/rajatslakhina/adaptive-friction-kit-demo-app.git
open adaptive-friction-kit-demo-app/Demo.xcodeproj
```

1. Xcode resolves `adaptive-friction-kit` from GitHub (pinned `upToNextMajorVersion` from `1.0.0`).
2. Select the **Demo** scheme and any iOS Simulator (iOS 16 or later).
3. Build & Run. The first tap on **Review & send** should show *Out-of-band verify* above a *Proceed* floor.

To start in a specific QA state, add launch arguments to the scheme: `-AF_SIGNAL medium -AF_AVAILABILITY timeout` (signals: `unknown` | `medium` | `high`; availabilities: `available` | `notAuthorized` | `timeout`). A typo falls back to that key's default rather than crashing the launch.

## What the app owns

`Demo/DemoApp.swift` builds the configuration from the core module's own validated types — `FrictionMatrix.standard`, `BandThresholds.standard`, a 1.5 s deadline, `ShadowConfiguration(driver: .current, observer: .prior)`, a cap of four outstanding evaluations — and reads the initial `QAScenario` from `CommandLine.arguments`. Both initializers throw for values the policy would refuse; the constants here never trip them, and if a future edit does, the app shows a `ConfigurationRejectedView` naming the `PolicyError` instead of crashing at launch. That is why the app imports `AdaptiveFriction` as well as `AdaptiveFrictionUI`.

*Rejected alternative:* a `SensitiveFlowDemoView()` with library-side defaults. It would make the demo a one-liner, but it would also mean the library ships an opinion about deadlines and shadow drivers that a real app has to discover and override — and it would hide the one thing this app exists to show, which is that the policy is configured, validated and refused by types the app can see. A `try!` on the configuration was rejected for the same reason `ConfigurationRejectedView` exists: a launch crash is the worst possible way to learn a constant was edited.

*On `Package.resolved`:* it is deliberately not committed. The project pins `adaptive-friction-kit` by version (`upToNextMajorVersion` from `1.0.0`) in `project.pbxproj`, so every fresh clone and every CI run resolves the newest `1.x.y` from GitHub and prints what it got — the CI job's "Show resolved version" step exists to make that visible in the log rather than frozen in a file that Xcode rewrites on its own schedule.

## Verification

Stated separately so none of it can be mistaken for the others:

- **Compiles for the iOS Simulator, against the package resolved from GitHub — yes.** This repo's [CI](https://github.com/rajatslakhina/adaptive-friction-kit-demo-app/actions) runs on `macos-15`: `xcodebuild -resolvePackageDependencies` (which fetches `adaptive-friction-kit` from GitHub at the newest `1.x` tag — the "Show resolved version" step prints the exact tag and commit), then `xcodebuild build -scheme Demo -destination 'generic/platform=iOS Simulator'` with signing disabled. The first run on this repository passed; every later push re-runs it.
- **Ran on an iOS Simulator — no.** Not by the run that produced this repository (see [Screenshots](#screenshots)). The library's own tests (51, on Linux) exercise the policy that the screen drives, including the default-state trace this README describes; the screen itself has been compiled, not launched.
- **The real Trust Insights framework — not linked.** The evaluator behind the pickers is the library's `SimulatedInsightSource`; the real adapter's shape is sketched in the library README and is not compiled anywhere.
- **`project.pbxproj` was written by hand** and machine-checked before pushing: balanced braces (33/33) and parentheses (24/24), 22 object ids all defined, none dangling, `objectVersion = 60`, and the shared `Demo.xcscheme` references the app target's id.

## Library

[`rajatslakhina/adaptive-friction-kit`](https://github.com/rajatslakhina/adaptive-friction-kit) — design decisions, trade-offs, rejected alternatives, and the 51-test suite.
