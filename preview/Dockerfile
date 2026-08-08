# Dockerfile — 7 of these in your tree, and you have both the Docker and
# Containers extensions installed in VS Code.
#
# No numeric prefix: both editors detect this file by exact name, so
# `20-Dockerfile` would fall back to plain text.
#
# syntax=docker/dockerfile:1.9

ARG GO_VERSION=1.26
ARG ALPINE_VERSION=3.21

# ── Build stage ───────────────────────────────────────────────────────────

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS build

ARG BUILD_REV=dev
ARG TARGETARCH

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOFLAGS="-trimpath" \
    GOCACHE=/root/.cache/go-build

WORKDIR /src

RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache git ca-certificates tzdata

COPY go/go.mod ./go/
RUN --mount=type=cache,target=/root/.cache/go-build \
    cd go && go mod download && go mod verify

COPY go/ ./go/

RUN --mount=type=cache,target=/root/.cache/go-build <<EOF
set -eux
cd go
go build \
  -ldflags="-s -w -X main.revision=${BUILD_REV}" \
  -o /out/preview \
  .
/out/preview --version || true
EOF

# ── Test stage, skipped unless targeted ───────────────────────────────────

FROM build AS test

RUN cd go && go vet ./... && go test ./... 2>/dev/null || echo "no tests"

# ── Runtime stage ─────────────────────────────────────────────────────────

FROM alpine:${ALPINE_VERSION} AS runtime

LABEL org.opencontainers.image.title="preview" \
      org.opencontainers.image.description="Leo Dark parity corpus sample" \
      org.opencontainers.image.source="https://github.com/LeoManrique/leo-theme" \
      org.opencontainers.image.licenses="MIT"

ENV TZ=Europe/Madrid \
    LOG_LEVEL=info \
    PATH="/usr/local/bin:${PATH}"

RUN addgroup -g 10001 -S preview \
 && adduser  -u 10001 -S preview -G preview -h /home/preview \
 && mkdir -p /etc/preview \
 && chown -R preview:preview /etc/preview

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build --chown=preview:preview /out/preview /usr/local/bin/preview
COPY --chmod=0644 09-config.json /etc/preview/config.json

USER preview:preview
WORKDIR /home/preview

VOLUME ["/etc/preview"]
EXPOSE 8080/tcp 9090/tcp

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider -q http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/preview"]
CMD ["--addr=:8080", "--metrics=:9090"]

ONBUILD RUN echo "this only runs in a downstream build"
