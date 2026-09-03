import SwiftUI
import AdaptiveFriction
import AdaptiveFrictionUI

/// The demo app for `adaptive-friction-kit`.
///
/// The app owns the policy configuration and the launch scenario and hands
/// both to the library's payment-review screen. That split is deliberate:
/// "which friction matrix, what deadline, which model drives" is a product
/// decision and belongs to the app, not to a library initializer. It is also
/// why this file imports `AdaptiveFriction` as well as `AdaptiveFrictionUI` —
/// the configuration below is built from the core module's own validated
/// types (`RiskPolicyConfiguration`, `ShadowConfiguration`, `QAScenario`),
/// and the fallback screen reports the core module's `PolicyError` if a
/// constant is ever edited into something the policy would refuse.
@main
struct DemoApp: App {

    var body: some Scene {
        WindowGroup {
            switch DemoApp.launch {
            case .success(let configuration):
                SensitiveFlowDemoView(configuration: configuration)
            case .failure(let error):
                // Unreachable with the constants below (see `launch`), but a
                // configuration error must degrade to a readable screen, never
                // to a crash at launch.
                ConfigurationRejectedView(message: DemoApp.describe(error))
            }
        }
    }

    /// A 1.5 s deadline — long enough for the simulated evaluator's 20 ms,
    /// short enough that the `timeout` QA state (10 s latency) is visibly
    /// cut off. Shadow evaluation drives on the current model and observes
    /// the prior one, so every "Review & send" adds one comparison to the
    /// promotion ledger. A cap of 4 outstanding evaluations is small enough
    /// to be reasoned about on screen.
    ///
    /// The initial scenario comes from the scheme's launch arguments
    /// (`-AF_SIGNAL high -AF_AVAILABILITY timeout`) when present, so all nine
    /// QA states are reachable without touching the pickers; otherwise it is
    /// `high` / `available`, which makes the headline interaction — a signal
    /// raising friction above the app's own floor — visible on the very first
    /// tap.
    ///
    /// Both initializers throw for values the policy would refuse (a
    /// non-positive deadline, a driver equal to its observer, a tolerance
    /// outside (0, 1]); none of these constants trips them, so the `.failure`
    /// branch is unreachable as written. It exists so that editing a constant
    /// can never turn a typo into a launch crash.
    static let launch: Result<SensitiveFlowDemoConfiguration, any Error> = Result {
        let shadow = try ShadowConfiguration(driver: .current, observer: .prior,
                                             disagreementTolerance: 0.05)
        let policy = try RiskPolicyConfiguration(matrix: .standard,
                                                 thresholds: .standard,
                                                 deadline: .milliseconds(1_500),
                                                 shadow: shadow,
                                                 maxOutstandingEvaluations: 4,
                                                 transientRetryAfter: .seconds(30))
        let scenario = QAScenario.parse(arguments: CommandLine.arguments)
            ?? QAScenario(signal: .high, availability: .available)
        return SensitiveFlowDemoConfiguration(policy: policy, initialScenario: scenario)
    }

    static func describe(_ error: any Error) -> String {
        if let policyError = error as? PolicyError {
            switch policyError {
            case .invalidThresholds(let elevatedAt, let highAt):
                return "Invalid band thresholds: elevated \(elevatedAt), high \(highAt)"
            case .matrixIncomplete(let band, let signal):
                return "Friction matrix is missing the (\(band), \(signal)) cell"
            case .matrixNotMonotone(let band, let signal, let level, let previous):
                return "Friction matrix decreases at (\(band), \(signal)): \(level) after \(previous)"
            case .invalidWeight(let name, let weight):
                return "Invalid weight \(weight) for risk signal \(name)"
            case .invalidConfiguration(let message):
                return "Invalid policy configuration: \(message)"
            case .shadowSelectorsMustDiffer:
                return "Shadow driver and observer must be different models"
            }
        }
        return String(describing: error)
    }
}

/// Shown only if the launch configuration is rejected by the library.
struct ConfigurationRejectedView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("The demo configuration was rejected by AdaptiveFriction.")
                .multilineTextAlignment(.center)
            Text(message)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
