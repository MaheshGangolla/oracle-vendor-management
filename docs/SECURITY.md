# Security design

| Layer | Control |
| --- | --- |
| Authentication | APEX Accounts for demo only; production uses OCI IAM Identity Domains / Oracle IDCS through OpenID Connect |
| Authorization (UI) | APEX authorization schemes call `vom_security.has_role` and hide pages, regions and buttons |
| Authorization (server) | Packages call `vom_security.assert_role` before every privileged action, so UI hiding is never the only control |
| Segregation of duties | Approval steps are role-based; each step needs a user holding that step's role |
| Data validation | Check constraints (status, risk level, e-mail format, date order) and unique tax ID per country |
| Documents | Stored as BLOBs inside the database; upload limited to PDF / PNG / JPEG up to 10 MB (page validation) |
| Audit | `VOM_AUDIT_LOG` records who did what and when for vendors, documents and approval steps |
| REST API | Read-only; exposes approved vendors only; no document content |
| Secrets | No credentials in this repository; mail and identity settings are configured in the APEX instance |

## Protecting the REST API

`ords/vendor_api_module.sql` publishes the module without a privilege so it can be tested.
Before exposing it outside the database network:

1. Create an ORDS role and privilege covering the `vom.vendor.api.v1` module (ORDS REST Workshop in APEX: *RESTful Services > Privileges*).
2. Create an OAuth client with the *client credentials* grant for each consuming system.
3. Give the client the role, and have consumers request a bearer token before calling `/v1/vendors/`.

## Before committing an application export

Check the export for workspace-specific values, such as e-mail addresses, web credential names, remote server URLs and authentication provider endpoints, and replace them with placeholders.
