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
		return "", errors.New(fmt.Sprintf("reading SOCKS userid: %s", n, err))
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

var emptyAddr = net.TCPAddr{net.IPv4(0, 0, 0, 0), 0}

func SendSocks4aResponseGranted(w io.Writer, addr *net.TCPAddr) error {
	return SendSocks4aResponse(w, socksRequestGranted, addr)
}

func SendSocks4aResponseFailed(w io.Writer) error {
	return SendSocks4aResponse(w, socksRequestFailed, &emptyAddr)
}
