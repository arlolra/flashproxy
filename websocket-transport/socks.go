// SOCKS4a server library.

package main

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"net"
)

const (
	socksVersion         = 0x04
	socksCmdConnect      = 0x01
	socksResponseVersion = 0x00
	socksRequestGranted  = 0x5a
	socksRequestFailed   = 0x5b
)

// Read a SOCKS4a connect request, and call the given connect callback with the
// requested destination string. If the callback returns an error, sends a SOCKS
// request failed message. Otherwise, sends a SOCKS request granted message for
// the destination address returned by the callback.
func AwaitSocks4aConnect(conn *net.TCPConn, connect func(string) (*net.TCPAddr, error)) error {
	dest, err := ReadSocks4aConnect(conn)
	if err != nil {
		SendSocks4aResponseFailed(conn)
		return err
	}
	destAddr, err := connect(dest)
	if err != nil {
		SendSocks4aResponseFailed(conn)
		return err
	}
	SendSocks4aResponseGranted(conn, destAddr)
	return nil
}

// Read a SOCKS4a connect request. Returns a "host:port" string.
func ReadSocks4aConnect(s io.Reader) (string, error) {
	r := bufio.NewReader(s)

	var h [8]byte
	n, err := io.ReadFull(r, h[:])
	if err != nil {
		return "", errors.New(fmt.Sprintf("after %d bytes of SOCKS header: %s", n, err))
	}
	if h[0] != socksVersion {
		return "", errors.New(fmt.Sprintf("SOCKS header had version 0x%02x, not 0x%02x", h[0], socksVersion))
	}
	if h[1] != socksCmdConnect {
		return "", errors.New(fmt.Sprintf("SOCKS header had command 0x%02x, not 0x%02x", h[1], socksCmdConnect))
	}

	_, err = r.ReadBytes('\x00')
	if err != nil {
		return "", errors.New(fmt.Sprintf("reading SOCKS userid: %s", err))
	}

	var port int
	var host string

	port = int(h[2])<<8 | int(h[3])<<0
	if h[4] == 0 && h[5] == 0 && h[6] == 0 && h[7] != 0 {
		hostBytes, err := r.ReadBytes('\x00')
		if err != nil {
			return "", errors.New(fmt.Sprintf("reading SOCKS4a destination: %s", err))
		}
		host = string(hostBytes[:len(hostBytes)-1])
	} else {
		host = net.IPv4(h[4], h[5], h[6], h[7]).String()
	}

	if r.Buffered() != 0 {
		return "", errors.New(fmt.Sprintf("%d bytes left after SOCKS header", r.Buffered()))
	}

	return fmt.Sprintf("%s:%d", host, port), nil
}

// Send a SOCKS4a response with the given code and address.
func SendSocks4aResponse(w io.Writer, code byte, addr *net.TCPAddr) error {
	var resp [8]byte
	resp[0] = socksResponseVersion
	resp[1] = code
	resp[2] = byte((addr.Port >> 8) & 0xff)
	resp[3] = byte((addr.Port >> 0) & 0xff)
	resp[4] = addr.IP[0]
	resp[5] = addr.IP[1]
	resp[6] = addr.IP[2]
	resp[7] = addr.IP[3]
	_, err := w.Write(resp[:])
	return err
}

var emptyAddr = net.TCPAddr{IP = net.IPv4(0, 0, 0, 0), Port = 0}

// Send a SOCKS4a response code 0x5a.
func SendSocks4aResponseGranted(w io.Writer, addr *net.TCPAddr) error {
	return SendSocks4aResponse(w, socksRequestGranted, addr)
}

// Send a SOCKS4a response code 0x5b (with an all-zero address).
func SendSocks4aResponseFailed(w io.Writer) error {
	return SendSocks4aResponse(w, socksRequestFailed, &emptyAddr)
}
