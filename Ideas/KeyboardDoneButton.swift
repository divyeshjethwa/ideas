import SwiftUI
import UIKit

extension View {
    /// Adds a ✓ button above the keyboard that closes it.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                } label: {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
