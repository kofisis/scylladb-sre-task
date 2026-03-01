# Technical Reference - CallDrop ScyllaDB Assessment

**For:** Detailed schema, network architecture, and advanced operations  
**See:** README.md for quick testing procedures

---

## 📋 Database Schema

### Keyspace: calldrop
```cql
CREATE KEYSPACE calldrop
  WITH REPLICATION = {'class': 'NetworkTopologyStrategy', 'replication_factor': 3}
  AND DURABLE_WRITES = true;
```

**Properties:**
- Replication Factor: 3 (data on all 3 nodes)
- Strategy: NetworkTopologyStrategy (scales to multiple regions)
- Durable writes: Enabled (data not lost on crash)

### Table: call_records

```cql
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
  AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
  AND compaction = {'class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'};
```

**Key Design:**
- **Partition Key:** `user_phone` (all calls for a user stored together)
- **Clustering Keys:** `call_ts DESC (newest first), destination_number ASC`
- **Why this design:** Queries like "get calls for user +11000000000" are fast

**Columns:**
| Column | Type | Purpose |
|--------|------|---------|
| user_phone | TEXT | Which user made the call |
| call_ts | BIGINT | When call happened (milliseconds since epoch) |
| destination_number | TEXT | Who they called |
| call_duration_seconds | INT | How long call lasted |
| source_tower_id | TEXT | Which tower user was on |
| dest_tower_id | TEXT | Which tower recipient was on |
| call_success | BOOLEAN | true=connected, false=dropped |
| source_imei | TEXT | Phone's unique identifier |

**Storage:**
- Compression: LZ4 (smaller disk usage)
- Compaction: SizeTieredCompactionStrategy (good for time-series data)

### Materialized View 1: successful_calls_by_user

```cql
CREATE MATERIALIZED VIEW calldrop.successful_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL AND call_success = true
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success DESC, call_ts DESC);
```

**Purpose:** Query only successful calls for a user (auto-maintained by ScyllaDB)

### Materialized View 2: failed_calls_by_user

```cql
CREATE MATERIALIZED VIEW calldrop.failed_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL AND call_success = false
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success ASC, call_ts DESC);
```

**Purpose:** Query only failed calls for a user (auto-maintained by ScyllaDB)

---

## 🌐 Network Architecture

### Cluster Nodes

| # | Public IP | Internal IP | Region | Port 9042 |
|---|-----------|-------------|--------|-----------|
| 1 | 16.147.230.26 | 172.31.31.46 | us-west-2a | ✅ |
| 2 | 16.147.222.180 | 172.31.27.44 | us-west-2b | ✅ |
| 3 | 18.236.162.135 | 172.31.27.60 | us-west-2c | ✅ |

### Configuration

**Seed Nodes (for cluster formation):**
```
172.31.31.46, 172.31.27.44, 172.31.27.60
```
(Internal IPs only - prevents cross-region issues)

**Listen Addresses:**
```
Each node listens on its internal IP (172.31.x.x)
```
(Gossip and client connections on internal network)

**Broadcast Addresses:**
```
Each node broadcasts its internal IP to other nodes
```
(Ensures traffic stays within VPC)

**ScyllaDB Configuration:**
```
disable_raft: true        (for stable single-region cluster)
rpc_address: 172.31.x.x   (listen on internal IP)
listen_address: 172.31.x.x (gossip on internal IP)
```

### Communication Protocols

| Protocol | Port | Purpose |
|----------|------|---------|
| Gossip | UDP:7000 | Nodes talk to each other (cluster membership) |
| Native Protocol | TCP:9042 | Client connections (CQL queries) |
| SSH | TCP:22 | Management access (from your machine) |

### Network Flow

```
Your Computer
    ↓ (SSH via public IP)
Node 1, Node 2, or Node 3 (EC2 instances)
    ↓ (SSH opens terminal on node)
ScyllaDB (listening on localhost:9042 = internal IP)
    ↓↑ (CQL queries)
Database responds
```

---

## 📊 Data Details

### Sample Dataset
- **Records Loaded:** 361
- **Users:** 15 unique phone numbers (+11000000000 to +11000000014)
- **Calls per User:** 20-25 calls
- **Date Range:** February 2026 (30 days)
- **Success Rate:** ~85% (262 successful, 99 failed)

### Data Generation

Each call record has:
- **Call duration:** Random selection from [30s, 45s, 60s, 90s, 120s, 180s, 300s]
- **Tower IDs:** Random from [tower-1a, tower-1b, tower-2a, tower-2b, tower-3a, tower-3b]
- **IMEI:** Device identifier format (IMEI-XXX-YY)
- **Timestamps:** Distributed across 30 days, millisecond precision
- **Success rate:** 85% (randomly selected for each call)

### Verification

All 3 nodes verified to have identical data:
```
SELECT COUNT(*) FROM calldrop.call_records;
Node 1: 361 ✓
Node 2: 361 ✓
Node 3: 361 ✓
```

---

## 🔧 Advanced Operations

### Manual Data Query

SSH to any node:
```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26
```

Then use cqlsh:
```bash
cqlsh localhost 9042

# In cqlsh prompt:
USE calldrop;
SELECT COUNT(*) FROM call_records;
SELECT * FROM call_records WHERE user_phone = '+11000000000' LIMIT 5;
SELECT * FROM successful_calls_by_user WHERE user_phone = '+11000000000';
EXIT;
```

### Check Replication Status

SSH to any node:
```bash
nodetool status -u cassandra -pw cassandra
```

Look for:
- All nodes showing `UN` (Up Normal)
- Balanced load across nodes
- 256 tokens for each node

### Reload Data if Needed

```bash
cd /Users/nana/Documents/Personal/scylladb_int
./load_data.sh
```

This will:
1. Connect to Node 1 via SSH
2. Execute CQL INSERT statements for all 361 records
3. Verify counts on all 3 nodes

### Restart a Node if Needed

```bash
ssh -i ~/.ssh/id_rsa_syclla ubuntu@NODE_IP \
  'sudo systemctl restart scylla-server'
```

The cluster will automatically rebalance data to/from the node.

---

## 📈 Analytics Script Details

### Script: analytics.py

**Command:** `python3 analytics.py --start DATE --end DATE [--phone NUMBER]`

**Parameters:**
- `--start`: Start date (YYYY-MM-DD format)
- `--end`: End date (YYYY-MM-DD format)  
- `--phone`: (Optional) Filter by specific user phone number

**How it works:**
1. Parses command-line arguments
2. Converts dates to milliseconds (epoch time)
3. Builds CQL query with WHERE clauses for time range + optional phone filter
4. Executes via SSH to Node 1
5. Counts total, successful, and failed calls
6. Calculates success rate percentage (successful ÷ total)
7. Formats output with interpretation

**Query Logic:**

```
Total Calls:
  SELECT COUNT(*) FROM calldrop.call_records
  WHERE call_ts >= START_MS AND call_ts <= END_MS
         AND (optional) user_phone = '+11000000000'

Successful Calls:
  SELECT COUNT(*) FROM calldrop.call_records
  WHERE call_ts >= START_MS AND call_ts <= END_MS
         AND call_success = true
         AND (optional) user_phone = '+11000000000'
  ALLOW FILTERING

Failed Calls:
  SELECT COUNT(*) FROM calldrop.call_records
  WHERE call_ts >= START_MS AND call_ts <= END_MS
         AND call_success = false
         AND (optional) user_phone = '+11000000000'
  ALLOW FILTERING

Success Rate = (Successful ÷ Total) × 100%
```

**Why ALLOW FILTERING:**
- call_success is not part of the partition key
- ScyllaDB requires explicit permission to filter on non-key columns
- This is optional for small datasets, required for large ones

### Example Usage

**Get network success rate for a month:**
```bash
python3 analytics.py --start "2026-02-01" --end "2026-03-01"
```

**Get one user's success rate:**
```bash
python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"
```

**Get success rate for a week:**
```bash
python3 analytics.py --start "2026-02-08" --end "2026-02-15"
```

**Get success rate for one day:**
```bash
python3 analytics.py --start "2026-02-15" --end "2026-02-16"
```

---

## 🐛 Troubleshooting

### Query Timeout (>30 seconds)

**Symptom:** Command hangs or times out

**Cause:** Network issue or node memory overload

**Fix:**
```bash
# Check if nodes are responding
./test_cluster_status.sh

# If a node shows as DOWN, restart it
ssh -i ~/.ssh/id_rsa_syclla ubuntu@NODE_IP \
  'sudo systemctl restart scylla-server'
```

### Wrong Data Counts

**Symptom:** Some nodes show different record counts

**Cause:** Replication lag or data corruption

**Fix:**
```bash
# Reload all data
./load_data.sh

# Wait 30 seconds
sleep 30

# Verify counts match
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135 \
  'cqlsh localhost 9042 -e "SELECT COUNT(*) FROM calldrop.call_records;"'
```

### Analytics Script Errors

**Symptom:** "Query error: unexpected EOF"

**Cause:** Special characters in phone number not escaped properly

**Fix:**
```bash
# Try without phone filter first
python3 analytics.py --start "2026-02-01" --end "2026-03-01"

# If that works, try with phone filter
python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"
```

### SSH Connection Refused

**Symptom:** "Connection refused" or timeout on SSH

**Cause:** Wrong IP or security group blocking

**Fix:**
```bash
# Use public IPs for SSH
ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26  # Not internal IP

# Verify key permissions
ls -la ~/.ssh/id_rsa_syclla  # Should be 400 or 600
```

---

## 📚 What Each File Does

| File | Purpose | When to Use |
|------|---------|-------------|
| `README.md` | Quick start and testing | First time, quick reference |
| `TECHNICAL_REFERENCE.md` | This file - schema details | Understanding design, troubleshooting |
| `analytics.py` | Analytics script | Querying success rates |
| `load_data.sh` | Data loader | Repopulating if data lost |
| `test_cluster_status.sh` | Cluster health check | Verifying nodes are UP |
| `verify_cluster.py` | Connection tester | Debugging connectivity |

---

## 🎯 Task Requirements Met

✅ **Requirement 1:** Deploy 3-node ScyllaDB cluster
- Nodes: 3
- Status: UP/Normal
- Replication: RF=3 (NetworkTopologyStrategy)

✅ **Requirement 2:** Create schema with call_records table
- Partition Key: user_phone ✓
- Clustering Keys: call_ts, destination_number ✓
- Columns: All required ✓
- Materialized Views: 2 created ✓

✅ **Requirement 3:** Load sample data
- Records: 361 ✓
- Users: 15 ✓
- Calls per user: 20-25 ✓
- Replicated: All 3 nodes ✓

✅ **Requirement 4:** Create analytics script
- Time filtering: ✓
- Phone filtering: ✓
- Success rate calculation: ✓
- Output formatting: ✓

⏳ **Requirement 5:** Stage 3 (Large dataset)
- Ready to proceed once dataset provided

---

## 📞 Support

**Node IP Reference:**
```
Node 1: ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26
Node 2: ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.222.180
Node 3: ssh -i ~/.ssh/id_rsa_syclla ubuntu@18.236.162.135
```

**Database Credentials:**
```
CQL User: cassandra
CQL Password: cassandra
CQL Port: 9042
```

**Key Files:**
```
SSH Key: ~/.ssh/id_rsa_syclla
Working Directory: ~/Documents/Personal/scylladb_int/
```

**Last Updated:** March 1, 2026  
**Version:** 1.0 (Stage 1 & 2 Complete)
