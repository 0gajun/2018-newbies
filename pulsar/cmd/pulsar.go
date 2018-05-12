package main

import (
	"log"

	"github.com/0gajun/2018-newbies/pulsar"
	"github.com/go-redis/redis"
)

func main() {
	redis := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "",
		DB:       0,
	})

	server := pulsar.NewServer(redis)

	if err := server.ListenAndServe("127.0.0.1:3001"); err != nil {
		log.Fatalf("Failed to listen and server : %v\n", err)
	}
}
