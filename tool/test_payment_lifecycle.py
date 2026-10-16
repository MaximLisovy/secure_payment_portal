#!/usr/bin/env python3
"""Runs a payment through background and Activity recreation on an emulator, for every brand (or one).

Usage: python3 tool/test_payment_lifecycle.py --device emulator-5554 [--flavor retail]
Builds and installs each flavor's debug APK, resets only that app's data, and drives the real
Flutter UI and the real foreground service with adb. Only emulators are accepted. Exit status 1
if any scenario fails; the report is in build/payment_integration/<flavor>-lifecycle.json.
"""

import argparse
import json
import re
import subprocess
import sys
import time

from payment_lifecycle_support import Android, ROOT, wait_for


def background_and_return(android):
    android.reset()
    android.tap_pay()
    process = android.pid()
    android.shell("input", "keyevent", "KEYCODE_HOME")
    wait_for(lambda: android.activity_identity() is None, "background Activity")
    wait_for(lambda: not android.service_running(), "background payment completion")
    if android.pid() != process:
        raise RuntimeError("The process changed; this did not test background continuation")
    android.launch()
    android.expect_receipt()


def recreate_engine(android):
    android.reset()
    android.tap_pay()
    process = android.pid()
    previous = android.activity_identity()
    if previous is None:
        raise RuntimeError("Payment Activity was not resumed")
    # NEW_TASK + CLEAR_TASK (API 11+) destroys the old Activity without force-stop.
    # MainActivity uses FlutterActivity's uncached engine, destroyed with its host.
    android.launch(recreate=True)
    wait_for(lambda: android.activity_identity() not in (None, previous), "replacement Activity")
    if android.pid() != process:
        raise RuntimeError("The process died instead of only recreating its Activity/engine")
    if not android.service_running():
        raise RuntimeError("The foreground service did not outlive engine replacement")
    wait_for(lambda: not android.service_running(), "replacement engine payment completion")
    android.expect_receipt()


def run_flavor(device, flavor, brands):
    """Builds, installs and runs every scenario for one flavor. True if all passed."""
    brand = next(entry for entry in brands if entry["id"] == flavor)
    gradle = (ROOT / "android/app/build.gradle.kts").read_text()
    base = re.search(r'applicationId = "([^"]+)"', gradle).group(1)
    namespace = re.search(r'namespace = "([^"]+)"', gradle).group(1)
    package = base + brand["applicationIdSuffix"]
    android = Android(device, package, f"{package}/{namespace}.MainActivity")
    android.require_emulator()
    directory = ROOT / "build/payment_integration"
    directory.mkdir(parents=True, exist_ok=True)
    report = {"flavor": flavor, "api": int(android.shell("getprop", "ro.build.version.sdk")),
              "scenarios": []}
    with (directory / f"{flavor}-lifecycle-build.log").open("w") as log:
        subprocess.run(["flutter", "build", "apk", "--debug", "--flavor", flavor,
                        "--target=lib/main.dart"], cwd=ROOT, stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=300)
    apk = ROOT / f"build/app/outputs/flutter-apk/app-{flavor}-debug.apk"
    android.command("install", "-r", "-t", str(apk), timeout=90)
    passed = True
    try:
        for name, scenario in [("background-and-return", background_and_return),
                               ("activity-and-engine-recreation", recreate_engine)]:
            started = time.monotonic()
            result = {"name": name, "passed": False}
            report["scenarios"].append(result)
            try:
                scenario(android)
                result["passed"] = True
                sys.stdout.write(f"PASS {flavor}: {name}\n")
            except Exception as error:  # a failed scenario must not hide the next flavor
                passed = False
                result["error"] = str(error)
                result["lastAppLabels"] = android.last_labels
                sys.stdout.write(f"FAIL {flavor}: {name}: {error}\n")
                break
            finally:
                result["seconds"] = round(time.monotonic() - started, 2)
                sys.stdout.flush()
    finally:
        (directory / f"{flavor}-lifecycle.json").write_text(json.dumps(report, indent=2) + "\n")
        android.cleanup()
    return passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--flavor", help="one brand id (default: every brand in android/brands.json)")
    args = parser.parse_args()
    brands = json.loads((ROOT / "android/brands.json").read_text())
    ids = [entry["id"] for entry in brands]
    if args.flavor and args.flavor not in ids:
        parser.error("flavor must be registered in android/brands.json")
    results = [run_flavor(args.device, flavor, brands) for flavor in ([args.flavor] if args.flavor else ids)]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
