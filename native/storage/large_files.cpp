#include <cstddef>
#include <filesystem>
#include <iterator>
#include <vector>
#include <algorithm>
#include <format>
#include <sstream>
#include "../utils/json_util.hpp"

/**
 * Finds large files in the specified directory and returns them sorted by size.
 * Uses std::vector to store found entries, with emplace_back to add entries in-place.
 * Uses std::partial_sort to sort entries by size efficiently.
 * Uses std::filesystem for recursive directory traversal.
 *
 * @param root_path The root directory to search in.
 * @param min_bytes Minimum file size in bytes (default: 10 MB).
 * @param max_results Maximum number of results to return (default: 50).
 * @return JSON string with file information including name, path, and size.
 *
 * STL usage:
 * - std::vector<LargeEntry>: dynamic array to store found file entries
 * - emplace_back: constructs and inserts a new LargeEntry at the end in-place,
 *                 e.g., found.push_back({name, path, sz}) constructs the struct in-place
 * - std::partial_sort: partially sorts the vector by size (descending)
 * - std::distance: computes the number of elements in a range
 *
 * LargeEntry struct contains:
 * - name: filename (escaped for JSON)
 * - path: full file path
 * - size: file size in bytes
 *
 * Example: find_large_files("/storage/emulated/0", 1048576, 20) returns top 20 largest files
 *          larger than 1 MB.
 */
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

        for (const auto& entry : fs::recursive_directory_iterator( root_path, fs::directory_options::skip_permission_denied, ec)) {
            if (ec) break;
            if (!entry.is_regular_file(ec)) continue;

            uint64_t sz = entry.file_size(ec);
            if (ec || sz < min_bytes) continue;

            found.push_back({
                json::escape(entry.path().filename().string()),
                entry.path().string(),
                sz
            });
        }

        auto mid = found.begin() + std::min<size_t>(max_results, found.size());
        std::partial_sort(found.begin(), mid, found.end(), 
            [](const auto& a, auto &b) {return  a.size > b.size; });
        found.resize(std::distance(found.begin(), mid));

        std::sort(found.begin(), found.end(), [](const LargeEntry& a, const LargeEntry& b) {
                      return a.size > b.size;
                  });

        if (static_cast<int>(found.size()) > max_results) {
            found.resize(static_cast<size_t>(max_results));
        }

        std::ostringstream json;
        json << R"({"min_bytes":)" << min_bytes
             << R"(,"count":)" << found.size()
             << R"(,"files":[)";

        for (size_t i = 0; i < found.size(); ++i) {
            if (i) json << ',';
            json << std::format(
                R"({{"name":"{}","path":"{}","size":{}}})",
                found[i].name, found[i].path, found[i].size
            );
        }
        json << "]}";
        return json.str();
    }

}