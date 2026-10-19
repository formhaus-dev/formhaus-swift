#if os(iOS)
    import UIKit

    @MainActor
    enum ScriptKeyboard {
        static func hide() {
            UITextField.appearance().inputView = UIView(frame: .zero)
            UITextField.appearance().inputAccessoryView = nil
        }
    }
#else
    @MainActor
    enum ScriptKeyboard {
        static func hide() {}
    }
#endif
