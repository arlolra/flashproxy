package main

import (
	"code.google.com/p/go.net/websocket"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"time"
)

const socksTimeout = 2

func logDebug(format string, v ...interface{}) {
	fmt.Fprintf(os.Stderr, format+"\n", v...)
}

func proxy(local *net.TCPConn, ws *websocket.Conn) error {
	// Local-to-WebSocket read loop.
	go func() {
		n, err := io.Copy(ws, local)
		logDebug("end local-to-WebSocket %d %s", n, err)
	}()

	// WebSocket-to-local read loop.
	go func() {
		n, err := io.Copy(local, ws)
		logDebug("end WebSocket-to-local %d %s", n, err)
	}()

	select {}
	return nil
}

func handleConnection(conn *net.TCPConn) error {
	defer conn.Close()

	conn.SetDeadline(time.Now().Add(socksTimeout * time.Second))
	dest, err := readSocks4aConnect(conn)
	if err != nil {
		sendSocks4aResponseFailed(conn)
		return err
	}
	// Disable deadline.
	conn.SetDeadline(time.Time{})
	logDebug("SOCKS request for %s", dest)

	// We need the parsed IP and port for the SOCKS reply.
	destAddr, err := net.ResolveTCPAddr("tcp", dest)
	if err != nil {
		sendSocks4aResponseFailed(conn)
		return err
	}

	wsUrl := url.URL{Scheme: "ws", Host: dest}
	ws, err := websocket.Dial(wsUrl.String(), "", wsUrl.String())
	if err != nil {
		sendSocks4aResponseFailed(conn)
		return err
	}
	defer ws.Close()
	logDebug("WebSocket connection to %s", ws.Config().Location.String())

	sendSocks4aResponseGranted(conn, destAddr)

	return proxy(conn, ws)
}

func socksAcceptLoop(ln *net.TCPListener) error {
	for {
		socks, err := ln.AcceptTCP()
		if err != nil {
			return err
		}
		go func() {
			err := handleConnection(socks)
			if err != nil {
				logDebug("SOCKS from %s: %s", socks.RemoteAddr(), err)
			}
		}()
	}
	return nil
}

func startListener(addrStr string) (*net.TCPListener, error) {
	addr, err := net.ResolveTCPAddr("tcp", addrStr)
	if err != nil {
		return nil, err
	}
	ln, err := net.ListenTCP("tcp", addr)
	if err != nil {
		return nil, err
	}
	go func() {
		err := socksAcceptLoop(ln)
		if err != nil {
			logDebug("accept: %s", err)
		}
	}()
	return ln, nil
}

func main() {
	const ptMethodName = "websocket"
	var socksAddrStrs = [...]string{"127.0.0.1:0", "[::1]:0"}

	ptClientSetup([]string{ptMethodName})

	for _, socksAddrStr := range socksAddrStrs {
		ln, err := startListener(socksAddrStr)
		if err != nil {
			ptCmethodError(ptMethodName, err.Error())
		}
		ptCmethod(ptMethodName, "socks4", ln.Addr())
	}
	ptCmethodsDone()

	select {}
}
