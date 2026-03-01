# Technical Assessment: ScyllaDB Implementation for "CallDrop"

Hello Emmanuel,

To proceed with the hiring process, we would like you to complete the following technical task. Please read the requirements carefully. If you have any questions or require guidance, feel free to ask.

**Action Required:** Once you are ready to begin, please share your **public SSH key**. I will then provide you with the access details for 5 AWS instances to perform this task.

---

## 1. Preparation
Before starting the technical tasks, it is highly recommended to complete the following course:
* **S101: ScyllaDB Essentials** – Overview of ScyllaDB and NoSQL Basics.

---

## 2. Infrastructure & Setup
**Scenario:** You are part of the DevOps team at "CallDrop," a large Telco provider. Your goal is to deploy and configure a ScyllaDB environment on AWS instances running **Ubuntu**.

### System Configuration
You will be provided with **5 nodes**:
* **Nodes 1–3:** ScyllaDB Cluster nodes.
* **Node 4:** Monitoring node.
* **Node 5:** Client node (used to run your scripts).

### Installation Requirements
* **ScyllaDB:** Download and install the latest **Scylla Open Source** on Nodes 1–3 using the binary option (`apt-get`) from ScyllaDB.com.
* **Gossiping:** Configure the appropriate Gossiping protocol for AWS.
* **Monitoring:** Install the **Scylla Monitoring Stack** on Node 4 using the Docker container option.
* **Permissions:** You have `sudo` rights on all nodes to install necessary software.

---

## 3. Data Modeling & Population
Once the cluster is operational, design a data model for CallDrop’s call tracking information.

### Step A: LLM Assistance
Use an LLM of your choice (e.g., Gemini, Claude, or ChatGPT) to help create the schema.
* **Partition Key:** User’s phone number.
* **Clustering Key:** Destination number.
* **Other Columns:** * Call duration (seconds)
    * Source cell tower ID
    * Destination cell tower ID
    * Call successfully completed (Boolean)
    * Source phone IMEI number

### Step B: Data Entry
* **Records:** Generate approximately 15 users, with 20–25 call records per user.
* **Views:** Create a **Materialized View** based on the "successfully completed" column.

---

## 4. Analytics Scripting
The marketing team needs to calculate the success rate of calls within specific timeframes.

**Task:** Write a script (Bash, Python, Java, Go, etc.) on the **Client Node** that accepts:
1.  A range of time (Input).
2.  An optional phone number to filter by (Input).

**Output:**
* The percentage of successfully completed phone calls for that criteria.

---

## 5. Performance Analysis (Stage 3)
Once you complete the steps above, **email your output to us** to receive a data-loading script for Stage 3.

**Task:**
1.  Execute the provided script to load a large dataset.
2.  Rerun your analytics script from Section 4.
3.  Observe the Scylla Monitoring Dashboard.
4.  **Analysis:** Provide a written explanation for any **imbalance** observed between different Shards across the nodes.

---

## 6. Final Deliverables
Please provide the following outputs organized by item number:

### Part 1: Cluster Setup
* `nodetool status` output.
* Snapshots/screenshots of the Monitoring dashboard.

### Part 2: Data Model
* Keyspace and Table schemas.
* A sample output of data from the table.
* Documentation of the LLM process: Initial prompt, LLM output, revisions made, and final generation scripts used.

### Part 3: Analytics
* The source code used for the analytics program.
* A summary of your findings and a sample output based on a selected range scan.

### Part 4: System Insight
* A written explanation regarding the shard imbalance identified in the monitoring dashboard.