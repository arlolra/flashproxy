package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
)

const defaultPort = 9901

// When a connection handler starts, +1 is written to this channel; when it
// ends, -1 is written.
var handlerChan = make(chan int)

func logDebug(format string, v ...interface{}) {
	fmt.Fprintf(os.Stderr, format+"\n", v...)
}

type websocketConn struct {
	Ws *websocket
	Base64 bool
	messageBuf []byte
}

func (conn *websocketConn) Read(b []byte) (n int, err error) {
	for len(conn.messageBuf) == 0 {
		var m websocketMessage
		m, err = conn.Ws.ReadMessage()
		if err != nil {
			return
		}
		if conn.Base64 {
			if m.Opcode != 1 {
				err = errors.New(fmt.Sprintf("got non-text opcode %d with the base64 subprotocol", m.Opcode))
				return
			}
			conn.messageBuf = make([]byte, base64.StdEncoding.DecodedLen(len(m.Payload)))
			var num int
			num, err = base64.StdEncoding.Decode(conn.messageBuf, m.Payload)
			if err != nil {
				return
			}
			conn.messageBuf = conn.messageBuf[:num]
		} else {
			if m.Opcode != 2 {
				err = errors.New(fmt.Sprintf("got non-binary opcode %d with no subprotocol", m.Opcode))
				return
			}
			conn.messageBuf = m.Payload
		}
	}

	n = copy(b, conn.messageBuf)
	conn.messageBuf = conn.messageBuf[n:]

	return
}

func (conn *websocketConn) Write(b []byte) (n int, err error) {
	if conn.Base64 {
		buf := make([]byte, base64.StdEncoding.EncodedLen(len(b)))
		base64.StdEncoding.Encode(buf, b)
		err = conn.Ws.WriteMessage(1, buf)
		if err != nil {
			return
		}
		n = len(b)
	} else {
		err = conn.Ws.WriteMessage(2, b)
		n = len(b)
	}
	return
}

func NewWebsocketConn(ws *websocket) websocketConn {
	var conn websocketConn
	conn.Ws = ws
	conn.Base64 = (ws.Subprotocol == "base64")
	return conn
}

func websocketHandler(ws *websocket) {
	fmt.Printf("blah\n")
}

func startListener(addr *net.TCPAddr) (*net.TCPListener, error) {
	ln, err := net.ListenTCP("tcp", addr)
	if err != nil {
		return nil, err
	}
	go func() {
		var config websocketConfig
		config.Subprotocols = []string{"base64"}
		config.MaxMessageSize = 1500
		http.Handle("/", config.Handler(websocketHandler))
		err = http.Serve(ln, nil)
		if err != nil {
			panic("http.Serve: " + err.Error())
		}
	}()
	return ln, nil
}

func main() {
	const ptMethodName = "websocket"

	ptInfo := ptServerSetup([]string{ptMethodName})

	listeners := make([]*net.TCPListener, 0)
	for _, bindAddr := range ptInfo.BindAddrs {
		// When tor tells us a port of 0, we are supposed to pick a
		// random port. But we actually want to use the configured port.
		if bindAddr.Addr.Port == 0 {
			bindAddr.Addr.Port = defaultPort
		}

		ln, err := startListener(bindAddr.Addr)
		if err != nil {
			ptSmethodError(bindAddr.MethodName, err.Error())
		}
		ptSmethod(bindAddr.MethodName, ln.Addr())
		listeners = append(listeners, ln)
	}
	ptSmethodsDone()

	var numHandlers int = 0

	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, os.Interrupt)
	var sigint bool = false
	for !sigint {
		select {
		case n := <-handlerChan:
			numHandlers += n
		case <-signalChan:
			logDebug("SIGINT")
			sigint = true
		}
	}

	for _, ln := range listeners {
		ln.Close()
	}

	sigint = false
	for numHandlers != 0 && !sigint {
		select {
		case n := <-handlerChan:
			numHandlers += n
		case <-signalChan:
			logDebug("SIGINT")
			sigint = true
		}
	}
}
