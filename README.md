# PostgreSQL vchord Extension Container

[![](https://img.shields.io/github/license/muhlba91/postgresql-vchord-extension-container?style=for-the-badge)](LICENSE)
[![](https://img.shields.io/github/actions/workflow/status/muhlba91/postgresql-vchord-extension-container/release.yml?style=for-the-badge)](https://github.com/muhlba91/postgresql-vchord-extension-container/actions/workflows/release.yml)
[![](https://api.scorecard.dev/projects/github.com/muhlba91/postgresql-vchord-extension-container/badge?style=for-the-badge)](https://scorecard.dev/viewer/?uri=github.com/muhlba91/postgresql-vchord-extension-container)
[![](https://img.shields.io/github/v/tag/muhlba91/postgresql-vchord-extension-container?style=for-the-badge)](https://github.com/muhlba91/postgresql-vchord-extension-container/releases)
[![](https://img.shields.io/github/release-date/muhlba91/postgresql-vchord-extension-container?style=for-the-badge)](https://github.com/muhlba91/postgresql-vchord-extension-container/releases)
<a href="https://www.buymeacoffee.com/muhlba91" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="28" width="150"></a>

An extension image providing [vchord](https://github.com/pgsty/vchord) for PostgreSQL, built for [CloudNativePG image volume extensions](https://cloudnative-pg.io/docs/1.30/imagevolume_extensions). It replaces the full image [postgresql-pgvecto-container](https://github.com/muhlba91/postgresql-pgvecto-container), which bundles vchord into the CloudNativePG PostgreSQL image.

---

> [!IMPORTANT]
> vchord requires the `vector` extension: `CREATE EXTENSION vchord` fails without it.
> Mount the [pgvector extension image](https://github.com/cloudnative-pg/postgres-extensions-containers/tree/main/pgvector) next to this image, as shown below.

---

## Requirements

- [mise](https://mise.jdx.dev)

## Installation Notes

The image holds only the vchord library and SQL files for one PostgreSQL major version; it is attached to a CloudNativePG `Cluster` through `.spec.postgresql.extensions`. The `Cluster` image, the extension image and the CPU architecture must match in PostgreSQL major version; the library needs glibc 2.35 or newer and is tested against the `trixie` image. Adding or updating an extension image restarts the PostgreSQL pods.

The cluster needs:

- PostgreSQL 18 or later, with the [`minimal` CloudNativePG image](https://github.com/cloudnative-pg/postgres-containers?tab=readme-ov-file#minimal-images)
- Kubernetes 1.35 or later (1.33 and 1.34 need the `ImageVolume` feature gate)

### Container Tags

The container images are `ghcr.io/muhlba91/postgresql-vchord-extension:<TAG>` and are published for `linux/amd64` and `linux/arm64`. The tagging scheme is `<VCHORD_TAG>-<POSTGRESQL_MAJOR_VERSION>[-<RELEASE_TAG>]` with:

- `<VCHORD_TAG>`: the [vchord](https://github.com/pgsty/vchord/releases) version
- `<POSTGRESQL_MAJOR_VERSION>`: the PostgreSQL major version the library is built for
- `<RELEASE_TAG>`: the release version of this container (versions internal changes; pin it, as the tag without it moves)

Additionally, `<GIT_COMMIT_SHA>-<POSTGRESQL_MAJOR_VERSION>` tags reference the commit of a build.

### Usage

Add both extension images to the `Cluster`, load `vchord` through `shared_preload_libraries` and create the extensions in the database. The `# renovate:` comments are read by the custom manager from [Renovate](#renovate).

```yaml
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-vchord
spec:
  instances: 1

  # renovate: datasource=docker packageName=ghcr.io/cloudnative-pg/postgresql versioning=regex:^(?<major>19)\.(?<minor>\d+)-minimal-trixie$
  imageName: ghcr.io/cloudnative-pg/postgresql:19.0-minimal-trixie

  storage:
    size: 1Gi

  postgresql:
    shared_preload_libraries:
      - vchord
    extensions:
      - name: pgvector
        image:
          # renovate: datasource=docker packageName=ghcr.io/cloudnative-pg/pgvector versioning=regex:^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)-19-trixie$
          reference: ghcr.io/cloudnative-pg/pgvector:0.8.7-19-trixie
      - name: vchord
        image:
          # renovate: datasource=docker packageName=ghcr.io/muhlba91/postgresql-vchord-extension versioning=regex:^\d+\.\d+\.\d+-19-v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$
          reference: ghcr.io/muhlba91/postgresql-vchord-extension:1.5.0-19-v2.0.0

---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: cluster-vchord-app
spec:
  name: app
  owner: app
  cluster:
    name: cluster-vchord
  extensions:
    - name: vector
      # renovate: datasource=docker packageName=ghcr.io/cloudnative-pg/pgvector extractVersion=^(?<version>\d+\.\d+\.\d+)-19-trixie$
      version: "0.8.7"
    - name: vchord
      # renovate: datasource=docker packageName=ghcr.io/muhlba91/postgresql-vchord-extension extractVersion=^(?<version>\d+\.\d+\.\d+)-19-v\d+\.\d+\.\d+$
      version: "1.5.0"
```

List `vector` before `vchord` in the `Database`. Check the installation in the database with `\dx`: `vector` and `vchord` are listed.

### Renovate

Add this custom manager to the `renovate.json` of the repository holding the manifests:

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/\\.ya?ml$/"],
      "matchStrings": [
        "# renovate: datasource=(?<datasource>[a-z-]+) packageName=(?<packageName>\\S+)(?: versioning=(?<versioning>\\S+))?(?: extractVersion=(?<extractVersion>\\S+))?\\s+[\\w.-]+: [\"']?(?:[^:\\s\"']+:)?(?<currentValue>[^\\s\"']+)[\"']?"
      ]
    }
  ],
  "enabledManagers": ["custom.regex"]
}
```

Merge `enabledManagers` into the existing list. The image references and the `Database` versions then update together: a version is proposed only when the matching image tag exists.

### Upgrading vchord

Update the `vchord` image reference and the `Database` version together, which Renovate does in one pull request. Read the [vchord release notes](https://github.com/pgsty/vchord/releases) first: some releases require rebuilding indexes or changing index options.

---

## Development

Tool versions (hadolint, shellcheck, markdownlint-cli2) are managed with mise: run `mise trust` and `mise install` once, then use `make lint` and `make test`. `make test` builds the image for the host platform and runs a smoke test against the latest minor of the `minimal` PostgreSQL image and the pgvector extension image; set `CONTAINER_ENGINE=podman` to use podman.

The Dockerfile downloads the [vchord release](https://github.com/pgsty/vchord/releases) for the PostgreSQL major version, verifies its checksum and copies the library and SQL files into an empty image. The PostgreSQL major versions are a matrix in `.github/workflows/verify.yml` and `.github/workflows/release.yml`: add a major there and its `pgvector_image` to the `verify.yml` entry; the PostgreSQL image is derived from the major and the `trixie` distribution.

vchord is licensed under AGPL-3.0-only; its license is shipped in `/licenses/vchord` of the image.

---

## Contributing

Contributions are welcome.

## Supporting

To support the work, buy me a coffee.

<a href="https://www.buymeacoffee.com/muhlba91" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="75" width="300"></a>
