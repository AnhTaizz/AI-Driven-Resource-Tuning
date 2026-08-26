# Primary Technical References

These references are starting points. Implementation must still match the exact Spark/Hadoop versions used by the project.

`latest` and `stable` links below are discovery links only. For Phase 1, record the exact versioned documentation URLs consulted in the `benchmark_environment_id`/collector compatibility record and verify behavior against captured fixtures from the deployed runtime.

## TPC-DS Benchmark Foundation

Authoritative sources consulted for P01 on 2026-08-25:

- TPC current specifications/source page: https://www.tpc.org/tpc_documents_current_versions/current_specifications5.asp
- TPC-DS Standard Specification 4.0.0: https://www.tpc.org/TPC_Documents_Current_Versions/pdf/TPC-DS_v4.0.0.pdf

Repository-local evidence inspected without building or executing it:

- `../B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool/DSGen-software-code-4.0.0/EULA.txt` — TPC EULA version 2.2;
- `../B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool/DSGen-software-code-4.0.0/specification/specification_4.0.0.pdf` — committed specification copy;
- `../B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool/DSGen-software-code-4.0.0/tools/release.h` — source version macros `4.0.0`;
- current committed toolkit Git tree object at audit time: `749d129d1a22e2828b0be787231904be7563a135`.

The official source page and committed filenames/version macros agree on version 4.0.0, but the repository has no acquisition URL/date, original archive hash/signature, or provenance manifest tying the committed bytes to that upstream download. Git integrity is not proof of upstream authenticity. Licensing, continued public redistribution, and future packaging require human review; see `tpcds_implementation_plan.md`.

Project outputs must be described as a **TPC-DS-based controlled benchmark** using **TPC-DS-derived analytical workloads**, not as an official complete TPC-DS benchmark or results comparable to official TPC Benchmark Results.

## Apache Spark

- Monitoring and Instrumentation: https://spark.apache.org/docs/latest/monitoring.html
- Web UI / History Server: https://spark.apache.org/docs/latest/web-ui.html
- Configuration: https://spark.apache.org/docs/latest/configuration.html
- Running Spark on YARN: https://spark.apache.org/docs/latest/running-on-yarn.html
- Security: https://spark.apache.org/docs/latest/security.html
- Tuning: https://spark.apache.org/docs/latest/tuning.html

## Apache Hadoop YARN

- ResourceManager REST APIs: https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/ResourceManagerRest.html
- YARN Web Services Introduction: https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/WebServicesIntro.html
- YARN Overview: https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/YARN.html

## scikit-learn

- GroupKFold: https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupKFold.html
- TimeSeriesSplit: https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html
- Cross-validation guide: https://scikit-learn.org/stable/modules/cross_validation.html

## MLflow — Optional Tooling

MLflow is not mandatory for the MVP. If adopted, use it for experiment/model lineage rather than as architectural ceremony.

- Experiment Tracking: https://mlflow.org/docs/latest/ml/tracking/
- Model Registry: https://mlflow.org/docs/latest/ml/model-registry/
