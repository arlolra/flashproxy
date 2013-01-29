// Tor pluggable transports library.
//
// Sample client usage:
//
// PtClientSetup([]string{"foo"})
// ln, err := startSocksListener()
// if err != nil {
// 	panic(err.Error())
// }
// PtCmethod("foo", "socks4", ln.Addr())
// PtCmethodsDone()
//
// Sample server usage:
//
// info := PtServerSetup([]string{"foo", "bar"})
// for _, bindAddr := range info.BindAddrs {
// 	ln, err := startListener(bindAddr.Addr)
// 	if err != nil {
// 		panic(err.Error())
// 	}
// 	PtSmethod(bindAddr.MethodName, ln.Addr())
// }
// PtSmethodsDone()

package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
)

func getenv(key string) string {
	return os.Getenv(key)
}

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

// Print a pluggable transports protocol line to stdout. The line consists of an
// unescaped keyword, followed by any number of escaped strings.
func PtLine(keyword string, v ...string) {
	var buf bytes.Buffer
	buf.WriteString(keyword)
	for _, x := range v {
		buf.WriteString(" " + escape(x))
	}
	fmt.Println(buf.String())
}

// All of the Pt*Error functions call os.Exit(1).

// Emit an ENV-ERROR with explanation text.
func PtEnvError(msg string) {
	PtLine("ENV-ERROR", msg)
	os.Exit(1)
}

// Emit a VERSION-ERROR with explanation text.
func PtVersionError(msg string) {
	PtLine("VERSION-ERROR", msg)
	os.Exit(1)
}

// Emit a CMETHOD-ERROR with explanation text.
func PtCmethodError(methodName, msg string) {
	PtLine("CMETHOD-ERROR", methodName, msg)
	os.Exit(1)
}

// Emit an SMETHOD-ERROR with explanation text.
func PtSmethodError(methodName, msg string) {
	PtLine("SMETHOD-ERROR", methodName, msg)
	os.Exit(1)
}

// Emit a CMETHOD line. socks must be "socks4" or "socks5". Call this once for
// each listening client SOCKS port.
func PtCmethod(name string, socks string, addr net.Addr) {
	PtLine("CMETHOD", name, socks, addr.String())
}

// Emit a CMETHODS DONE line. Call this after opening all client listeners.
func PtCmethodsDone() {
	PtLine("CMETHODS", "DONE")
}

// Emit an SMETHOD line. Call this once for each listening server port.
func PtSmethod(name string, addr net.Addr) {
	PtLine("SMETHOD", name, addr.String())
}

// Emit an SMETHODS DONE line. Call this after opening all server listeners.
func PtSmethodsDone() {
	PtLine("SMETHODS", "DONE")
}

// Get a pluggable transports version offered by Tor and understood by us, if
// any. The only version we understand is "1". This function reads the
// environment variable TOR_PT_MANAGED_TRANSPORT_VER.
func getManagedTransportVer() string {
	const transportVersion = "1"
	for _, offered := range strings.Split(getenvRequired("TOR_PT_MANAGED_TRANSPORT_VER"), ",") {
		if offered == transportVersion {
			return offered
		}
	}
	return ""
}

// Get the intersection of the method names offered by Tor and those in
// methodNames. This function reads the environment variable
// TOR_PT_CLIENT_TRANSPORTS.
func getClientTransports(methodNames []string) []string {
	clientTransports := getenvRequired("TOR_PT_CLIENT_TRANSPORTS")
	if clientTransports == "*" {
		return methodNames
	}
	result := make([]string, 0)
	for _, requested := range strings.Split(clientTransports, ",") {
		for _, methodName := range methodNames {
			if requested == methodName {
				result = append(result, methodName)
				break
			}
		}
	}
	return result
}

// This structure is returned by PtClientSetup. It consists of a list of method
// names.
type PtClientInfo struct {
	MethodNames []string
}

// Check the client pluggable transports environments, emitting an error message
// and exiting the program if any error is encountered. Returns a subset of
// methodNames requested by Tor.
func PtClientSetup(methodNames []string) PtClientInfo {
	var info PtClientInfo

	ver := getManagedTransportVer()
	if ver == "" {
		PtVersionError("no-version")
	} else {
		PtLine("VERSION", ver)
	}

	info.MethodNames = getClientTransports(methodNames)
	if len(info.MethodNames) == 0 {
		PtCmethodsDone()
		os.Exit(1)
	}

	return info
}

// A combination of a method name and an address, as extracted from
// TOR_PT_SERVER_BINDADDR.
type PtBindAddr struct {
	MethodName string
	Addr       *net.TCPAddr
}

// Resolve an address string into a net.TCPAddr.
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

// Return a new slice, the members of which are those members of addrs having a
// MethodName in methodsNames.
func filterBindAddrs(addrs []PtBindAddr, methodNames []string) []PtBindAddr {
	var result []PtBindAddr

	for _, ba := range addrs {
		for _, methodName := range methodNames {
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
// further filtered by the methods in methodNames.
func getServerBindAddrs(methodNames []string) []PtBindAddr {
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
	result = filterBindAddrs(result, methodNames)

	return result
}

// Reads and validates the contents of an auth cookie file. Returns the 32-byte
// cookie. See section 4.2.1.2 of pt-spec.txt.
func readAuthCookieFile(filename string) ([]byte, error) {
	authCookieHeader := []byte("! Extended ORPort Auth Cookie !\x0a")
	header := make([]byte, 32)
	cookie := make([]byte, 32)

	f, err := os.Open(filename)
	if err != nil {
		return cookie, err
	}
	defer f.Close()

	n, err := io.ReadFull(f, header)
	if err != nil {
		return cookie, err
	}
	n, err = io.ReadFull(f, cookie)
	if err != nil {
		return cookie, err
	}
	// Check that the file ends here.
	n, err = f.Read(make([]byte, 1))
	if n != 0 {
		return cookie, errors.New(fmt.Sprintf("file is longer than 64 bytes"))
	} else if err != io.EOF {
		return cookie, errors.New(fmt.Sprintf("did not find EOF at end of file"))
	}

	if !bytes.Equal(header, authCookieHeader) {
		return cookie, errors.New(fmt.Sprintf("missing auth cookie header"))
	}

	return cookie, nil
}

// This structure is returned by PtServerSetup. It consists of a list of
// PtBindAddrs, along with a single address for the ORPort.
type PtServerInfo struct {
	BindAddrs      []PtBindAddr
	OrAddr         *net.TCPAddr
	ExtendedOrAddr *net.TCPAddr
	AuthCookie     []byte
}

// Check the server pluggable transports environments, emitting an error message
// and exiting the program if any error is encountered. Resolves the various
// requested bind addresses and the server ORPort. Returns a PtServerInfo
// struct.
func PtServerSetup(methodNames []string) PtServerInfo {
	var info PtServerInfo
	var err error

	ver := getManagedTransportVer()
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

	info.BindAddrs = getServerBindAddrs(methodNames)
	if len(info.BindAddrs) == 0 {
		PtSmethodsDone()
		os.Exit(1)
	}

	var extendedOrPort = getenv("TOR_PT_EXTENDED_SERVER_PORT")
	if extendedOrPort != "" {
		info.ExtendedOrAddr, err = net.ResolveTCPAddr("tcp", extendedOrPort)
		if err != nil {
			PtEnvError(fmt.Sprintf("cannot resolve TOR_PT_EXTENDED_SERVER_PORT %q: %s", extendedOrPort, err.Error()))
		}
	}

	var authCookieFilename = getenv("TOR_PT_AUTH_COOKIE_FILE")
	if authCookieFilename != "" {
		info.AuthCookie, err = readAuthCookieFile(authCookieFilename)
		if err != nil {
			PtEnvError(fmt.Sprintf("error reading TOR_PT_AUTH_COOKIE_FILE %q: %s", authCookieFilename, err.Error()))
		}
	}

	return info
}

// Connect to info.ExtendedOrAddr if defined, or else info.OrAddr, and return an
// open *net.TCPConn. If connecting to the extended OR port, extended OR port
// authentication à la 217-ext-orport-auth.txt is done before returning; an
// error is returned if authentication fails.
func PtConnectOr(info *PtServerInfo, conn net.Conn) (*net.TCPConn, error) {
	return net.DialTCP("tcp", nil, ptInfo.OrAddr)
}
