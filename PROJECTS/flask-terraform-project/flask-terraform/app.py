##############################################################
# app.py — Flask application
# This file lives on YOUR local machine.
# The file provisioner copies it to the EC2 instance.
# Then remote-exec starts it.
##############################################################

from flask import Flask, jsonify
import socket
import datetime

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <html>
    <head><title>Flask on AWS EC2</title></head>
    <body style="font-family: Arial; text-align: center; padding: 50px;">
        <h1>Flask App Running on AWS EC2</h1>
        <h2>Deployed with Terraform Provisioners</h2>
        <p>Server: {}</p>
        <p>Time: {}</p>
        <p><a href="/health">Health Check</a> | <a href="/info">Server Info</a></p>
    </body>
    </html>
    """.format(socket.gethostname(), datetime.datetime.now())

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "timestamp": str(datetime.datetime.now())
    })

@app.route("/info")
def info():
    return jsonify({
        "hostname": socket.gethostname(),
        "deployed_by": "Terraform Provisioners",
        "project": "Flask on AWS EC2"
    })

if __name__ == "__main__":
    # 0.0.0.0 means listen on ALL network interfaces
    # Without this Flask only listens on localhost
    # and the app would not be reachable from the internet
    app.run(host="0.0.0.0", port=5000, debug=False)
