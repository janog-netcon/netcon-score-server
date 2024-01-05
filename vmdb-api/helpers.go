package main

import (
	"bytes"
	"encoding/json"
	"net/http"
)

func renderJSON[T any](w http.ResponseWriter, statusCode int, response T) error {
	buf := bytes.Buffer{}

	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(true)
	if err := encoder.Encode(response); err != nil {
		return err
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	w.Write(buf.Bytes())
	return nil
}
