package fp_reg

import (
	"net"
	"net/http"

	"appengine"
	"appengine/urlfetch"
)

const BASE = "https://fp-facilitator.org/reg/"

func robotsTxtHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Write([]byte("User-agent: *\nDisallow:\n"))
}

func ipHandler(w http.ResponseWriter, r *http.Request) {
	remoteAddr := r.RemoteAddr
	if net.ParseIP(remoteAddr).To4() == nil {
		remoteAddr = "[" + remoteAddr + "]"
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Write([]byte(remoteAddr))
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
	w.Write([]byte("Thanks."))
}

func init() {
	http.HandleFunc("/robots.txt", robotsTxtHandler)
	http.HandleFunc("/ip", ipHandler)
	http.HandleFunc("/reg/", regHandler)
}
