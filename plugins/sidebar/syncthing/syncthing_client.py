#!/usr/bin/env -S uv run
# /// script
# dependencies = []
# ///

import json
import os
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

CONFIG_PATH = os.path.expanduser("~/.config/syncthing/config.xml")
HOST = os.environ.get("STGN_HOST") or "http://localhost:8091"
API_KEY = os.environ.get("STGN_API_KEY")


def discover_config():
    global HOST, API_KEY
    if os.path.exists(CONFIG_PATH):
        try:
            tree = ET.parse(CONFIG_PATH)
            root = tree.getroot()
            gui = root.find("gui")
            if gui is not None:
                apikey = gui.find("apikey")
                if apikey is not None and apikey.text:
                    API_KEY = apikey.text.strip()
                address = gui.find("address")
                if (
                    address is not None
                    and address.text
                    and "STGN_HOST" not in os.environ
                ):
                    addr = address.text.strip()
                    tls = gui.get("tls", "false").lower() == "true"
                    proto = "https" if tls else "http"
                    HOST = f"{proto}://{addr}"
        except Exception:
            pass

    API_KEY = os.environ.get("STGN_API_KEY") or API_KEY

    if not API_KEY:
        noon_cfg = Path(os.path.expanduser("~/.config/noon/syncthing.conf"))
        if noon_cfg.exists():
            try:
                for line in noon_cfg.read_text().strip().splitlines():
                    if line.startswith("STGN_API_KEY="):
                        API_KEY = line.split("=", 1)[1].strip()
                        break
            except Exception:
                pass


def fetch(endpoint):
    req = urllib.request.Request(f"{HOST}{endpoint}")
    req.add_header("X-API-Key", API_KEY)
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")[:200] if e.fp else ""
        return {"_error": f"HTTP {e.code}: {body or e.reason}"}
    except urllib.error.URLError as e:
        reason = str(e.reason)
        if "111" in reason:
            return {"_error": "Syncthing not running (connection refused)"}
        return {"_error": f"Connection failed: {reason}"}
    except Exception as e:
        return {"_error": str(e)}


def do_post(endpoint):
    req = urllib.request.Request(f"{HOST}{endpoint}", method="POST")
    req.add_header("X-API-Key", API_KEY)
    try:
        with urllib.request.urlopen(req, timeout=5):
            return {"_ok": True}
    except Exception as e:
        return {"_error": str(e)}


discover_config()
output_file = os.environ.get("STGN_DATA_FILE")

if not output_file:
    print(json.dumps({"error": "STGN_DATA_FILE not set"}), file=sys.stderr)
    sys.exit(1)

if not API_KEY:
    result = {
        "connected": False,
        "connectionStatus": "No API key — configure syncthing or set STGN_API_KEY",
        "systemInfo": {},
        "folders": {},
        "devices": {},
        "connections": {},
        "events": [],
        "actionFeedback": "",
    }
    with open(output_file, "w") as f:
        json.dump(result, f)
    sys.exit(0)


def write_data(action_feedback=""):
    system_info = fetch("/rest/system/status")
    connections = fetch("/rest/system/connections")
    config = fetch("/rest/system/config")
    raw_events = fetch("/rest/events?since=0&limit=30")

    if "_error" in system_info:
        result = {
            "connected": False,
            "connectionStatus": system_info["_error"],
            "systemInfo": {},
            "folders": {},
            "devices": {},
            "connections": {},
            "events": [],
            "actionFeedback": action_feedback,
        }
        with open(output_file, "w") as f:
            json.dump(result, f)
        return

    config_folders = config.get("folders", []) if "_error" not in config else []
    config_devices = config.get("devices", []) if "_error" not in config else []

    folders = {}
    for folder in config_folders:
        fid = folder["id"]
        comp = fetch(f"/rest/db/completion?folder={fid}")
        folders[fid] = {
            "id": fid,
            "label": folder.get("label", fid),
            "path": folder.get("path", ""),
            "type": folder.get("type", "sendreceive"),
            "paused": folder.get("paused", False),
            "completion": round(comp.get("completion", 0))
            if "_error" not in comp
            else 0,
            "globalBytes": comp.get("globalBytes", 0),
            "needBytes": comp.get("needBytes", 0),
            "needFiles": comp.get("needFiles", 0),
            "needDeletes": comp.get("needDeletes", 0),
        }

    devices = {}
    conns = connections.get("connections", {}) if "_error" not in connections else {}
    for device in config_devices:
        did = device["deviceID"]
        short_id = did[:7] + "…"
        conn_info = conns.get(did, {})
        devices[did] = {
            "deviceID": did,
            "shortID": short_id,
            "name": device.get("name", short_id),
            "compression": device.get("compression", "never"),
            "introducer": device.get("introducer", False),
            "connected": conn_info.get("connected", False),
            "address": conn_info.get("address", ""),
            "inBytesTotal": conn_info.get("inBytesTotal", 0),
            "outBytesTotal": conn_info.get("outBytesTotal", 0),
            "paused": device.get("paused", False),
        }

    events = []
    if isinstance(raw_events, list) and not isinstance(raw_events, dict):
        for e in raw_events[-20:]:
            if e.get("type") in (
                "StateChanged",
                "RemoteIndexUpdated",
                "LocalIndexUpdated",
                "ItemStarted",
                "ItemFinished",
            ):
                evt = {
                    "id": e.get("id"),
                    "type": e.get("type"),
                    "time": e.get("time", ""),
                    "data": {},
                }
                d = e.get("data", {})
                if e["type"] in ("ItemStarted", "ItemFinished"):
                    evt["data"] = {
                        "folder": d.get("folder", ""),
                        "item": d.get("item", ""),
                        "action": "updated",
                    }
                    if e["type"] == "ItemFinished":
                        evt["data"]["error"] = d.get("error")
                elif e["type"] == "StateChanged":
                    evt["data"] = {
                        "folder": d.get("folder", ""),
                        "from": d.get("from", ""),
                        "to": d.get("to", ""),
                    }
                else:
                    evt["data"] = {"folder": d.get("folder", "")}
                events.append(evt)

    result = {
        "connected": True,
        "connectionStatus": "Connected",
        "systemInfo": {
            k: system_info.get(k)
            for k in [
                "myID",
                "version",
                "uptime",
                "cpuPercent",
                "memUsageMB",
                "guiAddressOverride",
                "lastDialSuccess",
            ]
        },
        "folders": folders,
        "devices": devices,
        "connections": {
            "totalIn": conns.get("totalIn", 0),
            "totalOut": conns.get("totalOut", 0),
        },
        "events": events,
        "actionFeedback": action_feedback,
    }

    with open(output_file, "w") as f:
        json.dump(result, f)


if len(sys.argv) > 1:
    cmd = sys.argv[1]
    feedback = ""

    if cmd == "pause" and len(sys.argv) > 2:
        r = do_post(f"/rest/db/pause?folder={sys.argv[2]}")
        feedback = (
            "Paused " + sys.argv[2] if "_ok" in r else "Failed: " + r.get("_error", "")
        )
    elif cmd == "resume" and len(sys.argv) > 2:
        r = do_post(f"/rest/db/resume?folder={sys.argv[2]}")
        feedback = (
            "Resumed " + sys.argv[2] if "_ok" in r else "Failed: " + r.get("_error", "")
        )
    elif cmd == "rescan" and len(sys.argv) > 2:
        r = do_post(f"/rest/db/scan?folder={sys.argv[2]}")
        feedback = (
            "Rescanning " + sys.argv[2]
            if "_ok" in r
            else "Failed: " + r.get("_error", "")
        )
    elif cmd == "device-pause" and len(sys.argv) > 2:
        r = do_post(f"/rest/system/pause?device={sys.argv[2]}")
        feedback = "Paused device" if "_ok" in r else "Failed: " + r.get("_error", "")
    elif cmd == "device-resume" and len(sys.argv) > 2:
        r = do_post(f"/rest/system/resume?device={sys.argv[2]}")
        feedback = "Resumed device" if "_ok" in r else "Failed: " + r.get("_error", "")
    elif cmd == "restart":
        do_post("/rest/system/restart")
        feedback = "Syncthing restarting…"
    elif cmd == "refresh":
        pass
    else:
        pass

    write_data(feedback)
    print(feedback)
else:
    write_data()
