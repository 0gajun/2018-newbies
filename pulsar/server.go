package pulsar

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

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
	s.router.HandleFunc("/sse/user/{user_id:[0-9]+}", s.handleSSE())
	s.router.HandleFunc("/sse/user/{user_id:[0-9]+}/received_remit_requests", s.handleReceivedRemitRequests())
	s.router.HandleFunc("/sse/user/{user_id:[0-9]+}/finished_charges", s.handleFinishedCharges())
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

type finishedChargesPayload struct {
	ID     int64  `json:"id"`
	UserID int64  `json:"user_id"`
	Amount int64  `json:"amount"`
	Result string `json:"result"`
}

func (fc *finishedChargesPayload) toResponseJSONString() (string, error) {
	var response struct {
		ID int64 `json:"id"`
	}
	response.ID = fc.ID
	bytes, err := json.Marshal(&response)
	if err != nil {
		return "", err
	}
	return string(bytes), err
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

		ticker := time.NewTicker(time.Duration(5) * time.Minute)
		defer ticker.Stop()

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
			case t := <-ticker.C:
				fmt.Fprintf(w, "event: ping\n")
				fmt.Fprintf(w, "data: {\"time\": \"%s\"}", t.String())
				flusher.Flush()
			case <-closeNotify:
				log.Print("Closed connection by client")
				return
			}
		}
	}
}

type mapRedisPayloadToResponse func(payload string) (string, error)

var subscribeChannels = map[string]mapRedisPayloadToResponse{
	"received_remit_requests": func(payload string) (string, error) {
		data := receivedRemitRequestPayload{}
		if err := json.Unmarshal([]byte(payload), &data); err != nil {
			return "", fmt.Errorf("Failed to parse received msg... : %s (reason: %v)\n", payload, err)
		}

		response, err := data.toResponseJSONString()
		if err != nil {
			return "", fmt.Errorf("Failed to marshal response msg... (reason: %v)\n", err)
		}

		return response, nil
	},
	"finished_charges": func(payload string) (string, error) {
		data := finishedChargesPayload{}
		if err := json.Unmarshal([]byte(payload), &data); err != nil {
			return "", fmt.Errorf("Failed to parse received msg... : %s (reason: %v)\n", payload, err)
		}

		response, err := data.toResponseJSONString()
		if err != nil {
			return "", fmt.Errorf("Failed to marshal response msg... (reason: %v)\n", err)
		}

		return response, nil
	},
}

func (s *serverImpl) handleSSE() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {

		flusher, ok := w.(http.Flusher)

		if !ok {
			http.Error(w, "SSE unsupported!", http.StatusInternalServerError)
			return
		}

		setSSEHeader(w)

		closeNotify := w.(http.CloseNotifier).CloseNotify()

		vars := mux.Vars(r)
		userID := vars["user_id"]

		wg := &sync.WaitGroup{}

		type funInMsg struct {
			ChannelName string
			Message     string
			Error       error
		}

		fanIn := make(chan funInMsg)
		quit := make(chan struct{})
		defer func() {
			quit <- struct{}{}
			wg.Wait()
			close(fanIn)
			close(quit)
		}()

		for channelName, mapper := range subscribeChannels {
			wg.Add(1)

			go func(channelName string, mapper mapRedisPayloadToResponse) {
				defer wg.Done()

				sub := s.redis.Subscribe("user." + userID + "." + channelName)
				defer sub.Close()

				for {
					select {
					case msg, ok := <-sub.Channel():
						if !ok {
							log.Print("Redis connection is closed")
							return
						}

						if msg.Payload == "error" {
							log.Print("Error in goroutine")
							fanIn <- funInMsg{Error: fmt.Errorf("error: undefined")}
							return
						}

						response, err := mapper(msg.Payload)
						if err != nil {
							log.Printf("failed to map redis payload(%s) to response\n", msg.Payload)
							return // TODO: Error handling
						}

						fanIn <- funInMsg{ChannelName: channelName, Message: response}
					case <-quit:
						log.Printf("quit channel is closed (for channel %s)", channelName)
						return
					}
				}
			}(channelName, mapper)
		}

		ticker := time.NewTicker(time.Duration(5) * time.Second)
		defer ticker.Stop()

		for {
			select {
			case msg, _ := <-fanIn:
				if msg.Error != nil {
					fmt.Println("fanIn error: ", msg.Error)
					return
				}

				fmt.Fprintf(w, "event: %s\n", msg.ChannelName)
				fmt.Fprintf(w, "data: %s\n\n", msg.Message)
				flusher.Flush()
			case t := <-ticker.C:
				fmt.Fprint(w, "event: ping\n")
				fmt.Fprintf(w, "data: {\"time\": \"%s\"}\n\n", t.String())
				flusher.Flush()
			case <-closeNotify:
				log.Print("Closed connection by client")
				return
			}
		}
	}
}

func (s *serverImpl) handleFinishedCharges() http.HandlerFunc {
	return func(w http.ResponseWriter, req *http.Request) {
		flusher, ok := w.(http.Flusher)

		if !ok {
			http.Error(w, "SSE unsupported!", http.StatusInternalServerError)
			return
		}

		vars := mux.Vars(req)
		userId := vars["user_id"]

		setSSEHeader(w)

		closeNotify := w.(http.CloseNotifier).CloseNotify()

		subscribeChannel := "user." + userId + ".finished_charges"
		pubsub := s.redis.Subscribe(subscribeChannel)
		defer pubsub.Close()

		pubsubCh := pubsub.Channel()

		ticker := time.NewTicker(time.Duration(5) * time.Minute)
		defer ticker.Stop()
		for {
			select {
			case msg, ok := <-pubsubCh:
				if !ok {
					log.Print("Redis connection is closed")
					return
				}

				log.Printf("received: %s\n", msg.Payload)
				data := &finishedChargesPayload{}
				if err := json.Unmarshal([]byte(msg.Payload), data); err != nil {
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
			case t := <-ticker.C:
				fmt.Fprint(w, "event: ping\n")
				fmt.Fprintf(w, "data: {\"time\": \"%s\"}\n\n", t.String())
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
