# apex/

This folder holds the APEX application definition.

| File | Status |
| --- | --- |
| [APP_DESIGN.md](APP_DESIGN.md) | Page-by-page specification: authorization schemes, LOVs, pages, items and the package calls behind every button |
| `f<app_id>.sql` or `f<app_id>/` | **Not yet included.** Add the real export after building the application |

## Adding the application export

Export with SQLcl so the definition is reviewable in Git (one file per page):

```bash
sql <user>@<connect>
SQL> apex export -applicationid <app_id> -split -skipExportDate -expOriginalIds
```

Or in the browser: **App Builder > (application) > Export / Import > Export**, then commit `f<app_id>.sql` here.

Before committing, check the export for workspace-specific values, such as e-mail addresses in
authentication settings, web credential names, and remote server URLs, and replace them with placeholders.
