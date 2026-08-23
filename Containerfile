FROM docker.io/library/golang@sha256:28d89ee9cc0ff9fec75c82ca201e6bf7fdf9a679d4b7b24dfa04f2bb766bb468 AS build
ENV GOPROXY=https://proxy.golang.org,direct
RUN apk add --no-cache ca-certificates git
WORKDIR /src
COPY go.mod go.sum ./
RUN GOPROXY=direct go mod download github.com/klauspost/compress@v1.18.5
RUN go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/controller ./cmd/controller \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/agent ./cmd/agent \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/infra ./cmd/infra

FROM docker.io/library/alpine@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40
RUN addgroup -S nodecontrol -g 10001 && adduser -S -D -H -u 10001 -G nodecontrol nodecontrol
COPY --from=build /out/controller /usr/local/bin/controller
COPY --from=build /out/agent /usr/local/bin/agent
COPY --from=build /out/infra /usr/local/bin/infra
USER 10001:10001
ENTRYPOINT ["/usr/local/bin/controller"]
