import SwiftUI

struct SplitView<LeadingPane: View, TrailingPane: View>: View {
    var leadingPane: LeadingPane
    var trailingPane: TrailingPane
    
    init(@ViewBuilder leading leadingPane: () -> LeadingPane, @ViewBuilder trailing trailingPane: () -> TrailingPane) {
        self.leadingPane = leadingPane()
        self.trailingPane = trailingPane()
    }
    
    var body: some View {
        HStack {
            leadingPane.frame(maxWidth: .infinity)
            Divider().ignoresSafeArea()
            trailingPane.frame(maxWidth: .infinity)
        }
    }
}
