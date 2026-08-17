# Security and Operational Safety

## 1. Scope

This project may connect to internal Spark History Server and YARN ResourceManager endpoints and may process event logs containing internal application metadata. Treat those sources as potentially sensitive.

## 2. Secrets

- Never commit passwords, tokens, Kerberos keytabs, cookies, private certificates, or internal credentials.
- Use environment variables/secret stores appropriate to the environment.
- `.env` files containing secrets must be ignored by version control.
- Provide `.env.example` with placeholders only.

## 3. Endpoint Configuration

- Do not hardcode production/internal hostnames in reusable source code.
- Use configurable base URLs and timeouts.
- Validate TLS/HTTPS where the environment supports it.
- Do not disable certificate verification as a permanent workaround.

## 4. Least Privilege

Collectors should use read-only permissions needed for metrics/history access. The recommendation prototype should not require scheduler/admin write access.

## 5. Sensitive Content in Logs

Spark event logs/history may expose:

- job/application names;
- filesystem paths;
- SQL text;
- configuration properties;
- user names or operational metadata.

Before sharing artifacts outside the authorized environment:

- sanitize hostnames/usernames/paths;
- redact credentials/config secrets;
- avoid publishing raw SQL/data samples without review.

## 6. Raw Data Retention

Keep raw research data immutable for reproducibility, but apply the organization's retention/access rules. If company data cannot leave the environment, store only sanitized derived artifacts in the public/student repo.

## 7. Shared Cluster Safety

- respect YARN queues and resource caps;
- do not run destructive OOM/stress tests without approval;
- rate-limit collectors if endpoints are sensitive;
- bound retries and request timeouts;
- never automatically submit all candidate configurations to production.

## 8. Demo Safety

The demo should be read-only/recommendation-only by default. If “apply configuration” is ever added, it must be a separate explicitly authorized feature with auditability and rollback—not part of the MVP.

## 9. Reference

Apache Spark security guidance includes protecting event-log locations with appropriate permissions and treating monitoring endpoints as security-sensitive surfaces:

- https://spark.apache.org/docs/latest/security.html
