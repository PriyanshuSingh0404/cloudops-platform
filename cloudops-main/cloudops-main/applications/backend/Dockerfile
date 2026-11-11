# Build
FROM golang:1.25.7-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o main .

# Run binary only
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/main .
EXPOSE 5000
CMD ["./main"]
