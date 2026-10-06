import json
from pathlib import Path

import joblib
import matplotlib.pyplot as plt
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score

ROOT = Path(__file__).resolve().parent
APP_ROOT = ROOT.parent
DATA_FILE = ROOT / "energy_data.csv"
MODEL_FILE = ROOT / "bill_model.pkl"
GRAPH_FILE = ROOT / "actual_vs_predicted_bill.png"
FLUTTER_MODEL_FILE = APP_ROOT / "assets" / "ml_model.json"


def load_dataset() -> pd.DataFrame:
    data = pd.read_csv(DATA_FILE)
    data.columns = [col.strip() for col in data.columns]

    for column in ["Voltage", "Current", "Power"]:
        data[column] = pd.to_numeric(data[column], errors="coerce")

    data = data.dropna()
    data = data[(data["Voltage"] > 0) | (data["Current"] > 0) | (data["Power"] > 0)]

    # Monthly bill estimate from power readings (W) used during model development.
    data["Bill"] = data["Power"] * 5 / 1000 * 30 * 50
    return data


def export_flutter_model(model: LinearRegression) -> None:
    FLUTTER_MODEL_FILE.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "model_type": "linear_regression",
        "features": ["voltage", "current", "power"],
        "coefficients": {
            "voltage": float(model.coef_[0]),
            "current": float(model.coef_[1]),
            "power": float(model.coef_[2]),
        },
        "intercept": float(model.intercept_),
        "description": "Predicts estimated monthly bill (Rs.) from live sensor readings",
    }

    FLUTTER_MODEL_FILE.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    data = load_dataset()

    if len(data) < 10:
        raise SystemExit("Not enough training rows in energy_data.csv")

    features = data[["Voltage", "Current", "Power"]]
    target = data["Bill"]

    model = LinearRegression()
    model.fit(features, target)

    predictions = model.predict(features)
    score = r2_score(target, predictions)

    plt.figure(figsize=(10, 6))
    plt.plot(target.values, label="Actual Bill")
    plt.plot(predictions, label="Predicted Bill")
    plt.xlabel("Data Samples")
    plt.ylabel("Bill Amount (Rs.)")
    plt.title("Actual vs Predicted Electricity Bill")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(GRAPH_FILE, dpi=300)
    plt.close()

    joblib.dump(model, MODEL_FILE)
    export_flutter_model(model)

    print("Model trained successfully")
    print(f"R2 score: {score:.4f}")
    print(f"Saved: {MODEL_FILE}")
    print(f"Saved: {FLUTTER_MODEL_FILE}")
    print(f"Saved: {GRAPH_FILE}")


if __name__ == "__main__":
    main()
