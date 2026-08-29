FROM golang:1.22-alpine AS builder 
WORKDIR /app
COPY go.mod go.sum ./
RUN apk add --no-cache git 
RUN go mod download
COPY . .
EXPOSE 8086
RUN go build -o main .

#final stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app .
CMD ["./main"]