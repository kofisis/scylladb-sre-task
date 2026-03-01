#!/usr/bin/env python3
"""
CallDrop Cluster Connectivity Verifier
Tests SSH connectivity to all cluster nodes
"""

import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

NODES = {
    "Node 1": "16.147.230.26",
    "Node 2": "16.147.222.180",
    "Node 3": "18.236.162.135"
}

SSH_KEY = "~/.ssh/id_rsa_syclla"
SSH_USER = "ubuntu"
TIMEOUT = 10  # seconds


def test_node_connection(name, ip):
    """Test SSH connectivity to a node"""
    try:
        cmd = f"ssh -i {SSH_KEY} {SSH_USER}@{ip} 'echo OK' "
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=TIMEOUT
        )
        
        if result.returncode == 0 and "OK" in result.stdout:
            return (name, ip, True, "Connected")
        else:
            return (name, ip, False, "SSH failed")
    except subprocess.TimeoutExpired:
        return (name, ip, False, "Timeout")
    except Exception as e:
        return (name, ip, False, str(e))


def main():
    print("CallDrop Cluster Connectivity Test")
    print("=" * 50)
    print()
    
    # Test all nodes in parallel
    results = []
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = {
            executor.submit(test_node_connection, name, ip): (name, ip)
            for name, ip in NODES.items()
        }
        
        for future in as_completed(futures):
            result = future.result()
            results.append(result)
    
    # Print results
    all_ok = True
    for name, ip, connected, msg in sorted(results):
        status = "✓ OK" if connected else "✗ FAIL"
        print(f"{status}  {name:8} ({ip:18}): {msg}")
        if not connected:
            all_ok = False
    
    print()
    if all_ok:
        print("✓ All nodes are reachable")
        return 0
    else:
        print("✗ Some nodes are unreachable")
        return 1


if __name__ == "__main__":
    sys.exit(main())
