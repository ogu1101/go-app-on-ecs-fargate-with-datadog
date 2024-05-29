FROM golang:latest

WORKDIR /usr/src/app

# pre-copy/cache go.mod for pre-downloading dependencies and only redownloading them in subsequent builds if they change
COPY go.mod go.sum main.go ./
RUN go mod download && go mod verify

RUN go build -v -o /usr/local/bin/app -tags appsec ./...

ARG DD_GIT_REPOSITORY_URL
ARG DD_GIT_COMMIT_SHA
ENV DD_AGENT_HOST="datadog-agent" \
    DD_APPSEC_ENABLED=true \
    DD_DBM_PROPAGATION_MODE=full \
    DD_GIT_REPOSITORY_URL=${DD_GIT_REPOSITORY_URL} \
    DD_GIT_COMMIT_SHA=${DD_GIT_COMMIT_SHA} \
    DD_IAST_ENABLED=true \
    # DD_LOGS_INJECTION=true \
    # DD_PROFILING_ENABLED=true \
    DD_PROFILING_EXECUTION_TRACE_ENABLED=true \
    DD_PROFILING_EXECUTION_TRACE_PERIOD=15m \
    DD_TRACE_AGENT_PORT="8126" \
    DD_TRACE_CLIENT_IP_ENABLED=true

EXPOSE 8080
CMD ["app"]
