from flask import Flask, request, jsonify
import joblib

app = Flask(__name__)
model = joblib.load("bill_model.pkl")

# store latest data
current_usage = 0

@app.route("/update", methods=["POST"])
def update():
    global current_usage
    data = request.json
    current_usage = data["kwh"]
    return {"status": "updated"}

@app.route("/predict")
def predict():
    prediction = model.predict([[current_usage]])[0]
    return jsonify({"bill": round(prediction, 2)})
@app.route("/")
def home():
    return "Backend is running successfully 🚀"

app.run(host="0.0.0.0", port=5000)
