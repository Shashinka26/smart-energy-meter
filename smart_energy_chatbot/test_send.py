import requests

data = {"kwh": 200}

res = requests.post("http://127.0.0.1:5000/update", json=data)

print(res.json())