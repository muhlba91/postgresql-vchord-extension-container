ARG POSTGRESQL_MAJOR_VERSION=18
# renovate: datasource=github-releases packageName=pgsty/vchord
ARG VCHORD_VERSION=1.5.0

FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS builder

ARG TARGETARCH
ARG POSTGRESQL_MAJOR_VERSION
ARG VCHORD_VERSION

WORKDIR /tmp

# the release zip is built for glibc 2.35 or newer and bundles no other libraries
RUN case "${TARGETARCH}" in \
    amd64) arch="x86_64" ;; \
    arm64) arch="aarch64" ;; \
    *) echo "unsupported architecture: ${TARGETARCH}" >&2 && exit 1 ;; \
  esac && \
  asset="postgresql-${POSTGRESQL_MAJOR_VERSION}-vchord_${VCHORD_VERSION}_${arch}-linux-gnu.zip" && \
  url="https://github.com/pgsty/vchord/releases/download/${VCHORD_VERSION}" && \
  wget -q "${url}/${asset}" && \
  wget -q "${url}/${asset}.sha256" && \
  sha256sum -c "${asset}.sha256" && \
  unzip -q "${asset}" -d /tmp/vchord && \
  mkdir -p /out/lib /out/share/extension /out/licenses/vchord && \
  cp /tmp/vchord/pkglibdir/vchord.so /out/lib/ && \
  cp /tmp/vchord/sharedir/extension/* /out/share/extension/ && \
  cp /tmp/vchord/LICENSE /out/licenses/vchord/ && \
  chmod -R a+rX /out

FROM scratch

ARG CI_COMMIT_TIMESTAMP
ARG CI_COMMIT_SHA
ARG CI_COMMIT_TAG
ARG CI_UPSTREAM_VERSION
ARG POSTGRESQL_MAJOR_VERSION
ARG VCHORD_VERSION

LABEL org.opencontainers.image.authors="Daniel Muehlbachler-Pietrzykowski <dev@muehlbachler.io>"
LABEL org.opencontainers.image.vendor="Daniel Muehlbachler-Pietrzykowski"
LABEL org.opencontainers.image.source="https://github.com/muhlba91/postgresql-vchord-extension-container"
LABEL org.opencontainers.image.created="${CI_COMMIT_TIMESTAMP}"
LABEL org.opencontainers.image.title="cloudnativepg-postgresql-vchord-extension"
LABEL org.opencontainers.image.description="A CloudNativePG extension image providing vchord for PostgreSQL"
LABEL org.opencontainers.image.revision="${CI_COMMIT_SHA}"
LABEL org.opencontainers.image.version="${CI_COMMIT_TAG}"
LABEL org.opencontainers.image.upstream="${CI_UPSTREAM_VERSION}"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"
LABEL io.cloudnativepg.image.base.pgmajor="${POSTGRESQL_MAJOR_VERSION}"
LABEL io.cloudnativepg.image.sql.version="${VCHORD_VERSION}"

COPY --from=builder /out/licenses/ /licenses/

COPY --from=builder /out/lib/ /lib/

COPY --from=builder /out/share/ /share/

USER 65532:65532
