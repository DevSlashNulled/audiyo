import Foundation

final class Debouncer {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private var pendingWorkItem: DispatchWorkItem?

    init(interval: TimeInterval = 0.25, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    func schedule(_ action: @escaping @Sendable () -> Void) {
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem(block: action)
        pendingWorkItem = item
        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }
}
