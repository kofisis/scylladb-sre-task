# Quick Testing Checklist ✅

**Use this to verify everything is working. Takes ~5 minutes.**

---

## Test 1: Cluster Status ✅

**Command:**
```bash
./test_cluster_status.sh
```

**What to see:**
```
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens  Owns
UN  172.31.31.46     19.37 MB   256     33.3%
UN  172.31.27.44     18.95 MB   256     33.3%
UN  172.31.27.60     19.28 MB   256     33.3%
```

**✅ = PASS:** All 3 rows show `UN` (Up Normal)  
**❌ = FAIL:** Any row shows `DN`, `DL`, or other status

---

## Test 2a: Data on Node 1 ✅

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected:** `361`

**✅ = PASS:** Shows 361  
**❌ = FAIL:** Shows 0 or different number

---

## Test 2b: Data on Node 2 ✅

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected:** `361`

**✅ = PASS:** Shows 361  
**❌ = FAIL:** Shows 0 or different number

---

## Test 2c: Data on Node 3 ✅

**Command:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

**Expected:** `361`

**✅ = PASS:** Shows 361  
**❌ = FAIL:** Shows 0 or different number

**Summary:** If all 3 tests show 361, replication is working perfectly ✅

---

## Test 3: Full Analytics Query ✅

**Command:**
```bash
python3 analytics.py --start "2026-02-01" --end "2026-03-01"
```

**Expected output:**
```
======================================================================
CallDrop Call Success Rate Analysis
======================================================================

📊 Query Parameters:
   Date Range:    2026-02-01 to 2026-03-01
   User Phone:    All users

📈 Results:
   Total Calls:         312
   Successful Calls:    262
   Failed Calls:        50
   Success Rate:        83.97%

💡 Interpretation:
   ⚠️  Fair - Some call drops (83.97%)

======================================================================
```

**✅ = PASS:** 
- Script runs without error
- Shows 312 total calls
- Shows ~83-84% success rate

**❌ = FAIL:**
- Script gives error
- Shows 0 calls
- Shows very different success rate

---

## Test 4: Analytics with User Filter ✅

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

**✅ = PASS:**
- Script runs without error  
- Shows 18 total calls (for this user)
- Handles special characters (+)

**❌ = FAIL:**
- Script gives error
- Shows 0 calls
- Doesn't recognize phone number

---

## Summary

### If all 4 tests PASS ✅
You have successfully completed **Stage 1 & 2**:
- ✅ Cluster running
- ✅ Data replicated to all 3 nodes
- ✅ Analytics script working

**Next:** Email README.md + test results to hiring team for Stage 3

### If any test FAILS ❌

**Test 1 fails (cluster status):**
```bash
# A node might be down, restart it
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'sudo systemctl restart scylla-server'
sleep 30
./test_cluster_status.sh
```

**Tests 2a/2b/2c fail (data count):**
```bash
# Reload data
cd /Users/nana/Documents/Personal/scylladb_int
./load_data.sh
sleep 10
# Re-run tests 2a, 2b, 2c
```

**Test 3 or 4 fails (analytics):**
```bash
# Check if data exists first
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# If 0 records, run load_data.sh
# If records exist, try analytics again
python3 analytics.py --start "2026-02-01" --end "2026-03-01"
```

---

## Quick Reference

**All commands to copy-paste:**

```bash
# Test 1: Cluster status
./test_cluster_status.sh

# Test 2a: Node 1 data
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# Test 2b: Node 2 data
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# Test 2c: Node 3 data
ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135 'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# Test 3: Full analytics
python3 analytics.py --start "2026-02-01" --end "2026-03-01"

# Test 4: User filter analytics
python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"
```

---

**Status:** Ready to test  
**Time needed:** ~5 minutes  
**Success criteria:** All 4 tests PASS
