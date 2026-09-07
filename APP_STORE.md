# ENSPY Mobile App Store

Public page: `https://<ENSPY_DOMAIN>/application/`

Administration: menu **Application mobile**.

An administrator can upload an APK, define `versionName`, unique Android `versionCode`, release notes, publish/archive a version, activate/deactivate an existing version, delete releases, and view download counts and SHA-256.

Public API:
- GET `/api/app/latest`
- GET `/api/app/releases`
- GET `/api/app/releases/:id/download`

Admin API (JWT + admin role):
- GET `/api/app/admin/releases`
- POST `/api/app/admin/releases/upload`
- PATCH `/api/app/admin/releases/:id`
- DELETE `/api/app/admin/releases/:id`

APK files are stored in the persistent Docker `uploads_data` volume.
