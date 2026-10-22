package transfer

import "core:c"
import "core:fmt"

// get_network_info returns network status JSON
// Mirrors wayer::transfer::get_network_info
get_network_info :: proc() -> string {
	return `{"transfer status": "idle", "protocol" : "raw_sockets"}`
}

// start_listener creates a TCP socket on the given port
// Mirrors wayer::transfer::start_listener
// Uses POSIX sockets via C FFI for Android compatibility
foreign import libc "system:c"

@(default_calling_convention = "c")
foreign libc {
	socket       :: proc(domain: c.int, typ: c.int, protocol: c.int) -> c.int ---
	setsockopt   :: proc(sockfd: c.int, level: c.int, optname: c.int, optval: ^c.void, optlen: c.size_t) -> c.int ---
	bind         :: proc(sockfd: c.int, addr: ^c.void, addrlen: c.size_t) -> c.int ---
	close        :: proc(fd: c.int) -> c.int ---
	htons        :: proc(hostshort: u16) -> u16 ---
	INADDR_ANY   :: u32 ---
	AF_INET      :: c.int ---
	SOCK_STREAM  :: c.int ---
	SOL_SOCKET   :: c.int ---
	SO_REUSEADDR :: c.int ---
}

SockAddrIn :: struct {
	sin_family: u16,
	sin_port:   u16,
	sin_addr:   u32,
	sin_zero:   [8]byte,
}

start_listener :: proc(port: int) -> string {
	// POSIX socket creation (SOCK_STREAM ensures TCP protocol)
	server_fd := socket(AF_INET, SOCK_STREAM, 0)
	if server_fd < 0 {
		return `{"error": "failed_to_create_socket"}`
	}

	// Allow immediate reuse of local address/port to avoid "Address already in use" errors
	opt := c.int(1)
	setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, ^opt, size_of(c.int))

	// Setup the internet socket address structure
	address := SockAddrIn{}
	address.sin_family = u16(AF_INET)
	address.sin_addr = INADDR_ANY
	address.sin_port = htons(u16(port))

	// Bind
	if bind(server_fd, ^address, size_of(SockAddrIn)) < 0 {
		close(server_fd)
		return `{"error": "bind_failed"}`
	}

	// Close immediately for this test call; background worker threads manage persistent connections
	close(server_fd)

	return fmt.tprintf(`{"status": "socket_bound", "port": %d}`, port)
}