package main

import (
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
