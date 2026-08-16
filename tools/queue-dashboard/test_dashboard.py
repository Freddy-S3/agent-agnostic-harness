"""Render the queue dashboard in Chromium and exercise every dashboard tab."""

from __future__ import annotations

import os
import socket
import subprocess
import tempfile
import time
from datetime import date
from pathlib import Path

from playwright.sync_api import Page, sync_playwright


ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT / "tools" / "queue-dashboard" / "server.mjs"
TODAY = date.today().isoformat()

PC_QUEUE = f"""## Open decision
Status: blocked
Blocked reason: Choose the next step.
Options:
- Keep it
- Change it
Log:
- {TODAY}: waiting for an answer.

## Answered decision
Status: blocked
DECIDED {TODAY} by Faruk, via the queue dashboard: Keep it
Blocked reason: The answer is already recorded.
Log:
- {TODAY}: ANSWERED by Faruk via the queue dashboard: Keep it

## Completed change
Status: done
Log:
- {TODAY}: completed.
"""

PHONE_QUEUE = f"""## Open phone item
Status: pending
Log:
- {TODAY}: waiting for the phone.
"""

STUDY = """## Reading
- [ ] Read the first chapter
- [x] Finish the introduction
"""


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_for_server(port: int) -> None:
    for _ in range(40):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                return
        except Exception:
            time.sleep(0.1)
    raise AssertionError("dashboard server did not start")


def contrast_ratio(page: Page, selector: str) -> float:
    return page.eval_on_selector(
        selector,
        """
        element => {
          const parse = value => value.match(/\\d+/g).map(Number);
          const relative = rgb => rgb.map(value => {
            const channel = value / 255;
            return channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
          });
          const luminance = color => {
            const [r, g, b] = relative(parse(color));
            return 0.2126 * r + 0.7152 * g + 0.0722 * b;
          };
          const style = getComputedStyle(element);
          const foreground = luminance(style.color);
          const background = luminance(style.backgroundColor);
          const light = Math.max(foreground, background);
          const dark = Math.min(foreground, background);
          return (light + 0.05) / (dark + 0.05);
        }
        """,
    )


def assert_no_overflow(page: Page) -> None:
    overflow = page.evaluate(
        "document.documentElement.scrollWidth - document.documentElement.clientWidth"
    )
    assert overflow <= 1, f"horizontal overflow: {overflow}px"


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="queue-dashboard-") as raw_dir:
        queue_dir = Path(raw_dir)
        (queue_dir / "QUEUE-PC.md").write_text(PC_QUEUE, encoding="utf-8")
        (queue_dir / "QUEUE-PHONE.md").write_text(PHONE_QUEUE, encoding="utf-8")
        (queue_dir / "STUDY.md").write_text(STUDY, encoding="utf-8")

        port = free_port()
        env = os.environ.copy()
        env.update(
            {
                "PORT": str(port),
                "QUEUE_DIR": str(queue_dir),
                "QUEUE_TOKEN": "dashboard-test-token",
                "GH_CONFIG_DIR": str(queue_dir / "gh-config"),
            }
        )
        server = subprocess.Popen(
            ["node", str(SERVER)],
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        screenshot_dir = Path(tempfile.gettempdir()) / "queue-dashboard-test-output"
        screenshot_dir.mkdir(parents=True, exist_ok=True)
        console_errors: list[str] = []
        request_failures: list[str] = []

        try:
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(headless=True)
                context = browser.new_context(viewport={"width": 1440, "height": 1000})
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

                url = f"http://127.0.0.1:{port}/"
                wait_for_server(port)
                context.add_cookies(
                    [
                        {
                            "name": "qd",
                            "value": "dashboard-test-token",
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

                queue_count = page.locator("#t-queue").inner_text()
                history_count = page.locator("#t-history").inner_text()
                assert queue_count == "2", f"queue count: {queue_count}"
                assert history_count == "2", f"history count: {history_count}"
                assert page.locator("#panel-queue .card").count() == 2
                assert page.locator("#panel-queue").get_by_text("Answered decision", exact=True).count() == 0
                assert page.locator("#panel-queue").get_by_text("Completed change", exact=True).count() == 0
                assert page.locator("img").evaluate_all(
                    "images => images.every(image => image.complete && image.naturalWidth > 0)"
                )

                page.locator("#tab-history").click()
                page.wait_for_selector("#panel-history:not([hidden])")
                assert page.url.endswith("#history")
                assert page.locator("#panel-history .history-card").count() == 2
                assert page.locator("#panel-queue[hidden]").count() == 1

                page.locator("#tab-reading-list").click()
                page.wait_for_selector("#panel-reading-list:not([hidden])")
                assert page.url.endswith("#reading-list")
                assert page.locator("#study .task").count() == 2
                assert page.locator("#panel-queue[hidden]").count() == 1
                page.locator("#study input[type=checkbox]").first.check()
                for _ in range(20):
                    if "[x] Read the first chapter" in (queue_dir / "STUDY.md").read_text(
                        encoding="utf-8"
                    ):
                        break
                    time.sleep(0.05)
                else:
                    raise AssertionError(
                        "reading-list tick did not reach STUDY.md: "
                        + page.locator("#study .said").inner_text()
                    )

                page.locator("#tab-queue").click()
                page.wait_for_selector("#panel-queue:not([hidden])")
                page.locator("#panel-queue .opt").first.click()
                for _ in range(20):
                    if f"DECIDED {TODAY}" in (queue_dir / "QUEUE-PC.md").read_text(
                        encoding="utf-8"
                    ):
                        break
                    time.sleep(0.05)
                else:
                    raise AssertionError("queue answer did not reach QUEUE-PC.md")

                for color_scheme in ("light", "dark"):
                    page.emulate_media(color_scheme=color_scheme)
                    for panel in ("queue", "history", "reading-list"):
                        page.locator(f"#tab-{panel}").click()
                        page.wait_for_selector(f"#panel-{panel}:not([hidden])")
                        for width in (1440, 834, 390):
                            page.set_viewport_size({"width": width, "height": 900})
                            page.wait_for_timeout(50)
                            assert_no_overflow(page)
                        ratio = contrast_ratio(page, ".tab[aria-selected=\"true\"]")
                        assert ratio >= 4.5, f"tab contrast {color_scheme}/{panel}: {ratio}"
                        page.screenshot(path=str(screenshot_dir / f"{color_scheme}-{panel}.png"))

                assert not console_errors, f"console errors: {console_errors}"
                assert not request_failures, f"failed requests: {request_failures}"
                browser.close()
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)

    print("dashboard browser checks passed")
    print(f"screenshots: {screenshot_dir}")


if __name__ == "__main__":
    main()
