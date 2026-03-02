# CallDrop ScyllaDB Technical Assessment

**Status:** ✅ Stage 1 & 2 Complete | Ready for Stage 3

---

## 📋 What You Have

A **3-node ScyllaDB cluster** with:
- ✅ Cluster operational (all nodes UP/Normal)
- ✅ Call records schema created and replicated  
- ✅ 361 sample call records loaded
- ✅ Analytics script to query success rates

**Time to complete:** ~3 minutes to verify everything works

---

## 🚀 Quick Testing (Run These 3 Commands)

### Test 1: Verify All 3 Nodes Are Running
```bash
./test_cluster_status.sh
```

**What to look for:**
```
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens  Owns
UN  172.31.31.46     19.37 MB   256     33.3%
UN  172.31.27.44     18.95 MB   256     33.3%
UN  172.31.27.60     19.28 MB   256     33.3%
```

**What this means:**
- `UN` = Up and Normal ✅
- All 3 nodes present (172.31.x.x = internal IPs)
- Load values are similar across nodes (balanced)
- Tokens are 256 each (correct)
- Owns 33.3% each (perfectly balanced)

---

### Test 2: Check Data Loaded on Each Node

**Count records on Node 1:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected result:** `361`

**Count records on Node 2:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected result:** `361`

**Count records on Node 3:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected result:** `361`

**What this means:**
- All 3 nodes have exactly the same data (361 records each)
- Replication working perfectly
- No data loss or inconsistency

---

### Test 3: Run Analytics to Get Call Success Rate

**Get success rate for all calls in February 2026:**
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

**What this means:**
- Out of 312 total call records in that date range
- 262 calls succeeded (262 ÷ 312 = 83.97%)
- 50 calls failed
- This is the network's performance metric

**Test with a specific user:**
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

**What this means:**
- User +11000000000 made 18 calls in that date range
- 16 succeeded, 2 failed
- Their success rate is 88.89% (better than network average)

---

## 📊 Understanding the Results

### Node Status Interpretation

| Status | Meaning |
|--------|---------|
| **UN** | Up and Normal ✅ (everything is working) |
| **UL** | Up and Leaving (node is shutting down) |
| **DL** | Down and Leaving (node is offline) |
| **DN** | Down and Normal (node is offline) |

### Data Counts Interpretation

| Scenario | Meaning |
|----------|---------|
| All 3 nodes = 361 | ✅ Perfect - Replication working |
| Different counts | ⚠️ Problem - Replication issue |
| Node shows 0 | ❌ Problem - Node lost data |

### Success Rate Interpretation

| Rate | Meaning |
|------|---------|
| ≥95% | ✅ Excellent network quality |
| ≥90% | ✅ Good network quality |
| ≥85% | ⚠️ Fair (some call drops) |
| <85% | ❌ Poor (many failures) |

---

## 🎯 Completing the Task

You have completed **Stage 1 & 2** of the technical assessment:

### ✅ Stage 1: Infrastructure (DONE)
- [x] Deploy 3-node ScyllaDB cluster
- [x] All nodes UP/Normal
- [x] Port 9042 listening on all nodes
- [x] Replication working (RF=3)

### ✅ Stage 2: Data & Analytics (DONE)
- [x] Create keyspace `calldrop`
- [x] Create table `call_records` with correct schema
- [x] Create materialized views (successful/failed calls)
- [x] Load 361 sample call records
- [x] Create analytics script (time-range + phone filtering)

### ⏳ Stage 3: Ready When (NEXT)
- Receive dataset from hiring team
- Load production-scale data
- Run analytics on full dataset
- Analyze performance metrics

---

## 💾 What Files You Have

| File | Purpose |
|------|---------|
| `analytics.py` | Query script (success rate calculator) |
| `load_data.sh` | Data loader script |
| `test_cluster_status.sh` | Cluster status checker |
| `verify_cluster.py` | Connection tester |
| `README.md` | This file |
| `TECHNICAL_REFERENCE.md` | Schema & architecture details |

---

## 🔄 If Tests Fail

**Node shows DOWN:**
```bash
# Try restarting the node
ssh -i ~/.ssh/id_rsa_syclla ubuntu@NODE_IP \
  'sudo systemctl restart scylla-server'

# Wait 30 seconds, then re-run test_cluster_status.sh
sleep 30
./test_cluster_status.sh
```

**Data count is 0:**
```bash
# Reload data
./load_data.sh
```

**Analytics script gives error:**
```bash
# Check script syntax
python3 analytics.py --help

# Try simple query first (no phone filter)
python3 analytics.py --start "2026-02-01" --end "2026-03-01"
```

---

## 📞 Quick Reference

### SSH into any node:
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26    # Node 1
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180   # Node 2
ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135   # Node 3
```

### Check cluster from inside any node:
```bash
# SSH to any node first, then:
nodetool status -u cassandra -pw cassandra
```

### Manually query the database:
```bash
# SSH to any node first, then:
cqlsh localhost 9042
> SELECT COUNT(*) FROM calldrop.call_records;
> SELECT * FROM calldrop.call_records LIMIT 5;
> EXIT;
```

### See sample data:
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT * FROM calldrop.call_records LIMIT 5;"'
```

---



---

## 🎓 What Each Component Does

### Cluster (3 Nodes)
The actual database. Stores call records. To use it, you query it via CQL.

### Analytics.py
A Python script that asks the cluster questions like:
- "How many calls happened between Feb 1 and Mar 1?"
- "How many of those succeeded vs failed?"
- Calculates the percentage

### Data
361 sample call records representing 15 users making 20-25 calls each with realistic success rates.

---

**Ready to test? Run these 3 commands and you're done!**

```bash
./test_cluster_status.sh
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
python3 analytics.py --start "2026-02-01" --end "2026-03-01"
```
