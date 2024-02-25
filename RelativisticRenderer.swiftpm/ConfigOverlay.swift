import SwiftUI

struct ConfigOverlay<Child: View>: View {
    @ViewBuilder
    var child: () -> Child

    var body: some View {
        HStack(alignment: .top) {
            VStack {
                VStack(alignment: .leading) {
                    child()
                }
                .padding(16)
                .background(.black.opacity(0.6))
                .frame(width: 400)

                Spacer()
            }
            Spacer()
        }
    }
}
