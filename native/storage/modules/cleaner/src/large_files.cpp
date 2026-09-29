// wayer_storage_cleaner — top-N largest files under a root.
#include <wayer/storage/cleaner.hpp>

#include <wayer/core/json_util.hpp>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <format>
#include <sstream>
#include <string>
#include <system_error>
#include <vector>

namespace wayer::storage {
namespace fs = std::filesystem;

struct LargeEntry {
    std::string name;
    std::string path;
    uint64_t size;
};

std::string find_large_files(const std::string& root_path, uint64_t min_bytes, int max_results) {
    if (max_results <= 0) max_results = 50;
    if (min_bytes == 0) min_bytes = 10ull * 1024 * 1024; // 10 MB default

    std::vector<LargeEntry> found;
    std::error_code ec;

    for (const auto& entry : fs::recursive_directory_iterator(
             root_path, fs::directory_options::skip_permission_denied, ec)) {
        if (ec) break;
        if (!entry.is_regular_file(ec) || ec) continue;

        uint64_t sz = entry.file_size(ec);
        if (ec || sz < min_bytes) continue;

        found.push_back({
            entry.path().filename().string(),
            entry.path().string(),
            sz,
        });
    }

    const auto want = std::min<size_t>(static_cast<size_t>(max_results), found.size());
    std::partial_sort(found.begin(), found.begin() + static_cast<std::ptrdiff_t>(want), found.end(),
                      [](const LargeEntry& a, const LargeEntry& b) { return a.size > b.size; });
    found.resize(want);

    std::ostringstream json;
    json << R"({"min_bytes":)" << min_bytes
         << R"(,"count":)" << found.size()
         << R"(,"files":[)";

    for (size_t i = 0; i < found.size(); ++i) {
        if (i) json << ',';
        json << std::format(
            R"({{"name":"{}","path":"{}","size":{}}})",
            core::json::escape(found[i].name),
            core::json::escape(found[i].path),
            found[i].size);
    }
    json << "]}";
    return json.str();
}

} // namespace wayer::storage
