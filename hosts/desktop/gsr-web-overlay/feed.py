import argparse
import base64
import io
import json
import mmap
import os
import signal
import struct
import subprocess
import sys
import time
import urllib.request
from string import Template

from PIL import Image
from websockets.sync.client import connect

# Must match plugin.c. The file is never shrunk: gpu-screen-recorder keeps it
# mapped, and a shorter file turns its next read into SIGBUS.
MAGIC = 0x31574F47  # "GOW1"
HEADER = struct.Struct("<IIII")
MAX_W, MAX_H = 2048, 2048
SIZE = HEADER.size + MAX_W * MAX_H * 4


class Shm:
    def __init__(self, path):
        fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o600)
        if os.fstat(fd).st_size < SIZE:
            os.ftruncate(fd, SIZE)
        self.map = mmap.mmap(fd, SIZE)
        os.close(fd)
        self.seq = HEADER.unpack_from(self.map, 0)[1] & ~1

    def write(self, w, h, pixels):
        HEADER.pack_into(self.map, 0, MAGIC, self.seq + 1, w, h)
        self.map[HEADER.size:HEADER.size + len(pixels)] = pixels
        self.seq += 2
        HEADER.pack_into(self.map, 0, MAGIC, self.seq, w, h)


# Widgets made for OBS tend to redraw on every animation frame; at 60 fps the
# headless render plus PNG round trip costs close to half a core.
THROTTLE = Template("""
(() => {
  const interval = 1000 / $fps;
  window.requestAnimationFrame = cb => setTimeout(() => cb(performance.now()), interval);
  window.cancelAnimationFrame = id => clearTimeout(id);
  document.addEventListener("DOMContentLoaded", () => {
    const style = document.createElement("style");
    style.textContent = "*, *::before, *::after { transition: none !important; animation: none !important; }";
    document.head.appendChild(style);
  });
})();
""")


def frame_to_rgba(png):
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    bbox = img.getchannel("A").getbbox()
    if not bbox:
        return 0, 0, b""
    img = img.crop(bbox)
    if img.width > MAX_W or img.height > MAX_H:
        img = img.crop((0, 0, min(img.width, MAX_W), min(img.height, MAX_H)))
    return img.width, img.height, img.tobytes()


def devtools_port(profile, chrome):
    path = os.path.join(profile, "DevToolsActivePort")
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if chrome.poll() is not None:
            sys.exit(f"chromium exited with {chrome.returncode}")
        try:
            with open(path) as f:
                return int(f.readline())
        except (FileNotFoundError, ValueError):
            time.sleep(0.1)
    sys.exit("chromium did not open a DevTools port")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("url")
    ap.add_argument("--shm", required=True)
    ap.add_argument("--profile", required=True)
    ap.add_argument("--chromium", default="chromium")
    ap.add_argument("--width", type=int, default=400)
    ap.add_argument("--height", type=int, default=300)
    ap.add_argument("--scale", type=float, default=2.0)
    ap.add_argument("--fps", type=float, default=5.0)
    args = ap.parse_args()

    shm = Shm(args.shm)
    shm.write(0, 0, b"")

    def clear_and_exit(*_):
        shm.write(0, 0, b"")
        sys.exit(0)

    signal.signal(signal.SIGTERM, clear_and_exit)
    signal.signal(signal.SIGINT, clear_and_exit)

    profile = args.profile
    os.makedirs(profile, exist_ok=True)
    try:
        os.remove(os.path.join(profile, "DevToolsActivePort"))
    except FileNotFoundError:
        pass
    chrome = subprocess.Popen([
        args.chromium, "--headless=new", "--remote-debugging-port=0",
        f"--user-data-dir={profile}", "--no-first-run", "--mute-audio",
        "--hide-scrollbars", "--disable-gpu",
        f"--force-device-scale-factor={args.scale}",
        f"--window-size={args.width},{args.height}", "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    try:
        port = devtools_port(profile, chrome)
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list") as r:
            page = next(t for t in json.load(r) if t["type"] == "page")
        run(page["webSocketDebuggerUrl"], args, shm)
    finally:
        shm.write(0, 0, b"")
        chrome.terminate()
        chrome.wait()


def run(ws_url, args, shm):
    with connect(ws_url, max_size=None) as ws:
        next_id = 0

        def send(method, **params):
            nonlocal next_id
            next_id += 1
            ws.send(json.dumps({"id": next_id, "method": method, "params": params}))

        send("Emulation.setDefaultBackgroundColorOverride",
             color={"r": 0, "g": 0, "b": 0, "a": 0})
        send("Page.addScriptToEvaluateOnNewDocument",
             source=THROTTLE.substitute(fps=args.fps))
        send("Inspector.enable")
        send("Page.enable")
        send("Page.navigate", url=args.url)
        send("Page.startScreencast", format="png", maxWidth=MAX_W, maxHeight=MAX_H)

        # Chromium's own error page must never reach the video.
        loaded = False
        for raw in ws:
            msg = json.loads(raw)
            method = msg.get("method")
            if method == "Page.screencastFrame":
                p = msg["params"]
                send("Page.screencastFrameAck", sessionId=p["sessionId"])
                if loaded:
                    shm.write(*frame_to_rgba(base64.b64decode(p["data"])))
            elif method == "Page.frameNavigated":
                frame = msg["params"]["frame"]
                if "parentId" in frame:
                    continue
                loaded = "unreachableUrl" not in frame
                if not loaded:
                    shm.write(0, 0, b"")
                    time.sleep(5)
                    send("Page.navigate", url=args.url)
            elif method == "Inspector.targetCrashed":
                sys.exit("page crashed")


if __name__ == "__main__":
    main()
