package main

import (
	"bytes"
	"fmt"
	"net"
	"os"
	"strings"
)

// Abort with an ENV-ERROR if the environment variable isn't set.
func getenvRequired(key string) string {
	value := os.Getenv(key)
	if value == "" {
		ptEnvError(fmt.Sprintf("no %s environment variable", key))
	}
	return value
}

// Escape a string so it contains no byte values over 127 and doesn't contain
// any of the characters '\x00', '\n', or '\\'.
func escape(s string) string {
	var buf bytes.Buffer
	for _, b := range []byte(s) {
		if b == '\n' {
			buf.WriteString("\\n")
		} else if b == '\\' {
			buf.WriteString("\\\\")
		} else if 0 < b && b < 128 {
			buf.WriteByte(b)
		} else {
			fmt.Fprintf(&buf, "\\x%02x", b)
		}
	}
	return buf.String()
}

func ptLine(keyword string, v ...string) {
	var buf bytes.Buffer
	buf.WriteString(keyword)
	for _, x := range v {
		buf.WriteString(" " + escape(x))
	}
	fmt.Println(buf.String())
}

func ptEnvError(msg string) {
	ptLine("ENV-ERROR", msg)
	os.Exit(1)
}

func ptVersionError(msg string) {
	ptLine("VERSION-ERROR", msg)
	os.Exit(1)
}

func ptCmethodError(methodName, msg string) {
	ptLine("CMETHOD-ERROR", methodName, msg)
	os.Exit(1)
}

func ptGetManagedTransportVer() string {
	const transportVersion = "1"
	for _, offered := range strings.Split(getenvRequired("TOR_PT_MANAGED_TRANSPORT_VER"), ",") {
		if offered == transportVersion {
			return offered
		}
	}
	return ""
}

func ptGetClientTransports(supported []string) []string {
	clientTransports := getenvRequired("TOR_PT_CLIENT_TRANSPORTS")
	if clientTransports == "*" {
		return supported
	}
	result := make([]string, 0)
	for _, requested := range strings.Split(clientTransports, ",") {
		for _, methodName := range supported {
			if requested == methodName {
				result = append(result, methodName)
				break
			}
		}
	}
	return result
}

func ptCmethod(name string, socks string, addr net.Addr) {
	ptLine("CMETHOD", name, socks, addr.String())
}

func ptCmethodsDone() {
	ptLine("CMETHODS", "DONE")
}

func ptClientSetup(methodNames []string) []string {
	ver := ptGetManagedTransportVer()
	if ver == "" {
		ptVersionError("no-version")
	} else {
		ptLine("VERSION", ver)
	}

	methods := ptGetClientTransports(methodNames)
	if len(methods) == 0 {
		ptCmethodsDone()
		os.Exit(1)
	}

	return methods
}
