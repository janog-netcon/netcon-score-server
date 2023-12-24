package main

import (
	"context"
	"net"
	"net/http"
	"time"
)

// Server is a wrapper around http.Server.
// Server is context-aware and will stop gracefully when the parent context is cancelled.
type Server struct {
	ListenAddr string
	Handler    http.Handler

	server *http.Server
}

func (s *Server) Run(ctx context.Context) error {
	var err error

	s.server = &http.Server{
		Addr:    s.ListenAddr,
		Handler: s.Handler,
	}

	s.server.BaseContext = func(_ net.Listener) context.Context {
		return ctx
	}

	waitChan := make(chan struct{})
	go func() {
		err = s.server.ListenAndServe()
		close(waitChan)
	}()

	select {
	case <-waitChan:
		// If the server is closed, we just return the error
		return err

	case <-ctx.Done():
		// If the parent context is cancelled, try to gracefully shutdown the server
		// If we call s.Server.Shutdown(), s.Server.ListenAndServe() will return ErrServerClosed.
		// So, in this case, we will ignore err returned by s.Server.ListenAndServe().
		if err := s.Shutdown(); err != nil {
			return err
		}
		return nil
	}
}

func (s *Server) Shutdown() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := s.server.Shutdown(ctx); err != nil {
		return err
	}

	return nil
}
