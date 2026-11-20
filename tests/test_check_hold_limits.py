import importlib.util
import pathlib

spec = importlib.util.spec_from_file_location("chl", pathlib.Path(__file__).parents[1] / "tools/ci/check-hold-limits.py")
chl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(chl)


def test_flags_hour_and_day_holds():
    assert chl.scan_line("WINDOW = timedelta(hours=24)") == 1440
    assert chl.scan_line("IDLE = timedelta(days=2)") == 2880
    assert chl.scan_line("X = timedelta(minutes=45)") == 45
    assert chl.scan_line("const t = 4 * 60 * 60 * 1000;") == 240
    assert chl.scan_line("(( now - last < 2 * 3600 ))") == 120


def test_allows_thirty_minutes_or_less():
    assert chl.scan_line("HOLD = timedelta(minutes=30)") is None
    assert chl.scan_line("POLL = timedelta(seconds=90)") is None


def test_opt_out_needs_a_reason():
    assert chl.scan_line("LOOKBACK = timedelta(days=90)  # not-a-hold: report window") is None
    assert chl.scan_line("LOOKBACK = timedelta(days=90)  # not-a-hold:") == 129600
