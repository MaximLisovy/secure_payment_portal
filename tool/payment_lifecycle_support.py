"""Helpers (adb, the accessibility tree) for tool/test_payment_lifecycle.py, which runs on an emulator only."""

from pathlib import Path
import re
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
UI_PATH = "/data/local/tmp/payment-portal-lifecycle.xml"


def adb_path():
    executable = shutil.which("adb")
    if executable:
        return executable
    properties = (ROOT / "android/local.properties").read_text()
    sdk = re.search(r"^sdk.dir=(.+)$", properties, re.MULTILINE)
    if not sdk:
        raise RuntimeError("Set adb on PATH or configure the local Android SDK")
    return str(Path(sdk.group(1)) / "platform-tools/adb")


def wait_for(check, stage, timeout=25):
    deadline = time.monotonic() + timeout
    while True:
        result = check()
        if result:
            return result
        if time.monotonic() >= deadline:
            raise RuntimeError(f"Timed out waiting for {stage}")
        time.sleep(0.2)


class Android:
    def __init__(self, serial, package, activity):
        self.adb = adb_path()
        self.serial = serial
        self.package = package
        self.activity = activity
        self.last_labels = []
        self.dump_error = ""

    def command(self, *arguments, timeout=30):
        result = subprocess.run(
            [self.adb, "-s", self.serial, *arguments],
            check=False, capture_output=True, text=True, timeout=timeout,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout

    def shell(self, *arguments):
        return self.command("shell", *arguments)

    def require_emulator(self):
        if self.shell("getprop", "ro.kernel.qemu").strip() != "1":
            raise RuntimeError("This runner resets app data and supports emulators only")

    def launch(self, recreate=False):
        # Intent.FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_CLEAR_TASK (API 11+).
        flags = ["-f", str(0x10000000 | 0x00008000)] if recreate else []
        output = self.shell("am", "start", *flags, "-n", self.activity)
        if "Error:" in output:
            raise RuntimeError(output)

    def reset(self):
        self.shell("am", "force-stop", self.package)
        if "Success" not in self.shell("pm", "clear", self.package):
            raise RuntimeError("Could not reset the test application's data")
        if int(self.shell("getprop", "ro.build.version.sdk").strip()) >= 33:
            self.shell("pm", "grant", self.package, "android.permission.POST_NOTIFICATIONS")
        self.launch()

    def nodes(self, timeout=20):
        """The app's accessibility nodes (possibly none).

        `uiautomator dump` can fail while the screen is animating or an Activity is being
        replaced: it prints an error and writes no file. That is retried, within `timeout`
        seconds, and only then reported with what the last attempt said.
        """
        deadline = time.monotonic() + timeout
        while True:
            nodes = self._dump_nodes()
            if nodes is not None:
                return nodes
            if time.monotonic() >= deadline:
                raise RuntimeError(
                    f"uiautomator gave no readable hierarchy within {timeout}s: {self.dump_error}")
            time.sleep(0.2)

    def _dump_nodes(self):
        """One dump attempt: the app's nodes, or None (and `dump_error` set) if it failed."""
        try:
            # Remove the last dump first, so a failed attempt cannot be mistaken for a new one.
            self.shell("rm", "-f", UI_PATH)
            said = self.shell("uiautomator", "dump", UI_PATH)
            if "dumped to" not in said:
                self.dump_error = said.strip() or "no output"
                return None
            root = ET.fromstring(self.shell("cat", UI_PATH))
        except (RuntimeError, ET.ParseError, subprocess.TimeoutExpired) as error:
            self.dump_error = str(error)
            return None
        nodes = [node for node in root.iter("node") if node.get("package") == self.package]
        self.last_labels = [self.label(node) for node in nodes if self.label(node)]
        return nodes

    @staticmethod
    def label(node):
        return node.get("content-desc") or node.get("text", "")

    def tap_pay(self):
        def find_button():
            return next((node for node in self.nodes()
                         if self.label(node).startswith("Pay ")
                         and node.get("clickable") == "true"
                         and node.get("enabled") == "true"), None)

        # ElementTree leaves can be falsey; keep the predicate explicitly boolean.
        selected = []

        def ready():
            node = find_button()
            if node is None:
                return False
            selected[:] = [node]
            return True

        wait_for(ready, "enabled Pay button")
        coordinates = [int(value) for value in re.findall(r"\d+", selected[0].get("bounds", ""))]
        if len(coordinates) != 4:
            raise RuntimeError("Pay button has no usable accessibility bounds")
        x1, y1, x2, y2 = coordinates
        self.shell("input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
        wait_for(self.service_running, "native foreground payment service", timeout=10)

    def service_running(self):
        dump = self.shell("dumpsys", "activity", "services", self.package)
        return "PaymentProcessingService" in dump and "isForeground=true" in dump

    def activity_identity(self):
        dump = self.shell("dumpsys", "activity", "activities")
        for line in dump.splitlines():
            if "topResumedActivity=" in line and f"{self.package}/" in line:
                match = re.search(r"ActivityRecord\{(\S+)", line)
                return match.group(1) if match else None
        return None

    def pid(self):
        return self.shell("pidof", self.package).strip()

    def expect_receipt(self):
        wait_for(lambda: any(self.label(node) == "Payment successful" for node in self.nodes()),
                 "payment receipt")
        count = sum(self.label(node) == "Payment successful" for node in self.nodes())
        if count != 1:
            raise RuntimeError(f"Expected one receipt, found {count}")

    def cleanup(self):
        self.shell("am", "force-stop", self.package)
        self.shell("rm", "-f", UI_PATH)
