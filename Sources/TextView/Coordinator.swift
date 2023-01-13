import SwiftUI

extension TextView.Representable {
    final class Coordinator: NSObject, UITextViewDelegate {

        internal let textView: UIKitTextView

        private var originalText: NSMutableAttributedString = .init()
        private var text: Binding<NSMutableAttributedString>
        private var selectedRange: Binding<NSRange>
        private var calculatedHeight: Binding<CGFloat>
      
        var didBecomeFirstResponder = false

        var onCommit: (() -> Void)?
        var onEditingChanged: (() -> Void)?
        var shouldEditInRange: ((Range<String.Index>, String) -> Bool)?

        init(text: Binding<NSMutableAttributedString>,
             selectedRange: Binding<NSRange>,
             calculatedHeight: Binding<CGFloat>,
             shouldEditInRange: ((Range<String.Index>, String) -> Bool)?,
             onEditingChanged: (() -> Void)?,
             onCommit: (() -> Void)?
        ) {
            textView = UIKitTextView()
            textView.backgroundColor = .clear
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            self.text = text
            self.selectedRange = selectedRange
            self.calculatedHeight = calculatedHeight
            self.shouldEditInRange = shouldEditInRange
            self.onEditingChanged = onEditingChanged
            self.onCommit = onCommit

            super.init()
            textView.delegate = self
        }
      
        func textViewDidChangeSelection(_ textView: UITextView) {
          DispatchQueue.main.async {
            if self.selectedRange.wrappedValue != textView.selectedRange {
              self.selectedRange.wrappedValue = textView.selectedRange
            }
          }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            originalText = text.wrappedValue
            DispatchQueue.main.async {
              self.recalculateHeight()
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async {
              self.text.wrappedValue = NSMutableAttributedString(attributedString: textView.attributedText)
              self.recalculateHeight()
              self.onEditingChanged?()
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if onCommit != nil, text == "\n" {
                onCommit?()
                originalText = NSMutableAttributedString(attributedString: textView.attributedText)
                textView.resignFirstResponder()
                return false
            }

            return true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // this check is to ensure we always commit text when we're not using a closure
            if onCommit != nil {
                text.wrappedValue = originalText
            }
        }

    }

}

extension TextView.Representable.Coordinator {

    func update(representable: TextView.Representable) {
        textView.attributedText = representable.text
        textView.selectedRange = representable.selectedRange
        textView.font = representable.font
        textView.adjustsFontForContentSizeCategory = true
        textView.autocapitalizationType = representable.autocapitalization
        textView.autocorrectionType = representable.autocorrection
        textView.isEditable = representable.isEditable
        textView.isSelectable = representable.isSelectable
        textView.isScrollEnabled = representable.isScrollingEnabled
        textView.dataDetectorTypes = representable.autoDetectionTypes
        textView.allowsEditingTextAttributes = representable.allowsRichText

        switch representable.multilineTextAlignment {
        case .leading:
            textView.textAlignment = textView.traitCollection.layoutDirection ~= .leftToRight ? .left : .right
        case .trailing:
            textView.textAlignment = textView.traitCollection.layoutDirection ~= .leftToRight ? .right : .left
        case .center:
            textView.textAlignment = .center
        }

        if let value = representable.enablesReturnKeyAutomatically {
            textView.enablesReturnKeyAutomatically = value
        } else {
            textView.enablesReturnKeyAutomatically = onCommit == nil ? false : true
        }

        if let returnKeyType = representable.returnKeyType {
            textView.returnKeyType = returnKeyType
        } else {
            textView.returnKeyType = onCommit == nil ? .default : .done
        }

        if !representable.isScrollingEnabled {
            textView.textContainer.lineFragmentPadding = 0
            textView.textContainerInset = .zero
        }

        recalculateHeight()
        textView.setNeedsDisplay()
    }

    private func recalculateHeight() {
        let newSize = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude))
        guard calculatedHeight.wrappedValue != newSize.height else { return }

        DispatchQueue.main.async { // call in next render cycle.
            self.calculatedHeight.wrappedValue = newSize.height
        }
    }

}
