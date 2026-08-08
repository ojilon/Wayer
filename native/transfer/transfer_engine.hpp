#pragma once
#include <string>

namespace wayer::transfer {
    std::string get_network_info();
    std::string start_listener(int port);
}