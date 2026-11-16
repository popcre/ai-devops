def page(rows, limit, after=None):
    """Return the next page in ascending (sequence, id) order. Cursor is exclusive."""
    ordered = sorted(rows, key=lambda r: (r["sequence"], r["id"]))
    if after is not None:
        ordered = [r for r in ordered if r["sequence"] > after[0]]
    return ordered[:limit]
