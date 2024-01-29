import SwiftUI

struct CodeEditorView: View {
    let files = [
        (
            "app.py",
            """
            from flask import Flask
            
            app = Flask(__name__)
            
            @app.route("/")
            def index():
                return "Hello, world!"
            """
        ),
        (
            "login.html",
            """
            <html>
                <body>
                    <h1>Sign in</h1>
                    <form action="/signin" method="GET">
                        <input name="username" placeholder="Username" />
                        <button type="submit">Sign in</button>
                    </form>
                </body>
            </html>
            """
        )
    ]
    var body: some View {
        TabView {
            ForEach(files, id: \.0) { (name, content) in
                ScrollView {
                    Text(content)
                }
                    .font(.system(size: 12).monospaced())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .tabItem {
                        Text(name)
                    }
            }
        }
    }
}
