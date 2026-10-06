# ML Bill Prediction Backend

## Train model

```bash
pip install -r requirements.txt
python train_model.py
```

This creates:

- `bill_model.pkl`
- `../assets/ml_model.json`
- `actual_vs_predicted_bill.png`

## Run API

```bash
python backend.py
```

### Predict endpoint

```
GET /predict?voltage=229.2&current=0.002&power=1.1
POST /predict
{
  "voltage": 229.2,
  "current": 0.002,
  "power": 1.1
}
```

Response:

```json
{
  "bill": 8.25,
  "source": "ml_model"
}
```
