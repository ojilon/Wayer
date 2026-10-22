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
	wayer_transfer_bind_test :: proc(port: c.int) -> c.int ---
}

INADDR_ANY   :: u32 
AF_INET      :: c.int
SOCK_STREAM  :: c.int
SOL_SOCKET   :: c.int
SO_REUSEADDR :: c.int
	
SockAddrIn :: struct {
	sin_family: u16,
	sin_port:   u16,
	sin_addr:   u32,
	sin_zero:   [8]byte,
}

start_listener :: proc(port: int) -> string {
	if port < 1 || port > 65535 {
		return `{"error": "invalid port"}`
	}

	result := wayer_transfer_bind_test(c.int(port))
	if result == -1 {
        return `{"error": "failed_to_create_socket"}`
    }
	
    if result == -2 {
        return `{"error": "bind_failed"}`
    }
	
    return fmt.tprintf(
        `{"status": "socket_bound", "port": %d}`,
        port,
    )
}