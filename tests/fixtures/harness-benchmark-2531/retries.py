def next_delay(attempt, base=2, cap=60):
    """The first retry uses base seconds; later retries double to cap."""
    if attempt < 1:
        raise ValueError("attempts are numbered from one")
    return min(cap, base * (2 ** attempt))
