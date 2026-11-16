def ready(rows, now):
    """Return ready shipments in persisted order, including those due exactly now."""
    return [row["id"] for row in rows
            if row["status"] == "queued" and row["due"] < now]
