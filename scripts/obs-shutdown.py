#!/usr/bin/env python3
import websocket
import json
import sys
import subprocess
import hashlib
import base64
import time

PASSWORD = "JvPt8JrdfIalOTIq"

def obs_quit():
    ws = None
    try:
        ws = websocket.create_connection("ws://localhost:4456", timeout=3)
        ws.settimeout(5)
        
        # Receive Hello and authenticate
        hello_msg = ws.recv()
        hello_data = json.loads(hello_msg)
        
        auth_data = hello_data.get("d", {}).get("authentication")
        identify = {"op": 1, "d": {"rpcVersion": 1}}
        
        if auth_data:
            challenge = auth_data["challenge"]
            salt = auth_data["salt"]
            secret = base64.b64encode(
                hashlib.sha256((PASSWORD + salt).encode()).digest()
            ).decode()
            auth_response = base64.b64encode(
                hashlib.sha256((secret + challenge).encode()).digest()
            ).decode()
            identify["d"]["authentication"] = auth_response
        
        ws.send(json.dumps(identify))
        identified_msg = ws.recv()
        print(f"Authenticated", file=sys.stderr)
        
        # Stop ALL outputs before quitting
        outputs = [
            ("StopRecord", "stop-record"),
            ("StopStream", "stop-stream"),
            ("StopVirtualCam", "stop-virtualcam"),
            ("StopReplayBuffer", "stop-replay"),
        ]
        
        for request_type, request_id in outputs:
            cmd = {
                "op": 6,
                "d": {
                    "requestType": request_type,
                    "requestId": request_id
                }
            }
            ws.send(json.dumps(cmd))
            try:
                response = ws.recv()
                print(f"{request_type}: {response}", file=sys.stderr)
            except:
                pass
            time.sleep(0.3)
        
        # Now send Quit
        print("All outputs stopped, sending Quit...", file=sys.stderr)
        quit_cmd = {
            "op": 6,
            "d": {
                "requestType": "Quit",
                "requestId": "quit"
            }
        }
        ws.send(json.dumps(quit_cmd))
        
        # Wait for OBS to actually close
        time.sleep(2)
        
        # Check if it closed
        result = subprocess.run(["pgrep", "obs"], capture_output=True)
        if result.returncode == 0:
            print("OBS still running after Quit", file=sys.stderr)
            return False
        
        print("OBS quit successfully!", file=sys.stderr)
        return True
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return False
    finally:
        if ws:
            try:
                ws.close()
            except:
                pass

if __name__ == "__main__":
    if obs_quit():
        sys.exit(0)
    
    print("Force killing OBS", file=sys.stderr)
    subprocess.run(["pkill", "-9", "obs"])
    sys.exit(0)
