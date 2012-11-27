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
		PtEnvError(fmt.Sprintf("no %s environment variable", key))
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

func PtLine(keyword string, v ...string) {
	var buf bytes.Buffer
	buf.WriteString(keyword)
	for _, x := range v {
		buf.WriteString(" " + escape(x))
	}
	fmt.Println(buf.String())
}

func PtEnvError(msg string) {
	PtLine("ENV-ERROR", msg)
	os.Exit(1)
}

func PtVersionError(msg string) {
	PtLine("VERSION-ERROR", msg)
	os.Exit(1)
}

func PtCmethodError(methodName, msg string) {
	PtLine("CMETHOD-ERROR", methodName, msg)
	os.Exit(1)
}

func PtGetManagedTransportVer() string {
	const transportVersion = "1"
	for _, offered := range strings.Split(getenvRequired("TOR_PT_MANAGED_TRANSPORT_VER"), ",") {
		if offered == transportVersion {
			return offered
		}
	}
	return ""
}

func PtGetClientTransports(supported []string) []string {
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

func PtCmethod(name string, socks string, addr net.Addr) {
	PtLine("CMETHOD", name, socks, addr.String())
}

func PtCmethodsDone() {
	PtLine("CMETHODS", "DONE")
}

func PtClientSetup(methodNames []string) []string {
	ver := PtGetManagedTransportVer()
	if ver == "" {
		PtVersionError("no-version")
	} else {
		PtLine("VERSION", ver)
	}

	methods := PtGetClientTransports(methodNames)
	if len(methods) == 0 {
		PtCmethodsDone()
		os.Exit(1)
	}

	return methods
}

func PtSmethodError(methodName, msg string) {
	PtLine("SMETHOD-ERROR", methodName, msg)
	os.Exit(1)
}

func PtSmethod(name string, addr net.Addr) {
	PtLine("SMETHOD", name, addr.String())
}

func PtSmethodsDone() {
	PtLine("SMETHODS", "DONE")
}

func resolveBindAddr(bindAddr string) (*net.TCPAddr, error) {
	addr, err := net.ResolveTCPAddr("tcp", bindAddr)
	if err == nil {
		return addr, nil
	}
	// Before the fixing of bug #7011, tor doesn't put brackets around IPv6
	// addresses. Split after the last colon, assuming it is a port
	// separator, and try adding the brackets.
	parts := strings.Split(bindAddr, ":")
	if len(parts) <= 2 {
		return nil, err
	}
	bindAddr = "[" + strings.Join(parts[:len(parts)-1], ":") + "]:" + parts[len(parts)-1]
	return net.ResolveTCPAddr("tcp", bindAddr)
}

type PtBindAddr struct {
	MethodName string
	Addr       *net.TCPAddr
}

func filterBindAddrs(addrs []PtBindAddr, supported []string) []PtBindAddr {
	var result []PtBindAddr

	for _, ba := range addrs {
		for _, methodName := range supported {
			if ba.MethodName == methodName {
				result = append(result, ba)
				break
			}
		}
	}

	return result
}

// Return a map from method names to bind addresses. The map is the contents of
// TOR_PT_SERVER_BINDADDR, with keys filtered by TOR_PT_SERVER_TRANSPORTS, and
// further filtered by methods that we know.
func PtGetServerBindAddrs(supported []string) []PtBindAddr {
	var result []PtBindAddr

	// Get the list of all requested bindaddrs.
	var serverBindAddr = getenvRequired("TOR_PT_SERVER_BINDADDR")
	for _, spec := range strings.Split(serverBindAddr, ",") {
		var bindAddr PtBindAddr

		parts := strings.SplitN(spec, "-", 2)
		if len(parts) != 2 {
			PtEnvError(fmt.Sprintf("TOR_PT_SERVER_BINDADDR: %q: doesn't contain \"-\"", spec))
		}
		bindAddr.MethodName = parts[0]
		addr, err := resolveBindAddr(parts[1])
		if err != nil {
			PtEnvError(fmt.Sprintf("TOR_PT_SERVER_BINDADDR: %q: %s", spec, err.Error()))
		}
		bindAddr.Addr = addr
		result = append(result, bindAddr)
	}

	// Filter by TOR_PT_SERVER_TRANSPORTS.
	serverTransports := getenvRequired("TOR_PT_SERVER_TRANSPORTS")
	if serverTransports != "*" {
		result = filterBindAddrs(result, strings.Split(serverTransports, ","))
	}

	// Finally filter by what we understand.
	result = filterBindAddrs(result, supported)

	return result
}

type PtServerInfo struct {
	BindAddrs []PtBindAddr
	OrAddr    *net.TCPAddr
}

func PtServerSetup(methodNames []string) PtServerInfo {
	var info PtServerInfo
	var err error

	ver := PtGetManagedTransportVer()
	if ver == "" {
		PtVersionError("no-version")
	} else {
		PtLine("VERSION", ver)
	}

	var orPort = getenvRequired("TOR_PT_ORPORT")
	info.OrAddr, err = net.ResolveTCPAddr("tcp", orPort)
	if err != nil {
		PtEnvError(fmt.Sprintf("cannot resolve TOR_PT_ORPORT %q: %s", orPort, err.Error()))
	}

	info.BindAddrs = PtGetServerBindAddrs(methodNames)
	if len(info.BindAddrs) == 0 {
		PtSmethodsDone()
		os.Exit(1)
	}

	return info
}
