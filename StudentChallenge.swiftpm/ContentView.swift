import SwiftUI

struct ContentView: View {
    var body: some View {
        SplitView {
            TutorialView()
        } trailing: {
            CodeEditorView()
        }
    }
}
