#!/bin/bash
#
# CallDrop Cluster Status Tester - Verifies the health and functionality of the CallDrop ScyllaDB cluster
# Tests:
#   1. SSH connectivity to all nodes
#   2. Port 9042 (CQL) is listening
#   3. Data is replicated and accessible
#   4. Analytics queries work
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

# TEST 1: SSH Connectivity
echo "[TEST 1] SSH Connectivity..."

SSH_OK=0
for node in "${NODES[@]}"; do
  if ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$SSH_USER@$node" 'echo OK' &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $node: SSH OK"
    ((SSH_OK++))
  else
    echo -e "  ${RED}✗${NC} $node: SSH FAILED"
  fi
done

echo ""

if [ "$SSH_OK" -ne 3 ]; then
  echo -e "${RED}✗ FAIL${NC}: Only $SSH_OK/3 nodes are reachable via SSH"
  exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: All 3 nodes are reachable via SSH"
echo ""

# TEST 2: Port 9042 (CQL) Listening
echo "[TEST 2] Port 9042 (CQL) Listening..."

PORT_OK=0
for node in "${NODES[@]}"; do
  if ssh -i "$SSH_KEY" "$SSH_USER@$node" \
    "ss -tlnp 2>/dev/null | grep -q 9042 || netstat -tlnp 2>/dev/null | grep -q 9042"; then
    echo -e "  ${GREEN}✓${NC} $node:9042 listening"
    ((PORT_OK++))
  else
    echo -e "  ${RED}✗${NC} $node:9042 NOT listening"
  fi
done

echo ""

if [ "$PORT_OK" -ne 3 ]; then
  echo -e "${RED}✗ FAIL${NC}: Only $PORT_OK/3 nodes have port 9042 listening"
  exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: All 3 nodes have port 9042 (CQL) listening"
echo ""

# TEST 3: Data Replication
echo "[TEST 3] Data Replication..."

DATA_OK=0
for i in "${!NODES[@]}"; do
  node="${NODES[$i]}"
  # Get count by finding the line with just whitespace and numbers
  count=$(ssh -i "$SSH_KEY" "$SSH_USER@$node" \
    "cqlsh localhost 9042 -e 'SELECT COUNT(*) FROM calldrop.call_records;' 2>&1" \
    | awk '/^[[:space:]]+[0-9]+[[:space:]]*$/ {gsub(/[^0-9]/, ""); print; exit}')
  
  if [ "$count" = "361" ]; then
    echo -e "  ${GREEN}✓${NC} Node $node: 361 records"
    ((DATA_OK++))
  else
    echo -e "  ${RED}✗${NC} Node $node: $count records (expected 361)"
  fi
done

echo ""

if [ "$DATA_OK" -ne 3 ]; then
  echo -e "${RED}✗ FAIL${NC}: Only $DATA_OK/3 nodes have correct data"
  exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: All 3 nodes have 361 replicated records"
echo ""

# TEST 4: Analytics Query
echo "[TEST 4] Analytics Query..."

analytics_output=$(ssh -i "$SSH_KEY" "$SSH_USER@${NODES[0]}" \
  "cqlsh localhost 9042 -e 'SELECT COUNT(*) FROM calldrop.call_records WHERE call_ts >= 1769900400000 AND call_ts < 1772319600000 ALLOW FILTERING;' 2>&1")

if echo "$analytics_output" | grep -qE '^[[:space:]]+[0-9]+'; then
  echo -e "  ${GREEN}✓${NC} Analytics query works"
  TOTAL=$(echo "$analytics_output" | awk '/^[[:space:]]+[0-9]+[[:space:]]*$/ {gsub(/[^0-9]/, ""); print; exit}')
  echo "     Total calls in Feb 2026: $TOTAL"
else
  echo -e "  ${RED}✗${NC} Analytics query failed"
  exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
echo "======================================"
echo ""
echo "Cluster Status:"
echo "  - 3 nodes: ONLINE"
echo "  - Port 9042: LISTENING"
echo "  - Data replicated: 361 records on each node"
echo "  - Analytics: WORKING"
echo ""
