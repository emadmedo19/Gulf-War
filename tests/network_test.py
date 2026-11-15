"""Run two real ENet peers locally and verify input/snapshot exchange."""
import os
import subprocess
import time

command = ["godot", "--headless", "--audio-driver", "Dummy", "--path", ".", "--script", "res://tests/network.gd", "--"]
peers = []
try:
    peers.append(subprocess.Popen(command + ["host"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    time.sleep(0.6)
    peers.append(subprocess.Popen(command + ["guest"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    for name, process in zip(["host", "guest"], peers):
        output = process.communicate(timeout=15)[0]
        print(name + ":\n" + output)
        if process.returncode or "PASS: ENet" not in output or "SCRIPT ERROR" in output:
            raise SystemExit(1)
finally:
    for process in peers:
        if process.poll() is None:
            process.kill()
            process.wait()
