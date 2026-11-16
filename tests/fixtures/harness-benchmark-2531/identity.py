def map_skus(rows):
    """Keep one value per case-sensitive SKU; first occurrence wins."""
    result = {}
    for row in rows:
        result.setdefault(row["sku"], row)
    return result
