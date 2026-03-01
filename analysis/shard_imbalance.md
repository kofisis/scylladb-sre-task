# Shard Imbalance Analysis (Template)

This file is a placeholder for the Stage 3 analysis once the bulk data load script is provided.

After receiving and running the script, use Scylla Monitoring to inspect:
- Per-shard load (requests, data volume)
- Latency and throughput differences across shards and nodes

Then document:
- How the partition key (`user_phone`) and token distribution affect which shards receive traffic.
- Whether the data-load script uses a skewed set of keys (e.g., hot users / phone numbers) that concentrate activity on specific shards.
- Any observations about replication, compaction, or background tasks that might contribute to visible imbalance.

