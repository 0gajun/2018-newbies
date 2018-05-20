FROM golang:1.10-alpine as builder

RUN apk add --update make && \
      mkdir -p /go/src/github.com/0gajun/2018-newbies/pulsar

WORKDIR /go/src/github.com/0gajun/2018-newbies/pulsar

COPY . .

RUN make

FROM alpine

RUN mkdir -p /app

COPY --from=builder /go/src/github.com/0gajun/2018-newbies/pulsar/pulsar /app/pulsar

EXPOSE 3001
