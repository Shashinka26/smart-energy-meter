import pandas as pd
from sklearn.linear_model import LinearRegression

data = pd.read_csv("bill_data.csv")

X = data[['monthly_kwh']]
y = data['monthly_bill']

model = LinearRegression()
model.fit(X, y)
import pandas as pd
prediction = model.predict(pd.DataFrame([[180]], columns=['monthly_kwh']))

print("Predicted bill:", prediction[0])

import joblib
joblib.dump(model, "bill_model.pkl")
print("Model saved successfully!")