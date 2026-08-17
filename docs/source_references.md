# Primary Technical References

These references are starting points. Implementation must still match the exact Spark/Hadoop versions used by the project.

`latest` and `stable` links below are discovery links only. For Phase 1, record the exact versioned documentation URLs consulted in the `benchmark_environment_id`/collector compatibility record and verify behavior against captured fixtures from the deployed runtime.

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
