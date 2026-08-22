# Benchmark Environment — LOCAL_YARN_V1

## 1. Status and Purpose

- Environment ID: `LOCAL_YARN_V1`
- Current status: **PLANNED**
- Physical host: personal workstation with 16 GB physical RAM
- Purpose: controlled local Spark-on-YARN research testbed
- Non-goal: production-cluster emulation

This environment will run synthetic inputs through real Spark jobs and expose real Spark History Server/event-log and YARN ResourceManager evidence. No exact version, image, host capacity, or service capacity in this document is considered verified until it is measured from the deployed environment.

## 2. Planned Logical Topology

All services run on one physical host. The two workers are logical isolation units, not two independent physical machines.

```text
Control services
  - HDFS NameNode
  - YARN ResourceManager
  - Spark History Server

Worker 1
  - HDFS DataNode
  - YARN NodeManager NM1

Worker 2
  - HDFS DataNode
  - YARN NodeManager NM2
```

## 3. Initial Planned Resource Envelope

| Component | Planned capacity | Evidence status |
|---|---:|---|
| NodeManager `NM1` | about 2 vcores / about 3 GB YARN memory | PLANNED |
| NodeManager `NM2` | about 2 vcores / about 3 GB YARN memory | PLANNED |

These values are feasibility estimates for a 16 GB workstation. Container minimum allocation, OS/Docker overhead, HDFS/Spark service memory, and usable host memory must be measured before benchmark configuration bounds are approved. The deployed values may be smaller.

## 4. Required Verified Snapshot

Before the status of `benchmark_environment_id = LOCAL_YARN_V1` changes to **VERIFIED**, observe and record:

- host CPU model and logical/physical core counts;
- physical RAM and measured available RAM before services start;
- host OS and architecture;
- container/runtime engine and version;
- exact Spark version;
- exact Hadoop/YARN version;
- exact Java version;
- exact Python version;
- image names plus immutable digests or distribution/build identifiers;
- HDFS/YARN/Spark History Server service configuration versions;
- YARN scheduler/queue and minimum/maximum allocation settings;
- each NodeManager's advertised vcores and memory;
- total effective YARN vcores and memory;
- Spark event-log and History Server locations/configuration;
- time zone/clock assumptions;
- mechanism used to observe swap and background host load.

Store environment-specific endpoints and secrets outside committed documentation. A sanitized resolved snapshot may be committed under a future versioned environment config.

## 5. Verification Checklist

- [ ] HDFS health check passes and a test artifact can be written/read.
- [ ] Both logical DataNodes and NodeManagers register as intended.
- [ ] YARN reports measured scheduler and NodeManager capacities.
- [ ] Spark submits in YARN mode with static allocation.
- [ ] Spark event logs are persisted.
- [ ] Spark History Server displays the completed application.
- [ ] YARN ResourceManager exposes the same application ID/attempt evidence.
- [ ] Host swap and background-load observations can be recorded.
- [ ] Exact versions and immutable image/distribution identifiers are captured.
- [ ] The resolved snapshot is reviewed before the environment status changes to `VERIFIED`.

## 6. Validity and Limitations

- Host swap during a benchmark invalidates that run pending investigation.
- Excessive background load must be flagged; important comparisons should be rerun.
- Two logical NodeManagers/containers on one host share CPU, RAM, memory bandwidth, disk, network, and host noise. They are not equivalent to independent physical enterprise workers.
- Local configurations and recommendations are specific to `LOCAL_YARN_V1`.
- Production/company use requires collecting target-environment execution history and retraining or explicitly calibrating the model/policy for that environment.
- Company history must retain its own environment IDs and provenance; it must not be relabeled as local benchmark data.

## 7. Change Control

After an environment becomes **VERIFIED**, any material change to capacity, Spark/Hadoop patch version, image digest, scheduler boundary, or service topology creates a new environment snapshot. A material compatibility or capacity change should receive a new `benchmark_environment_id` rather than silently mutating verified evidence.
