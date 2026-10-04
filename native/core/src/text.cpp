// wayer_core — plain-text helpers. See include/wayer/core/text.hpp.
#include <wayer/core/text.hpp>

#include <filesystem>
#include <fstream>
#include <string>
#include <system_error>

namespace wayer::core {
namespace fs = std::filesystem;

std::string ascii_lower(std::string s) {
    for (char& c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = static_cast<char>(c + ('a' - 'A'));
        }
    }
    return s;
}

bool write_text_file(const std::string& path, const std::string& content) {
    if (path.empty()) return false;
    std::error_code ec;
    const fs::path p(path);
    if (p.has_parent_path()) fs::create_directories(p.parent_path(), ec);
    ec.clear();
    std::ofstream out(path, std::ios::binary | std::ios::trunc);
    if (!out) return false;
    out << content;
    out.close();
    return static_cast<bool>(out);
}

} // namespace wayer::core
