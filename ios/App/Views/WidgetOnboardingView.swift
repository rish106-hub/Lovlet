import SwiftUI
import WidgetKit

struct WidgetOnboardingView: View {
    var onComplete: () -> Void

    @State private var isChecking = false
    @State private var showNotFound = false
    @State private var showContinueAnyway = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)
                .padding(.bottom, 24)

            Text("Add the Partner Widget")
                .font(.title.bold())
                .padding(.bottom, 8)

            Text("Stay connected at a glance — see your partner's latest moment right from your home screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                OnboardingStep(number: 1, text: "Long-press your home screen")
                OnboardingStep(number: 2, text: "Tap the \"+\" button in the top-left")
                OnboardingStep(number: 3, text: "Search for \"CouplesMVP\"")
                OnboardingStep(number: 4, text: "Choose a size and tap Add Widget")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                if showNotFound {
                    Text("Widget not detected yet. Add it to your home screen and try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if isChecking {
                            ProgressView()
                        } else {
                            Text("I've Added the Widget")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isChecking)
                .padding(.horizontal)

                if showContinueAnyway {
                    Button("Continue Anyway") {
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

#if DEBUG
                Button("⚡ Skip — Dev Only") {
                    onComplete()
                }
                .foregroundStyle(.orange)
                .padding(.top, 4)
#endif
            }
            .padding(.bottom, 32)
        }
    }

    private func verify() async {
        isChecking = true
        showNotFound = false
        defer { isChecking = false }

        let found = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            WidgetCenter.shared.getCurrentConfigurations { result in
                if case .success(let widgets) = result, !widgets.isEmpty {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }

        if found {
            onComplete()
        } else {
            showNotFound = true
            showContinueAnyway = true
        }
    }
}

private struct OnboardingStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue, in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}
