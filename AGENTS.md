# AGENTS.md

- Build an extension image for CloudNativePG: `/lib/vchord.so`, `/share/extension/*` and `/licenses/vchord/` only, no OS packages.
- Keep versions in the Dockerfile (`VCHORD_VERSION`) and the `verify.yml` matrix; Renovate updates them through `# renovate:` comments.
- Run `make check` before finishing; it lints and runs the smoke test.
- Write commits as Conventional Commits, lowercase, imperative, scopes only `ci`, `deps` and `release`.
- The README follows the container layout of `postgresql-pgvecto-container`, not the IaC skeleton.
