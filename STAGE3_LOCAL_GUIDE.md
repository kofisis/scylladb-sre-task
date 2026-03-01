# Stage 3 - Local Guide for Receiving Production Dataset

**This is your personal guide.** Do not send this to the hiring team.

---

## 📋 When You Receive the Dataset

The hiring team will provide:
1. A dataset file (CSV, JSON, or loading script)
2. Instructions specific to their format
3. Estimated data size and load time

---

## 🚀 Step 1: Verify Cluster Health (Before Loading)

```bash
cd /Users/nana/Documents/Personal/scylladb_int
./scripts/test_cluster_status.sh
```

**Expected Output:**
```
✓ PASS: All 3 nodes are reachable via SSH
✓ PASS: All 3 nodes have port 9042 (CQL) listening
✓ PASS: All 3 nodes have 361 replicated records
✓ ALL TESTS PASSED
```

If not all green, contact them mentioning cluster needs attention.

---

## 📥 Step 2: Load Their Dataset

**Option A - If they give you a CSV file:**
```bash
# Ask for their specific loading instructions
# Usually something like:
python3 their_load_script.py --file their_data.csv
```

**Option B - If they give you a shell script:**
```bash
chmod +x their_load_script.sh
./their_load_script.sh
```

**Option C - If they give you raw CQL statements:**
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26
cqlsh localhost 9042

# Then copy-paste their CQL statements
# Type: EXIT to quit
```

---

## ✅ Step 3: Verify Data Loaded Successfully

```bash
# Count total records (should be much larger than 361)
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# Verify all 3 nodes have same count
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# All three should show the same number
```

---

## 🔍 Step 4: Check Cluster Still Healthy

```bash
./scripts/test_cluster_status.sh
```

All tests should still pass (even with more data).

---

## 📊 Step 5: Run Analytics on Full Dataset

The hiring team will likely ask: "What's the overall success rate?"

```bash
# Basic analytics on full date range
python3 scripts/analytics.py --start "2026-02-01" --end "2026-03-01"
```

**Output will look like:**
```
Total Calls:         [large number]
Successful Calls:    [large number]
Failed Calls:        [some number]
Success Rate:        XX.XX%
```

Save this output - they'll ask for it.

---

## 📊 Step 6: Analyze Shard Distribution

They're likely to ask about data distribution. Check this:

```bash
# Sample query to see distribution
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'cqlsh localhost 9042' << EOF
SELECT user_phone, COUNT(*) as call_count 
FROM calldrop.call_records 
GROUP BY user_phone;

EXIT;
EOF
```

This will tell you:
- Do some users have way more calls than others? (hot spots)
- Is distribution even?
- Any unexpected patterns?

**Document your findings** in `analysis/shard_imbalance.md` - see that file for the format.

---

## 📝 Step 7: Fill in analysis/shard_imbalance.md

Edit this file with your findings:
```bash
nano analysis/shard_imbalance.md
```

Include:
1. Total records loaded
2. Distribution across users (even or skewed?)
3. Any hot spots (users with excessive calls)?
4. Query performance observations
5. Any schema recommendations

---

## 📧 Step 8: Prepare Your Response

Create an email with:

**Subject:** CallDrop Assessment - Stage 3 Complete

**Body:**
```
Hi,

I've completed Stage 3 of the assessment with the provided dataset.

Dataset Size: [X records]
All 3 cluster nodes: UP and healthy
Data replication: Verified (all nodes identical)

Analytics Results:
- Total Calls: [number]
- Successful: [number] (X.XX%)
- Failed: [number] (X.XX%)

Shard Analysis:
[Summary from analysis/shard_imbalance.md]

Query Performance:
[Notes on how fast queries respond]

Attached: Complete analysis/ folder with detailed findings.

Best regards,
[Your name]
```

**Attach these files in a ZIP:**
- `analysis/shard_imbalance.md`
- `scripts/test_cluster_status.sh` (output)
- Any screenshots from nodetool status

---

## 🆘 If Something Goes Wrong

**"Data won't load":**
1. Check cluster is still healthy: `./scripts/test_cluster_status.sh`
2. Check disk space on nodes: `ssh ubuntu@16.147.230.26 'df -h'`
3. Check node logs: `ssh ubuntu@16.147.230.26 'tail -100 /var/log/scylla/scylla.log'`

**"Queries are very slow":**
- Normal - they test your awareness of performance
- Document the latency: "SELECT COUNT took X ms with Y records"

**"Replication lag detected":**
- Mention it in your analysis
- This is valuable feedback - shows you're monitoring

---

## ⏱️ Timeline

- **Expect to spend:** 1-2 hours total
- **Actual work:** ~30 minutes
- **Waiting for things:** ~1 hour

---

## 💡 Pro Tips

1. **Take screenshots** of key outputs (test results, counts, query times)
2. **Note the time** when you run queries - latency info is valuable
3. **Be honest** about bottlenecks - design is good, but scale insights matter more
4. **Don't over-engineer** your analysis - simple, factual observations impress more than speculation

---

Good luck! You've got this. 🚀
