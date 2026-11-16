def reserve(stock, sku, qty):
    """Reserve a positive quantity only if adequate stock exists. Exact stock is valid."""
    available = stock.get(sku, 0)
    if qty <= 0 or available <= qty:
        return False
    stock[sku] = available - qty
    return True
