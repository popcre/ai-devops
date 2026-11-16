def chargeable_grams(actual, volumetric, step=100):
    """Round up the larger weight to the next step, preserving exact multiples."""
    grams = max(actual, volumetric)
    return ((grams + step - 1) // step) * step
