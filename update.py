#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 curl nix dpkg

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

API = "https://popo.netease.com/api/open/jsonp/check_version?device=6&callback=popo"


def parse_release(text):
    match = re.fullmatch(r"popo\((.*)\);?", text.strip(), re.DOTALL)
    if not match:
        raise ValueError("Unexpected JSONP response")
    response = json.loads(match[1])
    if response.get("status") != 1:
        raise ValueError("POPO API returned an error")
    data = response["data"]
    version = data["version"]
    url = urlsplit(data["url"])
    if not re.fullmatch(r"\d+(?:\.\d+)+", version):
        raise ValueError("Invalid release version")
    if (url.scheme != "https"
        or url.netloc not in {"popo.netease.com", "popo.gdl.netease.com"}
        or not re.fullmatch(r"/file/popolinux/[\w.-]+\.deb", url.path)
        or url.query or url.fragment):
        raise ValueError("Unexpected Linux download URL")
    return version, "https://popo.gdl.netease.com" + url.path


def update():
    path = Path("source.json")
    old = json.loads(path.read_text())
    response = subprocess.check_output(
        ["curl", "--fail", "--silent", "--show-error", "--location",
         "--retry", "3", "--max-time", "60", API], text=True)
    release, url = parse_release(response)
    fetched = json.loads(subprocess.check_output(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
        text=True))
    fields = subprocess.check_output(
        ["dpkg-deb", "--field", fetched["storePath"],
         "Package", "Version", "Architecture"], text=True)
    fields = dict(line.split(": ", 1) for line in fields.splitlines())
    version = fields["Version"]
    if (fields["Package"] != "popo" or fields["Architecture"] != "amd64"
        or not re.fullmatch(re.escape(release) + r"(?:\.\d+)*", version)):
        raise ValueError("deb metadata does not match the Linux release")
    new = {"version": version, "url": url, "hash": fetched["hash"]}
    if new == old:
        print(f"POPO {version} is up to date (hash verified)")
        return
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as f:
            temporary = Path(f.name)
            f.write(json.dumps(new, indent=2) + "\n")
        temporary.chmod(path.stat().st_mode & 0o777)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(f"POPO {old['version']} -> {version}")


def self_test():
    data = {"version": "3.71.1", "url": "https://popo.netease.com/file/popolinux/test.deb"}
    response = lambda d: "popo(" + json.dumps({"status": 1, "data": d}) + ");"
    assert parse_release(response(data)) == (
        "3.71.1", "https://popo.gdl.netease.com/file/popolinux/test.deb")
    for text in ["not jsonp", 'popo({"status":0})',
                 response({**data, "version": "bad"}),
                 response({**data, "url": "https://example.com/evil.deb"})]:
        try:
            parse_release(text)
        except ValueError:
            continue
        raise AssertionError(f"Accepted invalid release: {text}")
    print("Update parser checks passed")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif sys.argv[1:]:
        sys.exit("Usage: ./update.py [--self-test] (run from the package directory)")
    else:
        update()
