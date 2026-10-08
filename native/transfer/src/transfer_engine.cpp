// wayer_transfer — network helpers. Migrated from transfer_engine.cpp.
#include <wayer/transfer/transfer_engine.hpp>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstdint>
#include <format>
#include <string>

namespace wayer::transfer {

std::string get_network_info() {
    return R"({"transfer status": "idle", "protocol" : "raw_sockets"})";
}

std::string start_listener(int port) {
    // POSIX socket creation (SOCK_STREAM ensures TCP protocol)
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        return R"({"error": "failed_to_create_socket"})";
    }

    // Allow immediate reuse of local address/port to avoid "Address already in use" errors
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    // Setup the internet socket address structure
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY; // Bind to all available network interfaces
    address.sin_port = htons(static_cast<std::uint16_t>(port));

    auto* generic_address = reinterpret_cast<sockaddr*>(&address);

    if (bind(server_fd, generic_address, sizeof(address)) < 0) {
        close(server_fd);
        return R"({"error": "bind_failed"})";
    }

    // Close immediately for this test call; background worker threads manage persistent connections
    close(server_fd);

    return std::format(R"({{"status": "socket_bound", "port": {}}})", port);
}

} // namespace wayer::transfer
