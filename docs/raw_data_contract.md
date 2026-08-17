# Raw Collection Artifact Contract

## 1. Purpose

This contract defines the immutable evidence produced by Phase 1 collectors. Raw artifacts preserve source payloads and request context; they are not canonical execution records and contain no feature engineering or recommendation logic.

## 2. Artifact Boundary

One raw artifact represents one captured source response, event-log object, or explicitly recorded collection failure. A collection operation may produce multiple artifacts for one Spark application.

Payload bytes must be stored without semantic transformation. Compression is allowed only when the compression method is recorded and decompression reproduces the captured bytes. Sanitized fixtures are separate derived test assets and must not replace restricted raw evidence.

## 3. Required Manifest

Each artifact has a sidecar manifest with these fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `raw_contract_version` | string | yes | Manifest contract version, initially `raw_v1` |
| `raw_artifact_id` | string | yes | Unique immutable artifact identifier |
| `source_system` | enum | yes | `SPARK_HISTORY`, `SPARK_EVENT_LOG`, or `YARN_RM` |
| `source_operation` | string | yes | Stable collector operation name; do not store credentials |
| `source_endpoint_path` | string/null | no | Sanitized relative API path when applicable |
| `request_parameters` | object/null | no | Sanitized parameters affecting the response |
| `spark_application_id` | string/null | no | Source-observed or request-scoped application ID |
| `application_attempt_id` | string/null | no | YARN/Spark attempt identity where available |
| `collected_at` | timestamp | yes | UTC collection timestamp |
| `http_status` | int/null | no | HTTP response status when applicable |
| `content_type` | string/null | no | Captured response content type |
| `content_encoding` | string/null | no | Encoding/compression needed to recover payload bytes |
| `payload_path` | string/null | no | Repository/data-root-relative payload location |
| `payload_size_bytes` | int/null | no | Captured payload size |
| `payload_sha256` | string/null | no | SHA-256 of the stored payload bytes |
| `source_versions` | object | yes | Exact observed Spark/Hadoop/YARN versions or explicit unknown reasons |
| `benchmark_environment_id` | string | yes | Versioned environment snapshot identifier |
| `collector_version` | string | yes | Collector/schema implementation version |
| `collection_status` | enum | yes | `SUCCEEDED`, `FAILED`, or `PARTIAL` |
| `error_type` | string/null | no | Stable error category for failed/partial collection |
| `error_message` | string/null | no | Sanitized diagnostic; never include secrets |
| `sanitization_status` | enum | yes | `RESTRICTED_RAW`, `SANITIZED_FIXTURE`, or `NOT_REQUIRED` |

For a successful payload artifact, `payload_path`, `payload_size_bytes`, and `payload_sha256` are required. For a failed request with no payload, they remain null and the error fields are required.

## 4. Storage Layout

Recommended append-only layout:

```text
data/raw/<source_system>/<collection_date>/<spark_application_id-or-unknown>/<raw_artifact_id>/
  manifest.json
  payload.<source-extension>
```

Retries produce new artifact IDs. A collector must not overwrite an earlier response or failure record.

## 5. Identity and Correlation

- `spark_application_id` is the primary Spark/YARN correlation key where both sources expose it.
- `application_attempt_id` distinguishes retries/attempts and must not be collapsed silently.
- SQL execution and stage identifiers are children of the Spark application and are normalized later.
- Application-name matching is diagnostic only and is not a reliable correlation key.
- Any ambiguous or unavailable mapping is recorded as a limitation rather than guessed.

## 6. Version and Capability Evidence

The environment snapshot referenced by `benchmark_environment_id` records at least:

- exact Spark version;
- exact Hadoop/YARN version;
- Java and Python versions;
- deployment mode;
- distribution/container image version or digest;
- History Server and event-log configuration relevant to collection;
- enabled authentication mode without credentials.

Source capability discovery must distinguish `NOT_EXPOSED_BY_SOURCE`, `PARSER_UNSUPPORTED_VERSION`, `NOT_APPLICABLE`, and `COLLECTION_FAILED`.

## 7. Integrity and Immutability

- Verify `payload_sha256` when an artifact is read for normalization.
- Never edit a persisted raw artifact in place.
- Parser fixes create new normalized outputs; they do not rewrite raw evidence.
- Retention or access restrictions may archive/remove restricted artifacts only under an approved data-governance process with an audit record.

## 8. Security

- Strip credentials, tokens, cookies, and sensitive query parameters from manifests and logs.
- Restricted raw payloads may contain SQL text, paths, users, or configuration secrets and must follow `security_and_operations.md`.
- Sanitized fixtures must have new artifact IDs and record their relationship to the restricted source without exposing it.

## 9. Contract Tests

Phase 1 contract tests must verify:

- required manifest fields and enums;
- successful versus failed-artifact invariants;
- checksum correctness;
- append-only retry behavior;
- sanitized endpoint/request metadata;
- explicit version unknowns and source capability gaps;
- Spark/YARN application identity mapping on representative fixtures.

## 10. Evolution

- `raw_contract_version` changes when manifest meaning or required fields change.
- Adding optional fields may be a minor revision.
- Changing checksum semantics, identity meaning, or payload immutability requires an ADR and migration note.
