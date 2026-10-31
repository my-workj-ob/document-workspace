#!/usr/bin/env python3
"""
Cognidoc AI — Render Free Tier 24/7 Keep-Alive Pinger (Python)
Usage:
    python3 scripts/render_keep_alive.py
    # or with custom interval/URL:
    RENDER_URL="https://document-workspace-g59a.onrender.com/health/live" python3 scripts/render_keep_alive.py
"""

import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime

URL = os.getenv("RENDER_URL", "https://document-workspace-g59a.onrender.com/health/live")
INTERVAL = int(os.getenv("PING_INTERVAL_SEC", "600"))  # 10 minutes (Render sleeps after 15m)

def ping():
    req = urllib.request.Request(
        URL,
        headers={"User-Agent": "Cognidoc-KeepAlive-Bot/1.0", "Accept": "application/json"}
    )
    start_time = time.time()
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            latency = round(time.time() - start_time, 2)
            return response.status, latency, None
    except urllib.error.HTTPError as e:
        latency = round(time.time() - start_time, 2)
        return e.code, latency, str(e)
    except Exception as e:
        latency = round(time.time() - start_time, 2)
        return 0, latency, str(e)

def main():
    print("=" * 60)
    print("🚀 Cognidoc AI — Render Keep-Alive Service Boshlandi (Python)")
    print(f"🔗 Target URL : {URL}")
    print(f"⏱️  Interval   : Har {INTERVAL} soniyada ({INTERVAL // 60} daqiqa)")
    print("=" * 60)

    count = 0
    while True:
        count += 1
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        status, latency, err = ping()

        if status == 200:
            print(f"[{now}] #{count} [OK 200] Latency: {latency}s — Server faol va uyg'oq! ⚡", flush=True)
        elif status > 0:
            print(f"[{now}] #{count} [HTTP {status}] Latency: {latency}s — Javob: {err}", flush=True)
        else:
            print(f"[{now}] #{count} [XATO] Ulanib bo'lmadi: {err}. Qayta urinilmoqda...", flush=True)

        time.sleep(INTERVAL)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nKeep-alive to'xtatildi.")
        sys.exit(0)
