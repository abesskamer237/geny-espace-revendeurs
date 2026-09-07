# ENSPY v2.3.0 — Security hardening

- Private document/attachment files require a valid Bearer JWT.
- Advertisement images use `/api/ads/media/:filename` and are public only when referenced by an advertisement.
- Fresh installations generate a unique initial administrator password in `.env`.
- The API rotates only the historical demo admin hash; an already changed password is never overwritten.
- The VPS installer accepts proxied DNS such as Cloudflare and relies on ACME HTTP validation instead of a strict DNS-IP equality test.
