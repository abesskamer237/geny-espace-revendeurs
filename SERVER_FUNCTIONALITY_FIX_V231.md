# ENSPY Server 2.3.1 — functionality compatibility fix

## Fixed
- Added `notifications.filiere_id` with migration 0008.
- Calendar event creation no longer fails when it creates the corresponding notification.
- Student notification delivery now respects level + filière targeting.
- Admin notification creation (JSON and multipart) can target a filière.
- Public application version history now returns archived releases too; only the active release remains downloadable.
- Existing PostgreSQL, uploads, HTTPS and API routes remain additive.

## Deployment
Run `./update.sh` on an existing installation after updating the repository. The migration is idempotent.
