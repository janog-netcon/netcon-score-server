FROM golang:1.15-alpine as builder

WORKDIR /go/src/app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /go/bin/app

FROM scratch

COPY --from=builder /go/bin/app /go/bin/app

EXPOSE 8080

ENTRYPOINT ["/go/bin/app"]
