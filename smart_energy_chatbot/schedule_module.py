# schedule_module.py

def get_tariff(time):
    # simple tariff model
    if 6 <= time <= 18:
        return "HIGH"
    else:
        return "LOW"


def suggest_time(appliance, current_time):
    tariff = get_tariff(current_time)

    if tariff == "HIGH":
        return f"⚠ {appliance}: Avoid now (High cost). Use after 6PM for saving."
    else:
        return f"✅ {appliance}: Good time to use (Low cost)."


def weekly_schedule():
    schedule = {
        "Monday": "Use washing machine at night (saves Rs.50)",
        "Tuesday": "Avoid AC during peak hours (12PM-6PM)",
        "Wednesday": "Use iron and water heater after 7PM",
        "Thursday": "Turn off TV standby mode at night",
        "Friday": "Reduce peak-time usage of all appliances",
        "Saturday": "Use washing machine and water heater at night",
        "Sunday": "Flexible usage - monitor AC temperature"
    }
    return schedule


def estimate_savings(kwh):
    # simple saving calculation
    normal_cost = kwh * 30
    optimized_cost = kwh * 22
    saving = normal_cost - optimized_cost
    return saving


def reminder():
    return "🔔 Reminder: This is a good time to use heavy appliances (low tariff)."


if __name__ == "__main__":
    print(suggest_time("Washing Machine", 14))
    print(weekly_schedule())
    print("Estimated Saving:", estimate_savings(200))
    print(reminder())