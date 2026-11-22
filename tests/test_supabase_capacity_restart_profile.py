#!/usr/bin/env python3
"""Offline unit tests for tools/supabase_capacity_restart_profile.py."""
import hashlib
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import supabase_capacity_restart_profile as mod

SHA = "a" * 40


def make_fixture():
    blobs = {name: f"content:{name}\n".encode() for name in mod.SOURCE_FILES}
    pins = {name: hashlib.sha256(data).hexdigest() for name, data in blobs.items()}
    profile = {
        "schema_version": 1,
        "enabled": True,
        "repository": mod.REPOSITORY,
        "workflow": mod.WORKFLOW,
        "source_files": pins,
    }
    consumer = {
        "gates": {
            "infrastructure": {
                "required": [
                    "repository-branch-and-pr",
                    "current-chat-resource-and-action-authorization",
                    "reviewed-production-dispatch",
                    mod.GATE,
                ]
            }
        }
    }
    manifest = {
        "schema_version": 1,
        "operation": "pgss-capacity-restart/v1",
        "repository": mod.REPOSITORY,
        "workflow": mod.WORKFLOW,
        "ref": "main",
        "head_sha": SHA,
        "work_issue": 5609,
        "mode": "preview_only",
    }
    return manifest, profile, consumer, blobs


class TestSupabaseCapacityRestartProfile(unittest.TestCase):
    def test_qualifies_both_modes_on_linux_and_windows(self):
        for platform in ("linux", "win32"):
            for mode in ("preview_only", "preview_and_production"):
                manifest, profile, consumer, blobs = make_fixture()
                manifest["mode"] = mode
                digest = mod.qualify(
                    manifest, profile, head=SHA, main=SHA,
                    consumer=consumer, blobs=blobs, platform=platform,
                )
                self.assertEqual(len(digest), 64)

    def test_refuses_disabled_profile_or_drift_or_bad_mode(self):
        manifest, profile, consumer, blobs = make_fixture()
        profile["enabled"] = False
        with self.assertRaisesRegex(mod.Refused, "not enabled"):
            mod.qualify(manifest, profile, head=SHA, main=SHA, consumer=consumer, blobs=blobs, platform="win32")

        manifest, profile, consumer, blobs = make_fixture()
        blobs["config/pgss-capacity-restart.json"] = b"tampered"
        with self.assertRaisesRegex(mod.Refused, "source differs"):
            mod.qualify(manifest, profile, head=SHA, main=SHA, consumer=consumer, blobs=blobs, platform="linux")

        manifest, profile, consumer, blobs = make_fixture()
        manifest["mode"] = "production_only"
        with self.assertRaisesRegex(mod.Refused, "outside the closed"):
            mod.qualify(manifest, profile, head=SHA, main=SHA, consumer=consumer, blobs=blobs, platform="win32")

        manifest, profile, consumer, blobs = make_fixture()
        consumer["gates"]["infrastructure"]["required"] = ["reviewed-production-dispatch"]
        with self.assertRaisesRegex(mod.Refused, "not declared"):
            mod.qualify(manifest, profile, head=SHA, main=SHA, consumer=consumer, blobs=blobs, platform="win32")


if __name__ == "__main__":
    unittest.main()
