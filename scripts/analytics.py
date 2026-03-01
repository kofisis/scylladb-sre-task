#!/usr/bin/env python3
"""
CallDrop Analytics Script
Queries ScyllaDB cluster to calculate call success rates
"""

import subprocess
import sys
import argparse
from datetime import datetime

# Node 1 (primary for queries)
CLUSTER_NODE = "16.147.230.26"
SSH_KEY = "~/.ssh/id_rsa_syclla"
SSH_USER = "ubuntu"


def timestamp_ms(date_str):
    """Convert date string (YYYY-MM-DD) to milliseconds since epoch"""
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    return int(dt.timestamp() * 1000)


def run_cql_query(query):
    """Execute CQL query on the cluster via SSH"""
    ssh_cmd = f"ssh -i {SSH_KEY} {SSH_USER}@{CLUSTER_NODE}"
    cqlsh_cmd = f"cqlsh localhost 9042 -e \"{query}\""
    full_cmd = f"{ssh_cmd} '{cqlsh_cmd}'"
    
    try:
        result = subprocess.run(full_cmd, shell=True, capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            print(f"Error: {result.stderr}")
            return None
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        print("Error: Query timed out")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def get_success_rate(start_date, end_date, phone=None):
    """Calculate call success rate for a date range, optionally filtered by phone"""
    
    start_ts = timestamp_ms(start_date)
    end_ts = timestamp_ms(end_date)
    
    # Build the WHERE clause
    if phone:
        where_clause = f"user_phone = '{phone}' AND call_ts >= {start_ts} AND call_ts < {end_ts}"
    else:
        # For queries without partition key, we need ALLOW FILTERING
        where_clause = f"call_ts >= {start_ts} AND call_ts < {end_ts} ALLOW FILTERING"
    
    # Get total call count
    total_query = f"SELECT COUNT(*) FROM calldrop.call_records WHERE {where_clause};"
    total_output = run_cql_query(total_query)
    
    if not total_output:
        print("Failed to get total call count")
        return
    
    # Parse the count from output (format: "count\n  value")
    lines = total_output.split('\n')
    total_count = int(lines[-1].strip()) if lines else 0
    
    if total_count == 0:
        print(f"No calls found for date range {start_date} to {end_date}")
        if phone:
            print(f"  (phone: {phone})")
        return
    
    # Get successful call count
    success_query = f"SELECT COUNT(*) FROM calldrop.call_records WHERE {where_clause} AND call_success = true;"
    success_output = run_cql_query(success_query)
    
    if not success_output:
        print("Failed to get success count")
        return
    
    lines = success_output.split('\n')
    success_count = int(lines[-1].strip()) if lines else 0
    
    # Calculate rate
    failed_count = total_count - success_count
    success_rate = (success_count / total_count * 100) if total_count > 0 else 0
    
    # Print results
    print(f"Total Calls:         {total_count}")
    print(f"Successful Calls:    {success_count}")
    print(f"Failed Calls:        {failed_count}")
    print(f"Success Rate:        {success_rate:.2f}%")


def main():
    parser = argparse.ArgumentParser(
        description="Calculate call success rates from CallDrop cluster",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Get success rate for all calls in February 2026
  python3 analytics.py --start "2026-02-01" --end "2026-03-01"
  
  # Get success rate for specific user
  python3 analytics.py --start "2026-02-01" --end "2026-03-01" --phone "+11000000000"
        """
    )
    
    parser.add_argument("--start", required=True, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end", required=True, help="End date (YYYY-MM-DD)")
    parser.add_argument("--phone", default=None, help="Filter by phone number (optional)")
    
    args = parser.parse_args()
    
    # Validate dates
    try:
        datetime.strptime(args.start, "%Y-%m-%d")
        datetime.strptime(args.end, "%Y-%m-%d")
    except ValueError:
        print("Error: Dates must be in YYYY-MM-DD format")
        sys.exit(1)
    
    get_success_rate(args.start, args.end, args.phone)


if __name__ == "__main__":
    main()
