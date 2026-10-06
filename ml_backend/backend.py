from flask import Flask, jsonify, request
import joblib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MODEL_FILE = ROOT / "bill_model.pkl"

app = Flask(__name__)
model = joblib.load(MODEL_FILE)


def predict_bill(voltage: float, current: float, power: float) -> float:
    return float(model.predict([[voltage, current, power]])[0])


@app.route("/")
def home():
    return jsonify({"status": "ok", "service": "Smart Energy ML Backend"})


@app.route("/predict", methods=["GET", "POST"])
def predict():
    if request.method == "POST":
        payload = request.get_json(silent=True) or {}
        voltage = float(payload.get("voltage", 0))
        current = float(payload.get("current", 0))
        power = float(payload.get("power", 0))
    else:
        voltage = float(request.args.get("voltage", 0))
        current = float(request.args.get("current", 0))
        power = float(request.args.get("power", 0))

    bill = predict_bill(voltage, current, power)

    return jsonify(
        {
            "bill": round(bill, 2),
            "source": "ml_model",
            "inputs": {
                "voltage": voltage,
                "current": current,
                "power": power,
            },
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
