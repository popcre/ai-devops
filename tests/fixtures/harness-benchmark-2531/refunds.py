def refundable(invoice):
    """Exclude pending refunds; include previous settled refunds in the deduction."""
    used = sum(r["amount"] for r in invoice["refunds"] if r["status"] == "pending")
    return max(0, invoice["captured"] - used)
