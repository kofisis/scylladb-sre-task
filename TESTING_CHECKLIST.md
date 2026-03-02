# Complete Infrastructure Testing Checklist ✅

**Full validation of all 5 nodes: 3 cluster + 1 monitoring + 1 client**

**Time needed:** ~2-3 minutes | **Success criteria:** All 9 tests PASS

---

## Test 1: Cluster Status ✅

**What:** Verify all 3 ScyllaDB nodes are UP/NORMAL

**Command:**
```bash
./test_cluster_status.sh
```

**Expected output:**
```
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
UN  172.31.31.46    733.60 KB  1
UN  172.31.27.44    738.21 KB  1
UN  172.31.27.60    731.76 KB  1
```

**✅ PASS:** All 3 rows show `UN` (Up/Normal)  
**❌ FAIL:** Any row shows `DN`, `DL`, or different status

---

## Test 2a: Node 1 Data Replication ✅

**What:** Verify 361 records exist on Node 1

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected output:** `361`

**✅ PASS:** Shows `361`  
**❌ FAIL:** Shows `0` or different number

---

## Test 2b: Node 2 Data Replication ✅

**What:** Verify 361 records exist on Node 2

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected output:** `361`

**✅ PASS:** Shows `361`  
**❌ FAIL:** Shows `0` or different number

---

## Test 2c: Node 3 Data Replication ✅

**What:** Verify 361 records exist on Node 3

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected output:** `361`

**✅ PASS:** Shows `361`  
**❌ FAIL:** Shows `0` or different number

---

## Test 3: Analytics - Global Query ✅

**What:** Run analytics on all users in February 2026

**Command:**
```bash
python3 analytics.py --start "2026-02-01" --end "2026-03-01"
```

**Expected output:**
```
Total Calls:         312
Successful Calls:    262
Failed Calls:        50
Success Rate:        83.97%
```

**✅ PASS:** 
- Shows 312 total calls
- Shows ~83-84% success rate
- No errors

**❌ FAIL:**
- Shows 0 calls
- Shows error
- Very different success rate

---

## Test 4: Analytics - User Filter Query ✅

**What:** Run analytics for specific user (+11000000000)

**Command:**
```bash
python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"
```

**Expected output:**
```
Total Calls:         18
Successful Calls:    16
Failed Calls:        2
Success Rate:        88.89%
```

**✅ PASS:**
- Shows 18 total calls
- Handles phone number with special characters
- No errors

**❌ FAIL:**
- Shows 0 calls
- Shows error
- Doesn't recognize phone format

---

## Test 5a: Monitoring Node - Prometheus Targets ✅

**What:** Verify Prometheus is scraping metrics from all 3 cluster nodes

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@34.213.177.187 \
  'curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep "health"'
```

**Expected output:**
```json
"health": "up",
"health": "up",
"health": "up",
"health": "up",
```

(4 "up" entries: Prometheus self + 3 cluster nodes)

**✅ PASS:**
- Shows 4x "health": "up"
- All targets actively scraping
- No connection errors

**❌ FAIL:**
- Shows "health": "down"
- Connection refused to http://localhost:9090
- Cannot SSH to monitoring node

---

## Test 5b: Monitoring Node - Grafana Datasource ✅

**What:** Verify Grafana is connected to Prometheus

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@34.213.177.187 \
  'curl -s http://localhost:3000/api/datasources | python3 -m json.tool | grep -E "name|type|url"'
```

**Expected output:**
```json
"name": "Prometheus",
"type": "prometheus",
"url": "http://promotheus:9090",
```

**✅ PASS:**
- Shows Prometheus datasource
- Type is "prometheus"
- Datasource is active

**❌ FAIL:**
- Empty datasource list
- Connection refused on port 3000
- Datasource marked as inactive

---

## Test 5c: Monitoring Node - Real Metrics ✅

**What:** Verify Prometheus is actively collecting ScyllaDB metrics

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@34.213.177.187 \
  'curl -s "http://localhost:9090/api/v1/query?query=scylla_node_operation_mode" | python3 -m json.tool | grep -E "instance|value"'
```

**Expected output:**
```json
"instance": "172.31.31.46:9180",
"value": ["1772411707.312", "3"],
"instance": "172.31.27.44:9180",
"value": ["1772411707.312", "3"],
"instance": "172.31.27.60:9180",
"value": ["1772411707.312", "3"],
```

(3 instances with value "3" = all nodes in NORMAL mode)

**✅ PASS:**
- Shows 3 instances
- All values show "3" (NORMAL)
- Timestamps are recent (<1 min old)

**❌ FAIL:**
- Shows 0 instances
- Old timestamps (>5 min old)
- Connection to Prometheus fails

---

## Test 6a: Client Node - Connectivity ✅

**What:** Verify client can reach cluster AND monitoring stack

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 \
  'nc -zv 172.31.31.46 9042 && nc -zv 34.213.177.187 9090 && echo "✅ All connections successful"'
```

**Expected output:**
```
Connection to 172.31.31.46 9042 port [tcp/*] succeeded!
Connection to 34.213.177.187 9090 port [tcp/*] succeeded!
✅ All connections successful
```

**✅ PASS:**
- Both ports report "succeeded"
- No timeouts
- Client can reach both services

**❌ FAIL:**
- "Connection refused" 
- "Host unreachable"
- "Resource temporarily unavailable"

---

## Test 6b: Client Node - Python Setup ✅

**What:** Verify client has Python 3 and required modules

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 \
  'python3 -c "import subprocess, argparse, datetime; print(\"✅ Python + required modules OK\")"'
```

**Expected output:**
```
✅ Python + required modules OK
```

**✅ PASS:**
- Command runs without error
- All imports succeed

**❌ FAIL:**
- "ModuleNotFoundError"
- "Python not found"
- Syntax error

---

## Test 6c: Client Node - SSH Chain to Cluster ✅

**What:** Verify client can SSH to cluster nodes (for running analytics)

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 \
  'ssh -i ~/.ssh/id_rsa_syclla ubuntu@172.31.31.46 "echo ✅ SSH Chain successful"'
```

**Expected output:**
```
✅ SSH Chain successful
```

**✅ PASS:**
- SSH chain works
- Authentication succeeds
- Can reach cluster from client

**❌ FAIL:**
- "Permission denied"
- "Connection refused"
- "Could not resolve hostname"

---

## Master Test Suite - Copy & Paste All 9 Tests

Run this entire block to test everything at once:

```bash
#!/bin/bash
# Complete 9-test validation suite

echo "Starting complete infrastructure test suite..."
echo "=============================================="

# TEST 1
echo -e "\n📌 TEST 1: Cluster Status"
./test_cluster_status.sh | grep "UN" | wc -l

# TEST 2a
echo -e "\n📌 TEST 2a: Node 1 Data Count"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# TEST 2b
echo -e "\n📌 TEST 2b: Node 2 Data Count"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# TEST 2c
echo -e "\n📌 TEST 2c: Node 3 Data Count"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# TEST 3
echo -e "\n📌 TEST 3: Analytics Global"
python3 analytics.py --start "2026-02-01" --end "2026-03-01"

# TEST 4
echo -e "\n📌 TEST 4: Analytics User Filter"
python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"

# TEST 5a
echo -e "\n📌 TEST 5a: Prometheus Targets"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@34.213.177.187 'curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep "health"'

# TEST 5b
echo -e "\n📌 TEST 5b: Grafana Datasources"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@34.213.177.187 'curl -s http://localhost:3000/api/datasources | python3 -m json.tool | grep -E "name|type"'

# TEST 5c
echo -e "\n📌 TEST 5c: Prometheus Metrics"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@34.213.177.187 'curl -s "http://localhost:9090/api/v1/query?query=scylla_node_operation_mode" | python3 -m json.tool | grep instance'

# TEST 6a
echo -e "\n📌 TEST 6a: Client Connectivity"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 'nc -zv 172.31.31.46 9042 && nc -zv 34.213.177.187 9090'

# TEST 6b
echo -e "\n📌 TEST 6b: Client Python"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 'python3 -c "import subprocess, argparse, datetime; print(\"✅ Python OK\")"'

# TEST 6c
echo -e "\n📌 TEST 6c: Client SSH Chain"
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 'ssh -i ~/.ssh/id_rsa_syclla ubuntu@172.31.31.46 "echo ✅ SSH OK"'

echo -e "\n=============================================="
echo "Test suite complete!"
```

---

## Expected Success Indicators

**Cluster Tests (1-4):** 
```
✅ Test 1: 3 (all nodes UN)
✅ Test 2a: 361 records
✅ Test 2b: 361 records
✅ Test 2c: 361 records
✅ Test 3: 312 calls, 83.97%
✅ Test 4: 18 calls, 88.89%
```

**Monitoring Tests (5a-5c):**
```
✅ Test 5a: 4x "health": "up"
✅ Test 5b: Prometheus datasource found
✅ Test 5c: 3 instances with NORMAL mode
```

**Client Tests (6a-6c):**
```
✅ Test 6a: 2x succeeded!
✅ Test 6b: ✅ Python OK
✅ Test 6c: ✅ SSH OK
```

---

## Troubleshooting

**Test 1 fails (cluster not UP):**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'sudo systemctl restart scylla-server'
sleep 30
./test_cluster_status.sh
```

**Tests 2a/2b/2c fail (no data):**
```bash
./load_data.sh
sleep 10
# Re-run tests 2a, 2b, 2c
```

**Tests 3-4 fail (analytics error):**
```bash
# Check data exists first
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
# If 0, run load_data.sh
# Otherwise, try analytics again
```

**Tests 5a/5b fail (monitoring down):**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@34.213.177.187 'sudo systemctl restart prometheus grafana-server'
sleep 10
# Retry test
```

**Tests 5c fails (metrics not flowing):**
```bash
# Check cluster nodes are metrics-enabled
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'curl -s localhost:9180/metrics | head -5'
```

**Tests 6a/6b/6c fail (client issues):**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 'ping 172.31.31.46'
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.145.54.108 'python3 --version'
```

---

## Summary

| Component | Tests | Status |
|-----------|-------|--------|
| **ScyllaDB Cluster (3 nodes)** | 1, 2a, 2b, 2c | ✅ |
| **Analytics Scripts** | 3, 4 | ✅ |
| **Monitoring Stack (1 node)** | 5a, 5b, 5c | ✅ |
| **Client Node (1 node)** | 6a, 6b, 6c | ✅ |
| **Total Infrastructure** | 9 tests | ✅ |

**All systems ready for Stage 3** when all 9 tests pass.
