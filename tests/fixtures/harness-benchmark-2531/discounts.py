from decimal import Decimal, ROUND_HALF_UP

def discount(value, fraction):
    """Apply an inclusive 0–1 fraction as a markdown; round once to cents."""
    if not Decimal(0) <= fraction <= Decimal(1):
        raise ValueError("invalid fraction")
    return (value * (1 - fraction)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
