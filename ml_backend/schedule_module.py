"""Rule-based schedule and tariff helpers used by the ML backend."""


def get_tariff(hour: int) -> str:
    if 6 <= hour <= 18:
        return "HIGH"
    return "LOW"


def suggest_time(appliance: str, hour: int) -> str:
    tariff = get_tariff(hour)

    if tariff == "HIGH":
        return (
            f"{appliance}: Avoid now (high tariff). "
            "Use after 6 PM to reduce cost."
        )

    return f"{appliance}: Good time to use (low tariff)."


def estimate_savings(kwh: float) -> float:
    normal_cost = kwh * 30
    optimized_cost = kwh * 22
    return normal_cost - optimized_cost


def weekly_schedule() -> dict[str, str]:
    return {
        "Monday": "Use washing machine at night",
        "Tuesday": "Avoid heavy usage during day",
        "Wednesday": "Use iron after 7 PM",
        "Thursday": "Normal usage",
        "Friday": "Reduce peak-time usage",
        "Saturday": "Use appliances at night",
        "Sunday": "Flexible usage",
    }
