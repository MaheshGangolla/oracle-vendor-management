# Evidence checklist

## Already in the repository
- [x] Architecture, data model, lifecycle and page map diagrams (`evidence/`)
- [x] Complete DDL, PL/SQL packages, scheduler job, REST module
- [x] utPLSQL test suites
- [x] Synthetic sample data only; no client names, credentials or environment URLs

## To add after deployment
- [ ] `install.sql` run log showing no invalid objects
- [ ] utPLSQL results (`ut.run` output)
- [ ] Split APEX export in `apex/`
- [ ] Screenshots, synthetic data only:
  - [ ] Home dashboard (pipeline cards, risk donut, expiring documents)
  - [ ] Vendors interactive report
  - [ ] Vendor 360: risk breakdown and approval chain
  - [ ] My Approvals inbox and decision dialog
  - [ ] Document expiry calendar
  - [ ] Administration: approval rules grid
- [ ] REST call result for `GET /v1/vendors/` (hostname masked)

Mask workspace names, hostnames and real user e-mail addresses in every screenshot.
