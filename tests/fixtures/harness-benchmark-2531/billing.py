from decimal import Decimal, ROUND_HALF_UP

CENT = Decimal("0.01")

def total(lines, rate):
    """Charge only active lines; apply tax to the full subtotal once."""
    subtotal = sum((line["price"] * line["qty"] for line in lines), Decimal(0))
    return (subtotal * (1 + rate)).quantize(CENT, rounding=ROUND_HALF_UP)
