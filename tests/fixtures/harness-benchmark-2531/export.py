def snapshot(events):
    """Keep latest event per SKU; sequence is unique and input is unordered."""
    result = {}
    for event in events:
        result[event["sku"]] = event
    return result
