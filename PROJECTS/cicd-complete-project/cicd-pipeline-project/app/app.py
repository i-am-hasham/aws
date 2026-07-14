##############################################################
# app/app.py
# Simple Flask app — gets built into Docker image by CodeBuild
##############################################################

from flask import Flask, jsonify
import socket
import datetime
import os

app = Flask(__name__)

@app.route("/")
def home():
    return f"""
    <html>
    <head><title>Flask CI/CD Pipeline</title></head>
    <body style="font-family: Arial; text-align: center; padding: 50px; background: #1a1a2e; color: #eee;">
        <h1 style="color: #00d4ff;">Flask App — AWS CI/CD Pipeline</h1>
        <h2>GitHub → CodePipeline → CodeBuild → ECR → CodeDeploy → EC2</h2>
        <hr style="border-color: #00d4ff;">
        <p>Hostname: {socket.gethostname()}</p>
        <p>Time: {datetime.datetime.now()}</p>
        <p>Version: {os.environ.get('APP_VERSION', '1.0.0')}</p>
        <p><a href="/health" style="color: #00d4ff;">Health Check</a> |
           <a href="/info" style="color: #00d4ff;">Server Info</a></p>
    </body>
    </html>
    """

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "timestamp": str(datetime.datetime.now()),
        "version": os.environ.get("APP_VERSION", "1.0.0")
    })

@app.route("/info")
def info():
    return jsonify({
        "hostname": socket.gethostname(),
        "pipeline": "GitHub -> CodePipeline -> CodeBuild -> ECR -> CodeDeploy",
        "deployed_by": "AWS CodeDeploy",
        "version": os.environ.get("APP_VERSION", "1.0.0")
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
