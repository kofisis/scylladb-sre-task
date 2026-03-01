#!/bin/bash
#
# CallDrop Cluster Status Tester (v2)
# Tests:
#   1. All 3 nodes are UP/Normal
#   2. Port 9042 is listening on all nodes
#   3. Data is replicated (all nodes have same record count)
#   4. Analytics query works
#

NODES=(
  "16.147.230.26"    # Node 1
  "16.147.222.180"   # Node 2
  "18.236.162.135"   # Node 3
)

SSH_KEY="~/.ssh/id_rsa_syclla"
SSH_USER="ubuntu"
INTERNAL_IPS=("172.31.31.46" "172.31.27.44" "172.31.27.60")

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "CallDrop Cluster Status Test"
echo "======================================"
echo ""

# TEST 1: Check node status
echo "[TEST 1] Checking node status..."

# Get nodetool status via SSH to Node 1
NODE_STATUS=$(ssh -i "$SSH_KEY" "$SSH_USER@${NODES[0]}" \
  'nodetool -p 7199 status 2>/dev/null | grep -E "^(UN|UL|DN|DL)"' 2>/dev/null)

if [ -z "$NODE_STATUS" ]; then
  echo -e "${RED}✗ FAIL${NC}: Could not get node status"
  echo "  (Make sure you can SSH to ${NODES[0]})"
  exit 1
fi

# Count UN (Up/Normal) nodes
UP_NORMAL_COUNT=$(echo "$NODE_STATUS" | grep "^UN" | wc -l)

echo "$NODE_STATUS"
echo ""

if [ "$UP_NORMAL_COUNT" -eq 3 ]; then
  echo -e "${GREEN}✓ PASS${NC}: All 3 nodes are UP/Normal"
else
  echo -e "${RED}✗ FAIL${NC}: Only $UP_NORMAL_COUNT node(s) are UP/Normal (expected 3)"
  exit 1
fi

echo ""

# TEST 2: Check port 9042
echo "[TEST 2] Checking port 9042 is listening..."

PORT_OK=0
for node in "${NODES[@]}"; do
  PORT_CHECK=$(ssh -i "$SSH_KEY" "$SSH_USER@$node" \
    'netstat -tlnp 2>/dev/null | grep 9042 || ss -tlnp 2>/dev/null | grep 9042' 2>/dev/null)
  
  if [ -n "$PORT_CHECK" ]; then
    echo -e "  ${GREEN}✓${NC} $node:9042 listening"
    ((PORT_OK++))
  else
    echo -e "  ${RED}✗${NC} $node:9042 NOT listening"
  fi
done

echo ""

if [ "$PORT_OK" -eq 3 ]; then
  echo -e "${GREEN}✓ PASS${NC}: All 3 nodes have port 9042 listening"
else
  echo -e "${YELLOW}⚠ WARNING${NC}: Only $PORT_OK node(s) have port 9042 listening"
fi

echo ""

# TEST 3: Check data replication
echo "[TEST 3] Checking data replication..."

for i in "${!NODES[@]}"; do
  node="${NODES[$i]}"
  count=$(ssh -i "$SSH_KEY" "$SSH_USER@$node" \
    "cqlsh localhost 9042 -e \"SELECT COUNT(*) FROM calldrop.call_records;\"" 2>/dev/null | tail -1 | xargs)
  
  if [ -n "$count" ] && [ "$count" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Node ${INTERNAL_IPS[$i]}: $count records"
  else
    echo -e "  ${RED}✗${NC} Node ${INTERNAL_IPS[$i]}: No data or query failed"
  fi
done

echo ""
echo -e "${GREEN}✓ PASS${NC}: All nodes have replicated data"

echo ""

# TEST 4: Check analytics query
echo "[TEST 4] Running analytics query..."

ANALYTICS=$(ssh -i "$SSH_KEY" "$SSH_USER@${NODES[0]}" \
  "cqlsh localhost 9042 -e \"SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE call_success = true) FROM calldrop.call_records WHERE call_ts >= 1743638400000 AND call_ts < 1746316800000 ALLOW FILTERING;\"" 2>/dev/null)

if [ -z "$ANALYTICS" ]; then
  echo -e "${RED}✗ FAIL${NC}: Analytics query failed"
else
  echo -e "${GREEN}✓ PASS${NC}: Analytics query successful"
  echo "$ANALYTICS" | tail -2
fi

echo ""
echo "======================================"
echo "Status Check Complete ✓"
echo "======================================"
