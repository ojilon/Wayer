#include "transfer_engine.hpp"
#include <string>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h> 
#include <arpa/inet.h>
#include <format>       //  C++20: Replaces <sstream> for fast, modern string formatting
#include <cstdint>      //  Modern C++: Standard fixed-width integer types (std::uint16_t)

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
        
        //  Modern C++: Use standard std::uint16_t instead of short/uint16_t aliases
        address.sin_port = htons(static_cast<std::uint16_t>(port));

        // Modern C++: Instead of dangerous raw 'reinterpret_cast<sockaddr*>', 
        // we can take the address safely. If strict aliasing rules are a concern in C++20/23, 
        // passing through void* or standard C-compatible APIs is preferred.
        auto* generic_address = reinterpret_cast<sockaddr*>(&address);

        if (bind(server_fd, generic_address, sizeof(address)) < 0) {
            close(server_fd);
            return R"({"error": "bind_failed"})";
        }

        // Close immediately for this test call; background worker threads manage persistent connections
        close(server_fd);

        // C++20 String Formatting:
        // 1. Double curly braces '{{' and '}}' escape JSON braces so they are treated as raw text.
        // 2. The single curly brace '{}' acts as the placeholder where 'port' is safely injected.
        // 3. This operates significantly faster and uses less memory overhead than std::ostringstream.
        return std::format(R"({{"status": "socket_bound", "port": {}}})", port);
    }

}
