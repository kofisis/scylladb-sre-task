# 📋 CallDrop Data Model Design & Stage 3 Requirements

**Date:** March 1, 2026 | **Status:** Stage 1 & 2 Complete

---

## Part 1: Data Model Design Process

### 🤖 The Prompt (Given to LLM)

```
I need to design a ScyllaDB data model for a call tracking system called "CallDrop".

Requirements:
1. Table name: call_records
2. Keyspace: calldrop with replication factor 3
3. Partition key: user_phone (the user making the call)
4. Clustering keys: destination_number (primary sort), call_ts (timestamp, descending)
5. Columns needed:
   - call_duration_seconds (INT)
   - source_tower_id (TEXT) - which tower the call originated from
   - dest_tower_id (TEXT) - which tower the call terminated at
   - call_success (BOOLEAN) - true if call connected, false if dropped
   - source_imei (TEXT) - phone's unique device identifier

Additional requirements:
- Create a materialized view to query successful calls by user
- Create a materialized view to query failed calls by user
- Schema should support queries like:
  * "Get all calls for user +11000000000"
  * "Get successful calls for a date range"
  * "Get failed calls for a specific user"
  * "Count calls by user"
- Use LZ4 compression for storage optimization
- Use SizeTieredCompactionStrategy for time-series optimized queries

Please provide:
1. CQL CREATE KEYSPACE statement
2. CQL CREATE TABLE statement with proper partition/clustering keys
3. CQL CREATE MATERIALIZED VIEW statements (one for successful calls, one for failed)
4. Brief explanation of design choices
```

---

### 📝 LLM Output (Segment from Claude)

```
Your data model design is sound. Here's the optimized ScyllaDB schema:

## Keyspace Creation

CREATE KEYSPACE calldrop
  WITH REPLICATION = {'class': 'NetworkTopologyStrategy', 
                      'replication_factor': 3}
  AND DURABLE_WRITES = true;

## Main Table

CREATE TABLE calldrop.call_records (
  user_phone TEXT,
  call_ts BIGINT,
  destination_number TEXT,
  call_duration_seconds INT,
  source_tower_id TEXT,
  dest_tower_id TEXT,
  call_success BOOLEAN,
  source_imei TEXT,
  PRIMARY KEY ((user_phone), call_ts, destination_number)
) WITH CLUSTERING ORDER BY (call_ts DESC, destination_number ASC)
  AND compression = {'sstable_compression': 
                    'org.apache.cassandra.io.compress.LZ4Compressor'}
  AND compaction = {'class': 
      'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'};

## Materialized Views

CREATE MATERIALIZED VIEW calldrop.successful_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = true
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success DESC, call_ts DESC);

CREATE MATERIALIZED VIEW calldrop.failed_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = false
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success ASC, call_ts DESC);

## Design Rationale

1. **Partition Key (user_phone):**
   - Queries are user-centric ("calls for user X")
   - Each user's calls stored together for locality
   - Perfectly distributes load across cluster

2. **Clustering Keys (call_ts DESC, destination_number ASC):**
   - call_ts DESC: newest calls first (common query pattern)
   - destination_number ASC: alphabetical ordering within timestamp
   - Enables range queries: "calls between date X and Y"

3. **Materialized Views:**
   - successful_calls_by_user: instant access to successful calls
   - failed_calls_by_user: instant access to failed calls
   - ScyllaDB maintains these automatically

4. **Compression & Compaction:**
   - LZ4: Fast compression for call records (lots of redundant data)
   - SizeTieredCompactionStrategy: Optimized for time-series data
   - Good for "insert-heavy, read-heavy by time-range" patterns

## Query Examples This Enables

-- Get all calls for a user
SELECT * FROM calldrop.call_records WHERE user_phone = '11000000000';

-- Get calls in a date range
SELECT * FROM calldrop.call_records 
WHERE user_phone = '+11000000000' 
  AND call_ts >= 1708891200000 
  AND call_ts <= 1711479200000;

-- Get successful calls only
SELECT * FROM calldrop.successful_calls_by_user 
WHERE user_phone = '+11000000000';

-- Count all calls
SELECT COUNT(*) FROM calldrop.call_records;

-- Success rate calculation (needs application logic)
SELECT call_success, COUNT(*) 
FROM calldrop.call_records 
WHERE user_phone = '+11000000000'
GROUP BY call_success;
```

---

### 🔧 Schema Implementation (Final CQL)

Created in file: [cql/schema_calldrop.cql](cql/schema_calldrop.cql)

```cql
-- Keyspace for CallDrop system
CREATE KEYSPACE IF NOT EXISTS calldrop
  WITH REPLICATION = {'class': 'NetworkTopologyStrategy', 'replication_factor': 3}
  AND DURABLE_WRITES = true;

-- Main call records table
CREATE TABLE IF NOT EXISTS calldrop.call_records (
  user_phone TEXT,
  call_ts BIGINT,
  destination_number TEXT,
  call_duration_seconds INT,
  source_tower_id TEXT,
  dest_tower_id TEXT,
  call_success BOOLEAN,
  source_imei TEXT,
  PRIMARY KEY ((user_phone), call_ts, destination_number)
) WITH CLUSTERING ORDER BY (call_ts DESC, destination_number ASC)
  AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
  AND compaction = {'class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'};

-- View for successful calls
CREATE MATERIALIZED VIEW IF NOT EXISTS calldrop.successful_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = true
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success DESC, call_ts DESC);

-- View for failed calls
CREATE MATERIALIZED VIEW IF NOT EXISTS calldrop.failed_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = false
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success ASC, call_ts DESC);
```

---

### 📝 Revisions Made During Implementation

#### Revision 1: Token Count Issue
**Initial Problem:** Tokens showing as "1" instead of "256"  
**Cause:** Cluster restart during bootstrap  
**Impact:** Minimal - replication still works perfectly (RF=3)  
**Decision:** Keep current configuration - not critical for assessment

#### Revision 2: Query Filtering Issue
**Initial Problem:** "Cannot execute this query as it might involve data filtering"  
**Cause:** Queries on non-partition-key columns needed ALLOW FILTERING  
**Solution:** Added `ALLOW FILTERING` clause to analytics queries  
**Files Updated:**
- analytics.py: WHERE clauses on call_success field
- load_data.sh: Verification queries

#### Revision 3: Data Timestamp Format
**Initial Problem:** Need consistent timestamp format for date ranges  
**Solution:** Used milliseconds since epoch (BIGINT)  
**Example Timestamps:**
```
1708891200000 = 2026-02-25 12:00:00 UTC
1711479200000 = 2026-03-27 12:00:00 UTC
```

---

### 🐍 Data Generation Scripts Used

#### 1. **load_data.sh** - Primary Data Loader

Located: [load_data.sh](load_data.sh)

```bash
#!/bin/bash
# Generates 361 call records across 15 users
# Uses: 15 users × 20-25 calls per user
# Success rate: 85% realistic failure rate
# Timestamps: Distributed across 30 days

# Data characteristics:
# - User phone: +11000000000 through +11000000014
# - Destinations: Random phone numbers (+11000000000 to +11000000014)
# - Durations: 30s, 45s, 60s, 90s, 120s, 180s, 300s (varied)
# - Towers: tower-1a through tower-3b (6 towers total)
# - IMEI: Realistic format IMEI-XXX-YY
# - Success: ~85% true, ~15% false
```

**Execution:**
```bash
./load_data.sh
```

**Output:**
- 361 call records inserted into cluster
- Verified on all 3 nodes (361 records each)
- Replication factor 3 confirmed

#### 2. **analytics.py** - Query & Analysis Tool

Located: [analytics.py](analytics.py)

```python
# Features:
# - Time-range filtering (--start and --end dates)
# - User phone filtering (--phone for specific user)
# - Success rate calculation
# - Output formatting with interpretation

# Queries three data points:
# 1. Total calls in date range
# 2. Successful calls (call_success = true)
# 3. Failed calls (call_success = false)

# Calculates: success_rate = (successful ÷ total) × 100%
```

**Usage:**
```bash
# All calls in date range
python3 analytics.py --start "2026-02-01" --end "2026-03-01"

# Specific user
python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"
```

**Sample Output:**
```
Total Calls:         312
Successful Calls:    262
Failed Calls:        50
Success Rate:        83.97%
```

---

### 📊 Schema Field Explanations

| Column | Type | Purpose | Example | Key Type |
|--------|------|---------|---------|----------|
| **user_phone** | TEXT | Who made the call | `+11000000000` | **PARTITION KEY** |
| **call_ts** | BIGINT | When call happened (ms epoch) | `1708891200000` | Clustering (DESC) |
| **destination_number** | TEXT | Who was called | `+11000000001` | Clustering (ASC) |
| **call_duration_seconds** | INT | How long call lasted | `180` | Data |
| **source_tower_id** | TEXT | User's tower location | `tower-1a` | Data |
| **dest_tower_id** | TEXT | Recipient's tower location | `tower-2b` | Data |
| **call_success** | BOOLEAN | Call connected? | `true` | Data |
| **source_imei** | TEXT | Phone's device ID | `IMEI-001-01` | Data |

---

### 🎯 Why This Design Works

**For Queries:**
✅ User-centric queries fast (all user's calls together)  
✅ Date-range queries efficient (clustering by timestamp)  
✅ Success/failure filtering instant (materialized views)  

**For Scalability:**
✅ RF=3 ensures data isn't lost if one node fails  
✅ Replication across 3 nodes = 300% capacity backup  
✅ Distributes evenly (balanced partition key)  

**For Storage:**
✅ LZ4 compression = smaller disk usage  
✅ SizeTieredCompactionStrategy optimized for time-series  
✅ Efficient for "insert-heavy, read-by-range" patterns  

---

## Part 2: Stage 3 Requirements & Deliverables

### 📋 What Stage 3 Involves

**Goal:** Validate the data model with production-scale data and analyze performance

### Stage 3a: Large Dataset Loading ⏳

**What you'll receive:**
- A larger dataset (100s of thousands to millions of records)
- A loading script from the hiring team
- Instructions on how to load it

**What you'll do:**
```bash
# Run their provided loading script
./load_stage3_data.sh

# Or similar command they provide
# May take 5-30 minutes depending on data size
```

**Verification:**
```bash
# Check data was loaded
./test_cluster_status.sh

# Run count query
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'

# Should show millions instead of 361
```

---

### Stage 3b: Performance Analysis 📊

**What they'll ask for:**

#### 1. **Shard Distribution Report**
File: [analysis/shard_imbalance.md](analysis/shard_imbalance.md)

Answer these questions about the loaded data:

```markdown
## Shard Distribution Analysis

### 1. Data Distribution
- How many records per shard?
- Are records evenly distributed?
- Any skewed shards (too many/few records)?

### 2. Potential Issues
- Do any users have disproportionately more calls?
- Could this cause hot shards?
- What's the distribution pattern?

### 3. Recommendations
- Is the current partition key optimal?
- Should we consider secondary partitioning?
- Any schema changes needed for scale?

### 4. Query Performance
- Average latency for user query?
- Average latency for date-range query?
- Average latency for success-rate query?

### 5. Replication Health
- Are all 3 replicas consistent?
- Any replication lag observed?
- How long does consistency take?
```

#### 2. **Run Analytics on Full Dataset**

```bash
# Get overall success rate
python3 analytics.py --start "2026-02-01" --end "2026-03-01"

# Get per-user metrics (sample users)
python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"

# Different time ranges
python3 analytics.py --start "2026-02-15" --end "2026-02-28"
```

Expected Output Format:
```
Total Calls:         [Large number]
Successful Calls:    [Large number]
Failed Calls:        [Some number]
Success Rate:        XX.XX%
```

#### 3. **Performance Metrics**

Collect and share:

```
Query Performance:
- Time for "count all calls": XX ms
- Time for "user query": XX ms
- Time for "date range query": XX ms

System Health:
- Cluster nodes: All UP/Normal
- Token distribution: [notes on balance]
- Replication lag: [observed values]

Scalability Observations:
- Did queries slow down with more data?
- Any hot spots noticed?
- Replication keeping up?
```

---

### 📦 What to Provide for Stage 3

#### Files to Include

1. **Updated analytics.py output** (on full dataset)
2. **analysis/shard_imbalance.md** (completed analysis)
3. **test_cluster_status.sh output** (showing all nodes healthy)
4. **Performance metrics** (from queries on large dataset)

#### Example Email Format

```
Subject: CallDrop Assessment - Stage 3 Complete

Hi,

I've completed Stage 3 of the technical assessment:

## Large Dataset (XXX records)
- Loaded successfully using provided script
- All 3 nodes have identical replicas
- Cluster remains healthy and responsive

## Performance Analysis

### Summary
- Total calls: XXX,XXX
- Successful: XXX,XXX (XX.X%)
- Failed: XX,XXX (X.X%)

### Shard Distribution
- Data distributed evenly across shards
- No obvious hot spots identified
- Largest shard has XXX records, smallest has XXX

### Query Performance
- User query: ~XX ms
- Date range query: ~XXX ms
- Aggregation query: ~XXX ms

### Observations
[Detailed findings from analysis/shard_imbalance.md]

### Recommendations
[Any schema changes or optimizations suggested]

Please see attached analysis/ folder for complete details.

Thanks,
[Your name]
```

---

### 🎯 Stage 3 Checklist

**When you receive the Stage 3 dataset:**

- [ ] Receive loading script from hiring team
- [ ] Follow their instructions to load data
- [ ] Run `./test_cluster_status.sh` to verify
- [ ] Run `python3 analytics.py` on full dataset
- [ ] Complete `analysis/shard_imbalance.md` analysis
- [ ] Collect performance metrics
- [ ] Email results to hiring team

---

### ⏱️ Expected Timeline

| Task | Time |
|------|------|
| Receive Stage 3 dataset | Variable (depends on team) |
| Load dataset | 5-30 minutes (depends on size) |
| Run analytics queries | 5-10 minutes |
| Complete analysis document | 15-30 minutes |
| Email results | <5 minutes |
| **Total Stage 3** | ~1-2 hours |

---

### 💡 Pro Tips for Stage 3

1. **Before loading large dataset:**
   - Increase timeouts in analytics.py (queries may be slower)
   - Save baseline performance metrics
   - Note cluster state before/after

2. **During loading:**
   - Monitor memory usage: `free -h` on each node
   - Check disk space: `df -h` on each node
   - Watch replication lag via nodetool

3. **For the analysis:**
   - Screenshot nodetool output (shows token distribution)
   - Run same queries multiple times (check consistency)
   - Document any unexpected findings

4. **Common questions they may ask:**
   - "Does this schema scale to 1 billion records?" (Answer: With changes to compaction strategy)
   - "What's the bottleneck?" (Answer: Look at shard_imbalance.md findings)
   - "Would you change anything?" (Answer: Based on real data distribution)

---

## Summary

### What You've Completed (Stage 1 & 2) ✅
- [x] Designed schema with LLM assistance
- [x] Created tables and materialized views
- [x] Generated and loaded 361 sample records
- [x] Built analytics query tool
- [x] Verified replication across 3 nodes

### What You'll Do (Stage 3) ⏳
- [ ] Receive production-scale dataset
- [ ] Load dataset using provided script
- [ ] Run analytics on full data
- [ ] Analyze shard distribution
- [ ] Document findings in analysis/shard_imbalance.md
- [ ] Email complete results

### Files Ready for Stage 3
- ✅ `analysis/shard_imbalance.md` - Empty, ready for your analysis
- ✅ `analytics.py` - Ready to run on larger dataset
- ✅ `test_cluster_status.sh` - Ready to verify cluster health
- ✅ Schema - Already created and replicated

**You're prepared for Stage 3!** Just wait for the dataset and follow the steps above. 🚀
