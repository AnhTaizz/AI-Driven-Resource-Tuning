# Model Card — <model version>

## Model Summary

- Model version:
- Model type:
- Training date:
- Git revision:
- Dataset version:
- Feature-set version:
- Random seed:
- Benchmark environment IDs:

## Intended Use

Predict candidate Spark runtime for resource recommendation.

## Inputs

List every input group and availability class.

## Target

- runtime unit:
- target construction:

## Training / Validation Protocol

- split method:
- hyperparameter selection method:
- preprocessing:

## Metrics

Report Track A (known workload) and Track B (unseen workload) separately, plus relevant subgroups:

- MAE
- MAPE
- RMSE
- R²
- candidate-ranking metrics if used

## Baseline Comparison

Compare prediction/decision value to approved baselines.

## Failure Regions

Describe workload/config regions where model error is high or data is sparse.

## Explainability

- feature importance method:
- interpretation limitations:

## Recommendation Integration

- candidate-space version:
- policy version:
- risk estimator version:

## Limitations

Explicitly state why the model should not be treated as an autonomous production tuner without further validation.
