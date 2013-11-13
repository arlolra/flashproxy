package fp_reg

import (
	"io"
	"net"
	"net/http"
	"path"

	"appengine"
	"appengine/urlfetch"
)

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
	dir, blob := path.Split(path.Clean(r.URL.Path))
	if dir != "/reg/" {
		http.NotFound(w, r)
		return
	}
	client := urlfetch.Client(appengine.NewContext(r))
	resp, err := client.Get("https://" + FP_FACILITATOR + "/reg/" + blob)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func init() {
	http.HandleFunc("/robots.txt", robotsTxtHandler)
	http.HandleFunc("/ip", ipHandler)
	http.HandleFunc("/reg/", regHandler)
	if FP_FACILITATOR == "" {
		panic("FP_FACILITATOR empty; did you forget to edit config.go?")
	}
}
