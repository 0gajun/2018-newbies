package main

import (
	"log"
	"os"

	"github.com/0gajun/2018-newbies/pulsar"
	"github.com/go-redis/redis"
)

func main() {
	redis := redis.NewClient(&redis.Options{
		Addr:     getRedisAddr(),
		Password: "",
		DB:       0,
	})

	server := pulsar.NewServer(redis)

	bindAddr := getBindAddr()

	log.Printf("Listening on %s", bindAddr)

	if err := server.ListenAndServe(bindAddr); err != nil {
		log.Fatalf("Failed to listen and server : %v\n", err)
	}
}

func getRedisAddr() string {
	if redisAddr, ok := os.LookupEnv("REDIS_ADDR"); ok {
		return redisAddr
	}
	return "localhost:6379"
}

func getBindAddr() string {
	if bindAddr, ok := os.LookupEnv("PULSAR_BIND_ADDR"); ok {
		return bindAddr
	}
	return "127.0.0.1:3001"
}
