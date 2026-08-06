import AppKit

/// An `NSMenuItem` that runs a closure instead of requiring a target/selector pair.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, state: NSControl.StateValue = .off, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
        self.state = state
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        handler()
    }
}
