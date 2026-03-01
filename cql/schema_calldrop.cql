-- CallDrop Schema for ScyllaDB
-- Keyspace: calldrop
-- Replication: NetworkTopologyStrategy, RF=3

CREATE KEYSPACE IF NOT EXISTS calldrop
  WITH REPLICATION = {'class': 'NetworkTopologyStrategy', 'replication_factor': 3}
  AND DURABLE_WRITES = true;

-- Main table: call_records
-- Partition key: user_phone (who made the call)
-- Clustering key: call_ts DESC (when), destination_number ASC (who they called)
-- This allows efficient queries: "Get all calls for user X, sorted by recency"

CREATE TABLE IF NOT EXISTS calldrop.call_records (
  user_phone TEXT,                      -- Phone number of the caller
  call_ts BIGINT,                       -- Timestamp (milliseconds since epoch)
  destination_number TEXT,              -- Phone number called
  call_duration_seconds INT,            -- How long the call lasted
  source_tower_id TEXT,                 -- Tower the caller was near
  dest_tower_id TEXT,                   -- Tower the destination was near
  call_success BOOLEAN,                 -- Did the call connect?
  source_imei TEXT,                     -- Phone IMEI
  PRIMARY KEY ((user_phone), call_ts, destination_number)
) WITH CLUSTERING ORDER BY (call_ts DESC, destination_number ASC)
  AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
  AND compaction = {'class': 'org.apache.cassandra.db.compaction.SizeTieredCompactionStrategy'};

-- Materialized View: successful_calls_by_user
-- For analyzing calls that succeeded
-- Query: "Show me all successful calls for user X"

CREATE MATERIALIZED VIEW IF NOT EXISTS calldrop.successful_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = true
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success DESC, call_ts DESC);

-- Materialized View: failed_calls_by_user
-- For analyzing calls that failed
-- Query: "Show me all failed calls for user X"

CREATE MATERIALIZED VIEW IF NOT EXISTS calldrop.failed_calls_by_user AS
  SELECT * FROM calldrop.call_records
  WHERE user_phone IS NOT NULL 
    AND call_ts IS NOT NULL 
    AND destination_number IS NOT NULL 
    AND call_success = false
  PRIMARY KEY ((user_phone), call_success, call_ts, destination_number)
  WITH CLUSTERING ORDER BY (call_success ASC, call_ts DESC);
