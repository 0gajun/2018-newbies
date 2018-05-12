package pulsar

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/go-redis/redis"
	"github.com/gorilla/mux"
)

type Server interface {
	ListenAndServe(string) error
}

type serverImpl struct {
	redis  *redis.Client
	router *mux.Router
}

func NewServer(redis *redis.Client) Server {
	s := &serverImpl{
		redis:  redis,
		router: mux.NewRouter(),
	}

	s.routes()

	return s
}

func (s *serverImpl) ListenAndServe(addr string) error {
	return http.ListenAndServe(addr, s.router)
}

func (s *serverImpl) routes() {
	s.router.HandleFunc("/sse/user/{user_id:[0-9]+}/received_remit_requests", s.handleReceivedRemitRequests())
}

type receivedRemitRequestPayload struct {
	ID              int64 `json:"id"`
	UserID          int64 `json:"user_id"`
	RequestedUserID int64 `json:"requested_user_id"`
	Amount          int64 `json:"amount"`
}

func (rru *receivedRemitRequestPayload) toResponseJSONString() (string, error) {
	var response struct {
		ID int64 `json:"id"`
	}
	response.ID = rru.ID

	bytes, err := json.Marshal(&response)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func (s *serverImpl) handleReceivedRemitRequests() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		flusher, ok := w.(http.Flusher)

		if !ok {
			http.Error(w, "SSE unsupported!", http.StatusInternalServerError)
			return
		}

		vars := mux.Vars(r)
		userID := vars["user_id"]

		setSSEHeader(w)

		closeNotify := w.(http.CloseNotifier).CloseNotify()

		subscribeChannel := "user." + userID + ".received_remit_request"
		pubsub := s.redis.Subscribe(subscribeChannel)
		defer pubsub.Close()

		ch := pubsub.Channel()

		log.Printf("Started sse for user id = %s\n", userID)
		for {
			select {
			case msg, ok := <-ch:
				if !ok {
					log.Print("Redis connection is closed")
					return
				}

				log.Printf("received: %s\n", msg.Payload)

				data := receivedRemitRequestPayload{}
				if err := json.Unmarshal([]byte(msg.Payload), &data); err != nil {
					log.Printf("Failed to parse received msg... : %s (reason: %v)\n", msg.Payload, err)
					continue
				}

				response, err := data.toResponseJSONString()
				if err != nil {
					log.Printf("Failed to marshal response msg... (reason: %v)\n", err)
					continue
				}

				fmt.Fprintf(w, "data: %s\n\n", response)
				flusher.Flush()
			case <-closeNotify:
				log.Print("Closed connection by client")
				return
			}
		}
	}
}

func setSSEHeader(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
}
