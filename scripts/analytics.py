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
    try:
        # Build the cqlsh command to run remotely
        remote_cmd = f"cqlsh localhost 9042 -e {repr(query)}"
        
        # SSH to the node and execute cqlsh
        cmd = [
            "ssh",
            "-i", SSH_KEY,
            f"{SSH_USER}@{CLUSTER_NODE}",
            remote_cmd
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
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


def parse_cqlsh_count(output):
    """Parse COUNT result from cqlsh output"""
    if not output:
        return 0
    lines = [line.strip() for line in output.split('\n')]
    # Find the line that is just a number (not header, not row count)
    for line in lines:
        if line.isdigit():
            return int(line)
    return 0


def get_success_rate(start_date, end_date, phone=None):
    """Calculate call success rate for a date range, optionally filtered by phone"""
    
    start_ts = timestamp_ms(start_date)
    end_ts = timestamp_ms(end_date)
    
    # Build the base WHERE clause
    if phone:
        # Escape single quotes in phone number for CQL
        phone_escaped = phone.replace("'", "''")
        base_where = f"user_phone = '{phone_escaped}' AND call_ts >= {start_ts} AND call_ts < {end_ts}"
        need_filtering = False
    else:
        # For queries without partition key, we need ALLOW FILTERING
        base_where = f"call_ts >= {start_ts} AND call_ts < {end_ts}"
        need_filtering = True
    
    # Build ALLOW FILTERING suffix
    allow_filtering = " ALLOW FILTERING" if need_filtering else ""
    
    # Get total call count
    total_query = f"SELECT COUNT(*) FROM calldrop.call_records WHERE {base_where}{allow_filtering};"
    total_output = run_cql_query(total_query)
    
    if not total_output:
        print("Failed to get total call count")
        return
    
    # Parse the count from cqlsh output
    total_count = parse_cqlsh_count(total_output)
    
    if total_count == 0:
        print(f"No calls found for date range {start_date} to {end_date}")
        if phone:
            print(f"  (phone: {phone})")
        return
    
    # Get successful call count
    # Note: Even with partition key specified, we need ALLOW FILTERING since call_success isn't in the primary key
    success_query = f"SELECT COUNT(*) FROM calldrop.call_records WHERE {base_where} AND call_success = true ALLOW FILTERING;"
    success_output = run_cql_query(success_query)
    
    if not success_output:
        print("Failed to get success count")
        return
    
    success_count = parse_cqlsh_count(success_output)
    
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
