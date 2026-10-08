"""Offline verification of native numeric receipts, never a runtime claim."""
from source_binding import FILES

KEYS = {"schema", "execution_exit_code", "selection_verified", "http_requests",
        "source_commit", "source_archive_sha256", "toolchain_archive_sha256",
        "input_sources_sha256", "compiled_sources_sha256", "binary_sha256",
        "cold_baseline_ns", "cold_candidate_ns", "warm_baseline_ns", "warm_candidate_ns"}


def _digest(value, expected):
    return (isinstance(value, list) and len(value) == len(expected) // 2
            and all(type(item) is int and 0 <= item <= 255 for item in value)
            and bytes(value).hex() == expected)


def validate_receipt(receipt, manifest):
    if (type(receipt) is not dict or set(receipt) != KEYS or type(receipt["schema"]) is not int
            or receipt["schema"] != 1 or type(receipt["execution_exit_code"]) is not int
            or receipt["execution_exit_code"] < 0 or type(receipt["selection_verified"]) is not bool
            or receipt["http_requests"] is not None):
        raise ValueError("invalid numeric receipt")
    for key, pin in (("source_commit", "upstream_commit"), ("source_archive_sha256", "source_sha256"),
                     ("toolchain_archive_sha256", "toolchain_sha256")):
        if not _digest(receipt[key], manifest["pins"][pin]):
            raise ValueError("receipt pin mismatch")
    for key, field in (("input_sources_sha256", "counter_source_binding"),
                       ("compiled_sources_sha256", "compiled_counter_source_binding")):
        binding = manifest[field]
        if binding["schema"] != 1 or set(binding["files"]) != set(FILES):
            raise ValueError("incomplete source manifest")
        values = receipt[key]
        if not isinstance(values, list) or len(values) != len(FILES):
            raise ValueError("receipt closure mismatch")
        for value, name in zip(values, FILES):
            if not _digest(value, binding["files"][name]):
                raise ValueError("receipt source mismatch")
    values = receipt["binary_sha256"]
    if not isinstance(values, list) or len(values) != 3:
        raise ValueError("receipt binary closure mismatch")
    for value, kind in zip(values, ("baseline", "instrumented", "native_fixture")):
        if not _digest(value, manifest["artifacts"][kind]["sha256"]):
            raise ValueError("receipt binary mismatch")
    complete = receipt["execution_exit_code"] == 0 and receipt["selection_verified"]
    for key in ("cold_baseline_ns", "cold_candidate_ns", "warm_baseline_ns", "warm_candidate_ns"):
        values = receipt[key]
        if values is None and not complete:
            continue
        if (not isinstance(values, list) or len(values) != 20
                or any(type(value) is not int or value <= 0 or value > 10**15 for value in values)):
            raise ValueError("timing evidence incomplete")
    if complete:
        for group in ("cold", "warm"):
            baseline, candidate = receipt[group + "_baseline_ns"], receipt[group + "_candidate_ns"]
            if sorted(candidate)[18]*100 > sorted(baseline)[18]*105 or sum(candidate)*100 > sum(baseline)*105:
                raise ValueError("observed overhead exceeds qualification gate")
    return {"native_execution_complete": complete, "installed_acceptance": False, "http_requests": None}
