#!/usr/bin/env python3
from obswebsocket import obsws, requests
import sys

try:
    ws = obsws("localhost", 4455)  # Default port, no password by default
    ws.connect()
    
    # Stop streaming/recording if active
    ws.call(requests.StopStream())
    ws.call(requests.StopRecord())
    ws.call(requests.StopVirtualCam())
    ws.call(requests.StopReplayBuffer())
    
    # Exit OBS
    ws.call(requests.Quit())
    ws.disconnect()
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
