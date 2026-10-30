# Installation

## Prerequisites

| Requirement | Version / note |
| --- | --- |
| Oracle Database | 19c or later, or Autonomous Database (Always Free works) |
| Oracle APEX | 23.2 or later |
| ORDS | required only for the REST API |
| SQLcl | recommended for running the scripts and exporting the app |
| utPLSQL | v3, required only to run the tests |
| APEX instance mail | configured, for notifications (optional) |

The scripts run in the APEX workspace's **parsing schema**. The schema needs `CREATE TABLE`, `CREATE VIEW`,
`CREATE PROCEDURE` and `CREATE JOB` (standard for APEX workspace schemas).

## Steps

1. **Install the database layer**
   ```bash
   sql <schema_user>@<connect_string>
   SQL> @database/install.sql
   ```
   The script stops on the first error and lists invalid objects at the end. That list should be empty.

2. **Load demo data (optional)**
   ```sql
   @database/data/02_sample_data.sql
   ```
   Replace the `DEMO_*` usernames in `VOM_USER_ROLES` with your APEX workspace users.

3. **Run the tests (optional)**
   ```sql
   exec ut.run('test_vom_risk_engine');
   exec ut.run('test_vom_workflow');
   ```

4. **Publish the REST API (optional)**
   ```sql
   @ords/vendor_api_module.sql
   ```
   Then protect it as described in [SECURITY.md](SECURITY.md) before exposing it.

5. **Build the APEX application** from [../apex/APP_DESIGN.md](../apex/APP_DESIGN.md).

6. **Export the application** to `apex/` (see [../apex/README.md](../apex/README.md)).

## Uninstall

```sql
@database/uninstall.sql
```
This removes every `VOM_` object, the scheduler job and the REST module. All data is lost.
