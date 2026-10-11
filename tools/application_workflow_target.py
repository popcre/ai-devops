"""Validate the one reviewed application-owned HTS sandbox workflow target.

This validates admission metadata, not HTTP execution. The caller must prove
live target identity immediately before requests and retain actual acceptance.
"""
import json
import pathlib
import stat
import sys

TARGET = {
    "schema_version": 1,
    "repository": "popcre/designflow-backend",
    "issue": "https://github.com/popcre/designflow-backend/issues/94",
    "route": "authenticated-application-http",
    "api_origin": "https://api.alsand.designflow.app/api/core",
    "project": "lithe-breaker-323913",
    "region": "us-east4",
    "service": "popcre-albert-core-sandbox",
    "scope": "hts-non-operative-shadow-writes-provider-calls-learning-replay-retrieval",
    "routes": ["POST /api/cross/evidence", "POST /api/hts-rag/precheck-v2",
               "POST /api/hts-rag/shadow-classify",
               "GET /api/hts-rag/history", "GET /api/hts-rag/history/:id/turns"],
    "forbidden": ["sql", "schema", "cloud-mutation", "manual-promotion",
                  "runtime-flag-change", "rfq-apply-save", "production", "merge"],
}


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def main():
    try:
        root = pathlib.Path(sys.argv[1]).resolve(strict=True)
        relative = pathlib.PurePosixPath(sys.argv[2])
        if relative.is_absolute() or ".." in relative.parts:
            return 1
        path = root
        for part in relative.parts:
            path = path / part
            if stat.S_ISLNK(path.lstat().st_mode):
                return 1
        if not stat.S_ISREG(path.lstat().st_mode):
            return 1
        path.resolve(strict=True).relative_to(root)
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)
        return 0 if type(value) is dict and type(value.get("schema_version")) is int and value == TARGET else 1
    except (OSError, ValueError, TypeError, IndexError):
        return 1


if __name__ == "__main__":
    sys.exit(main())
