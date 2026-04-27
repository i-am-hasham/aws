from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return 'Hello, 2 me from future!'

if __name__ == '__main__':
    app.run()
