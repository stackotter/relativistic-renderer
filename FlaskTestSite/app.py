from flask import Flask, render_template, redirect

app = Flask(__name__)


@app.route("/")
def index():
    return redirect("/signin")


@app.route("/signin", methods=["GET", "POST"])
def signin():
    return render_template("login.html")


app.run("0.0.0.0", 80)
