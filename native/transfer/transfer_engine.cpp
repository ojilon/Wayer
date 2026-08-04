#include "transfer_engine.hpp"
#include <string>

namespace wayer::transfer {
    std::string get_network_info() {
        return R"({"transfer status": "idle", "protocol" : "raw_sockets"})";
    }

}