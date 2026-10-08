#pragma once
// Public facade for transfer module.
// Sockets/hotspot orchestration may remain Java (NetworkManager); native for framing/hash/helpers.
#include <wayer/transfer/transfer_engine.hpp>

namespace wayer::transfer {
int transfer_module_anchor();
}
