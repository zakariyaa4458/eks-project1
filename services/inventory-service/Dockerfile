#Initial stage
FROM golang:1.22-alpine AS builder
RUN adduser --disabled-password appuser 
USER appuser
WORKDIR /app
COPY go.mod go.sum ./
RUN apk add --no-cache git
RUN go mod download
COPY . .
RUN go build -o main .

#final stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/main .
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3  \
CMD curl -f http://localhost:8082/healthz || exit 1
EXPOSE 8082
CMD ["./main"]