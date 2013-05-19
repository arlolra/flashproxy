package fp

import (
  "fmt"
  "net/http"

  "appengine"
  "appengine/urlfetch"
)

const BASE = "https://fp-facilitator.org/reg/"

func ipHandler(w http.ResponseWriter, r *http.Request) {
  fmt.Fprintf(w, "%s", r.RemoteAddr)
}

func regHandler(w http.ResponseWriter, r *http.Request) {
  c := appengine.NewContext(r)
  blob := r.URL.Path[5:]
  client := urlfetch.Client(c)
  _, err := client.Get(BASE + blob)
  if err != nil {
    http.Error(w, err.Error(), http.StatusInternalServerError)
    return
  }
  fmt.Fprintf(w, "Thanks.")
}

func init() {
  http.HandleFunc("/ip", ipHandler)
  http.HandleFunc("/reg/", regHandler)
}
