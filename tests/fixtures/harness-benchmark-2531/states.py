def next_state(state, event):
    """Keep the current state when the event has no matching transition."""
    transitions = {
        ("queued", "send"): "sent",
        ("queued", "cancel"): "cancelled",
        ("sent", "deliver"): "delivered",
    }
    return transitions.get((state, event), state)
