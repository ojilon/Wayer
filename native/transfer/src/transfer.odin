// =============================================================================
// transfer.odin — network info + TCP listener stub for Transfer feature
//
// Part of package transfer (wayer_transfer). This is the Odin port of
// transfer_engine.cpp. Networking stays on the Java side (NetworkManager.java);
// native only provides the two small primitives Java's TransferFragment calls:
//
//   get_network_info  — returns {"transfer status":"idle","protocol":"raw_sockets"}
//   start_listener    — attempts bind() on a port, returns status JSON
//
// Why C for the socket bind?
//   * NDK's socket/bind/listen require careful error handling and must not use
//     Odin net package (which may pull in newer syscalls). The C helper
//     wayer_transfer_bind_test does the syscall directly and returns -1/-2
//     codes we translate to JSON.
//   * File transfer itself is Java sockets (TransferController.java) — native
//     only validates that a port can be bound (UI pre-check before starting
//     listener service).
//
// Future: When native handles full transfer, it will use the same C transport
// layer behind the facade (see native/transfer/MIGRATION.md).
//
// Android 10 note: Uses POSIX sockets via bionic libc (AF_INET/SOCK_STREAM),
// which are allowed; no Android-specific restriction on localhost binding.
//
// Mirrors: wayer::transfer::get_network_info, start_listener
// =============================================================================

package transfer

import "core:c"
import "core:fmt"

// ---------------------------------------------------------------------------
// C ABI — from transfer_shim.c
// ---------------------------------------------------------------------------

foreign import transfer_c "system:c"

@(default_calling_convention = "c")
foreign transfer_c {
	// Attempts socket/bind; returns 0 success, -1 socket_fail, -2 bind_fail
	wayer_transfer_bind_test :: proc(port: c.int) -> c.int ---
}

// ---------------------------------------------------------------------------
// get_network_info — static status JSON
// ---------------------------------------------------------------------------

// get_network_info returns fixed network status JSON.
// Mirrors wayer::transfer::get_network_info
get_network_info :: proc() -> string {
	return `{"transfer status":"idle","protocol":"raw_sockets"}`
}

// ---------------------------------------------------------------------------
// start_listener — TCP bind test
// ---------------------------------------------------------------------------

// start_listener attempts to bind a TCP socket on port and returns status JSON.
// Validates port range, delegates to C, translates return codes.
// Mirrors wayer::transfer::start_listener
start_listener :: proc(port: int) -> string {
	if port < 1 || port > 65535 {
		return `{"error":"invalid port"}`
	}

	result := wayer_transfer_bind_test(c.int(port))

	if result == -1 {
		return `{"error":"failed_to_create_socket"}`
	}
	if result == -2 {
		return `{"error":"bind_failed"}`
	}

	return fmt.tprintf(`{"status":"socket_bound","port":%d}`, port)
}
