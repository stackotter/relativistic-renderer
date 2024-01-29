import SwiftUI

struct TutorialView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Flask > SSTI").font(.title)
                Text("Server Side Template Injection (SSTI) is a vulnerability that can lead to an malicious actor executing arbitrary code on your server, which is never great! Let’s take a look at the vulnerability in action. First have a quick play around with the website to get a basic idea of what it’s doing, and then try signing in with the username {{ 7 * 7 }}.")
                WebView(url: URL(string: "http://localhost:80")!).frame(maxWidth: .infinity, minHeight: 300).border(.black, width: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding()
    }
}
