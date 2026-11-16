def available(stock, pending, sku, warehouse):
    """Count only this SKU's pending reservations in the specified warehouse."""
    reserved = sum(r["qty"] for r in pending if r["sku"] == sku)
    return max(0, stock.get((warehouse, sku), 0) - reserved)
