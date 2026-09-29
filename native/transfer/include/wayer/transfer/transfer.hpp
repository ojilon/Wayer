#pragma once
// Public facade for transfer module.
// Legacy: transfer_engine.hpp / .cpp
// Sockets/hotspot orchestration may remain Java (NetworkManager); native for framing/hash/helpers.

namespace wayer::transfer {
int transfer_module_anchor();
// get_network_info, start_listener, ...
}
