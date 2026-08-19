"""Render the live queue dashboard through its Tailscale phone-facing address."""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
QUEUE_DIR = Path(os.environ.get("QUEUE_DIR", Path.home() / ".claude-harness" / "queue"))


def dashboard_url() -> str:
    configured = os.environ.get("QUEUE_DASHBOARD_URL")
    if configured:
        return configured.rstrip("/")
    exe = os.environ.get("TAILSCALE_EXE", "C:/Program Files/Tailscale/tailscale.exe")
    address = subprocess.check_output([exe, "ip", "-4"], text=True).strip().split()[0]
    port = os.environ.get("QUEUE_DASHBOARD_PORT", "4317")
    return f"http://{address}:{port}"


def assert_no_overflow(page) -> None:
    overflow = page.evaluate(
        "document.documentElement.scrollWidth - document.documentElement.clientWidth"
    )
    assert overflow <= 1, f"horizontal overflow: {overflow}px"


def main() -> None:
    url = dashboard_url()
    token = (QUEUE_DIR / ".dashboard-token").read_text(encoding="utf-8").strip()
    console_errors: list[str] = []
    request_failures: list[str] = []

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 390, "height": 844}, is_mobile=True, has_touch=True
        )
        page = context.new_page()
        page.on(
            "console",
            lambda message: console_errors.append(message.text)
            if message.type == "error"
            else None,
        )
        page.on(
            "requestfailed",
            lambda request: request_failures.append(
                f"{request.method} {request.url}: {request.failure}"
            ),
        )

        context.add_cookies(
            [
                {
                    "name": "qd",
                    "value": token,
                    "url": url,
                    "httpOnly": True,
                    "sameSite": "Strict",
                }
            ]
        )
        page.goto(url, wait_until="domcontentloaded")
        page.wait_for_selector("#panel-queue:not([hidden])")
        page.wait_for_function(
            "document.querySelector('#pulse').textContent.includes('LIVE')"
        )
        assert page.locator("[role=tab]").count() == 4
        assert page.locator("#panel-queue .card").count() > 0

        for panel in ("queue", "history", "reading-list", "jobs"):
            page.locator(f"#tab-{panel}").click()
            page.wait_for_selector(f"#panel-{panel}:not([hidden])")
            assert_no_overflow(page)

        screenshot = Path(tempfile.gettempdir()) / "queue-dashboard-phone.png"
        page.screenshot(path=str(screenshot), full_page=True)
        assert not console_errors, f"console errors: {console_errors}"
        assert not request_failures, f"failed requests: {request_failures}"
        browser.close()

    print(f"live phone dashboard checks passed: {url}")
    print(f"screenshot: {screenshot}")


if __name__ == "__main__":
    main()
