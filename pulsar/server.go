package pulsar

import (
	"github.com/go-redis/redis"
	"github.com/gorilla/mux"
)

type serverImpl struct {
	redis  *redis.Client
	router *mux.Router
}
