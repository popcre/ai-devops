"""Throwaway helper for the #2070 live review proof. Do not merge."""


def last_n(items, n):
    """Return the last n items of a list, in order."""
    if n <= 0:
        return []
    return items[len(items) - n + 1:]
