// wayer_core — plain-text helpers. See include/wayer/core/text.hpp.
#include <wayer/core/text.hpp>

#include <string>

namespace wayer::core {

std::string ascii_lower(std::string s) {
    for (char& c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = static_cast<char>(c + ('a' - 'A'));
        }
    }
    return s;
}

} // namespace wayer::core
