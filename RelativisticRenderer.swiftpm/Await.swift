import SwiftUI

struct Await<R, Placeholder: View, Failure: View, Success: View>: View {
    var task: () async throws -> R
    
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var success: (R) -> Success
    @ViewBuilder var failure: (any Error) -> Failure
    
    @State var state = AwaitState.awaiting
    
    init(
        _ task: @escaping () async throws -> R,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder success: @escaping (R) -> Success,
        @ViewBuilder failure: @escaping (any Error) -> Failure
    ) {
        self.task = task
        self.placeholder = placeholder
        self.success = success
        self.failure = failure
    }
    
    enum AwaitState {
        case awaiting
        case success(R)
        case failure(any Error)
    }

    var body: some View {
        VStack {
            switch state {
            case .awaiting:
                placeholder()
            case let .success(result):
                success(result)
            case let .failure(error):
                failure(error)
            }
        }
        .onAppear {
            Task {
                do {
                    let result = try await task()
                    Task { @MainActor in
                        state = .success(result)
                    }
                } catch {
                    state = .failure(error)
                }
            }
        }
    }
}
