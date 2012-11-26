package main

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
	"net"
	"net/http"
	"strings"
)

type websocketConfig struct {
	Subprotocols []string
}

type websocket struct {
	Conn        net.Conn
	Bufrw       *bufio.ReadWriter
	// Whether we are a client or a server implications for masking.
	IsClient    bool
	Subprotocol string
}

func commaSplit(s string) []string {
	var result []string
	if strings.TrimSpace(s) == "" {
		return result
	}
	for _, e := range strings.Split(s, ",") {
		result = append(result, strings.TrimSpace(e))
	}
	return result
}

func containsCase(haystack []string, needle string) bool {
	for _, e := range haystack {
		if strings.ToLower(e) == strings.ToLower(needle) {
			return true
		}
	}
	return false
}

func sha1Hash(data string) []byte {
	h := sha1.New()
	h.Write([]byte(data))
	return h.Sum(nil)
}

func httpError(w http.ResponseWriter, bufrw *bufio.ReadWriter, code int) {
	w.Header().Set("Connection", "close")
	bufrw.WriteString(fmt.Sprintf("HTTP/1.0 %d %s\r\n", code, http.StatusText(code)))
	w.Header().Write(bufrw)
	bufrw.WriteString("\r\n")
	bufrw.Flush()
}

type WebSocketHTTPHandler struct {
	config            *websocketConfig
	websocketCallback func(*websocket)
}

func (handler *WebSocketHTTPHandler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	conn, bufrw, err := w.(http.Hijacker).Hijack()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer conn.Close()

	// See RFC 6455 section 4.2.1 for this sequence of checks.

	// 1. An HTTP/1.1 or higher GET request, including a "Request-URI"...
	if req.Method != "GET" {
		httpError(w, bufrw, http.StatusMethodNotAllowed)
		return
	}
	if req.URL.Path != "/" {
		httpError(w, bufrw, http.StatusNotFound)
		return
	}
	// 2. A |Host| header field containing the server's authority.
	// We deliberately skip this test.
	// 3. An |Upgrade| header field containing the value "websocket",
	// treated as an ASCII case-insensitive value.
	if !containsCase(commaSplit(req.Header.Get("Upgrade")), "websocket") {
		httpError(w, bufrw, http.StatusBadRequest)
		return
	}
	// 4. A |Connection| header field that includes the token "Upgrade",
	// treated as an ASCII case-insensitive value.
	if !containsCase(commaSplit(req.Header.Get("Connection")), "Upgrade") {
		httpError(w, bufrw, http.StatusBadRequest)
		return
	}
	// 5. A |Sec-WebSocket-Key| header field with a base64-encoded value
	// that, when decoded, is 16 bytes in length.
	websocketKey := req.Header.Get("Sec-WebSocket-Key")
	key, err := base64.StdEncoding.DecodeString(websocketKey)
	if err != nil || len(key) != 16 {
		httpError(w, bufrw, http.StatusBadRequest)
		return
	}
	// 6. A |Sec-WebSocket-Version| header field, with a value of 13.
	// We also allow 8 from draft-ietf-hybi-thewebsocketprotocol-10.
	var knownVersions = []string{"8", "13"}
	websocketVersion := req.Header.Get("Sec-WebSocket-Version")
	if !containsCase(knownVersions, websocketVersion) {
		// "If this version does not match a version understood by the
		// server, the server MUST abort the WebSocket handshake
		// described in this section and instead send an appropriate
		// HTTP error code (such as 426 Upgrade Required) and a
		// |Sec-WebSocket-Version| header field indicating the
		// version(s) the server is capable of understanding."
		w.Header().Set("Sec-WebSocket-Version", strings.Join(knownVersions, ", "))
		httpError(w, bufrw, 426)
		return
	}
	// 7. Optionally, an |Origin| header field.
	// 8. Optionally, a |Sec-WebSocket-Protocol| header field, with a list of
	// values indicating which protocols the client would like to speak, ordered
	// by preference.
	clientProtocols := commaSplit(req.Header.Get("Sec-WebSocket-Protocol"))
	// 9. Optionally, a |Sec-WebSocket-Extensions| header field...
	// 10. Optionally, other header fields...

	var ws websocket
	ws.Conn = conn
	ws.Bufrw = bufrw
	ws.IsClient = false

	// See RFC 6455 section 4.2.2, item 5 for these steps.

	// 1. A Status-Line with a 101 response code as per RFC 2616.
	bufrw.WriteString(fmt.Sprintf("HTTP/1.0 %d %s\r\n", http.StatusSwitchingProtocols, http.StatusText(http.StatusSwitchingProtocols)))
	// 2. An |Upgrade| header field with value "websocket" as per RFC 2616.
	w.Header().Set("Upgrade", "websocket")
	// 3. A |Connection| header field with value "Upgrade".
	w.Header().Set("Connection", "Upgrade")
	// 4. A |Sec-WebSocket-Accept| header field.  The value of this header
	// field is constructed by concatenating /key/, defined above in step 4
	// in Section 4.2.2, with the string
	// "258EAFA5-E914-47DA-95CA-C5AB0DC85B11", taking the SHA-1 hash of this
	// concatenated value to obtain a 20-byte value and base64-encoding (see
	// Section 4 of [RFC4648]) this 20-byte hash.
	const magicGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	acceptKey := base64.StdEncoding.EncodeToString(sha1Hash(websocketKey + magicGUID))
	w.Header().Set("Sec-WebSocket-Accept", acceptKey)
	// 5.  Optionally, a |Sec-WebSocket-Protocol| header field, with a value
	// /subprotocol/ as defined in step 4 in Section 4.2.2.
	for _, clientProto := range clientProtocols {
		for _, serverProto := range handler.config.Subprotocols {
			if clientProto == serverProto {
				ws.Subprotocol = clientProto
				w.Header().Set("Sec-WebSocket-Protocol", clientProto)
				break
			}
		}
	}
	// 6.  Optionally, a |Sec-WebSocket-Extensions| header field...
	w.Header().Write(bufrw)
	bufrw.WriteString("\r\n")
	bufrw.Flush()

	// Call the WebSocket-specific handler.
	handler.websocketCallback(&ws)
}

func (config *websocketConfig) Handler(f func(*websocket)) http.Handler {
	return &WebSocketHTTPHandler{config, f}
}
