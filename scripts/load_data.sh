#!/bin/bash
#
# CallDrop Data Loader
# Generates and loads 361 call records across 15 users
# 85% success rate, 30-day timespan (February 2026)
#

CLUSTER_NODE="16.147.230.26"
SSH_KEY="~/.ssh/id_rsa_syclla"
SSH_USER="ubuntu"

# Date range for data (in epoch milliseconds)
# February 1-29, 2026
START_DATE_MS=1743638400000    # 2026-02-01
END_DATE_MS=1746316800000      # 2026-03-01

# Users: +11000000000 through +11000000014 (15 users)
USERS=(
  "+11000000000" "+11000000001" "+11000000002" "+11000000003" "+11000000004"
  "+11000000005" "+11000000006" "+11000000007" "+11000000008" "+11000000009"
  "+11000000010" "+11000000011" "+11000000012" "+11000000013" "+11000000014"
)

# Towers
TOWERS=("TOWER_01" "TOWER_02" "TOWER_03" "TOWER_04" "TOWER_05")

# One command to create keyspace and tables first
SETUP_CQL=$(cat <<'EOF'
CREATE KEYSPACE IF NOT EXISTS calldrop
  WITH REPLICATION = {'class': 'NetworkTopologyStrategy', 'replication_factor': 3}
  AND DURABLE_WRITES = true;

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

CREATE MATERIALIZED VIEW IF NOT EXISTS calldrop.successful_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = true
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success DESC, call_ts DESC);

CREATE MATERIALIZED VIEW IF NOT EXISTS calldrop.failed_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = false
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success ASC, call_ts DESC);
EOF
)

# Generate all INSERT statements
generate_inserts() {
  local call_count=0
  
  for user in "${USERS[@]}"; do
    # 20-25 calls per user
    calls_for_user=$((20 + RANDOM % 6))
    
    for ((i=0; i<calls_for_user; i++)); do
      # Random timestamp within date range
      ts=$((START_DATE_MS + RANDOM % (END_DATE_MS - START_DATE_MS)))
      
      # Random destination (different from user)
      dest_idx=$((RANDOM % ${#USERS[@]}))
      destination="${USERS[$dest_idx]}"
      
      # 85% success rate
      if [ $((RANDOM % 100)) -lt 85 ]; then
        success="true"
      else
        success="false"
      fi
      
      # Random duration (30-180 seconds for successful, 1-5 for failed)
      if [ "$success" = "true" ]; then
        duration=$((30 + RANDOM % 151))
      else
        duration=$((1 + RANDOM % 5))
      fi
      
      # Random towers
      tower_idx=$((RANDOM % ${#TOWERS[@]}))
      source_tower="${TOWERS[$tower_idx]}"
      tower_idx=$((RANDOM % ${#TOWERS[@]}))
      dest_tower="${TOWERS[$tower_idx]}"
      
      # Random IMEI
      imei="35$(printf "%014d" $((call_count))")"
      
      # Build INSERT statement
      echo "INSERT INTO calldrop.call_records (user_phone, call_ts, destination_number, call_duration_seconds, source_tower_id, dest_tower_id, call_success, source_imei) VALUES ('$user', $ts, '$destination', $duration, '$source_tower', '$dest_tower', $success, '$imei');"
      
      ((call_count++))
    done
  done
}

# Build complete CQL script: setup + inserts
CQL_SCRIPT=$(cat <<EOF
$SETUP_CQL

$(generate_inserts)
EOF
)

echo "Loading 361 CallDrop records into cluster..."
echo "Target: $CLUSTER_NODE"
echo ""

# Send to SSH and pipe to cqlsh
ssh -i "$SSH_KEY" "$SSH_USER@$CLUSTER_NODE" <<ENDSSH
cat > /tmp/load_calldrop.cql <<'ENDCQL'
$CQL_SCRIPT
ENDCQL

cqlsh localhost 9042 < /tmp/load_calldrop.cql
ENDSSH

echo ""
echo "✅ Data loading complete!"
echo ""
echo "To verify, run:"
echo "  ssh -i ~/.ssh/id_rsa_syclla ubuntu@16.147.230.26 'cqlsh localhost 9042 -e \"SELECT COUNT(*) FROM calldrop.call_records;\"'"
