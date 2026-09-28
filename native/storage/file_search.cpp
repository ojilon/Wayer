#include <filesystem>
#include <string>
#include <vector>
#include <algorithm>
#include <format>
#include "../utils/json_util.hpp"

/**
 * Searches for files in the specified root directory matching the given query.
 * Uses std::filesystem::recursive_directory_iterator to traverse directories.
 * Performs case-insensitive matching against file names.
 * Returns exact matches (exact name match) and related matches (name contains query).
 * 
 * @param root_path The root directory path to search in.
 * @param query The search query string to match against file names.
 * @return JSON string with exact_matches and related_matches arrays.
 * 
 * Search results structure:
 * - exact_matches: files where the name exactly matches the query (case-insensitive)
 * - related_matches: files where the query is contained within the name (case-insensitive)
 * 
 * Each result contains:
 * - name: filename (JSON-escaped)
 * - path: full file path
 * - is_dir: whether the entry is a directory
 * - match_score: 100 for exact match, 50 for related match
 * 
 * STL usage:
 * - std::vector<SearchResult>: stores exact and related matches separately
 * - std::filesystem::recursive_directory_iterator: traverses all files/dirs recursively
 * - std::transform: converts query and file names to lowercase for comparison
 * - std::string::find: checks if query is contained in filename
 * - std::format: modern string formatting (C++20) for JSON output
 * 
 * Example: search_files("/storage/emulated/0", "photo") returns:
 * {"exact_matches":[{"name":"photo.jpg","path":"/storage/emulated/0/photo.jpg","is_dir":false,"match_score":100}],
 *  "related_matches":[{"name":"myphoto.png","path":"/storage/emulated/0/myphoto.png","is_dir":false,"match_score":50}]}
 */
namespace wayer::storage {
    namespace fs = std::filesystem;

    struct SearchResult {
        std::string name;
        std::string path;
        bool is_dir;
        int match_score; // 100 exact, 50 related
    };

    std::string search_files(const std::string& root_path, const std::string& query) {
        std::vector<SearchResult> exacts;
        std::vector<SearchResult> relateds;

        std::string q_lower = query;
        std::transform(q_lower.begin(), q_lower.end(), q_lower.begin(), ::tolower);

        if (q_lower.empty()) {
            return R"({"exact_matches":[],"related_matches":[]})";
        }

        std::error_code ec;
        for (const auto& entry : fs::recursive_directory_iterator(root_path, fs::directory_options::skip_permission_denied, ec)) {
            if (ec) break;

            std::string name = json::escape(entry.path().filename().string());
            std::string name_lower = name;
            std::transform(name_lower.begin(), name_lower.end(), name_lower.begin(), ::tolower);

            bool is_dir = entry.is_directory(ec);

            if (name_lower == q_lower) {
                exacts.push_back({name, entry.path().string(), is_dir, 100});
            } else if (name_lower.find(q_lower) != std::string::npos) {
                relateds.push_back({name, entry.path().string(), is_dir, 50});
            }
        }

        // Bulk JSON for Java
        std::string json = R"({"exact_matches":[)";
        for (size_t i = 0; i < exacts.size(); ++i) {
            json += std::format(
                R"({{"name":"{}","path":"{}","is_dir":{}}}{})",
                exacts[i].name,
                exacts[i].path,
                exacts[i].is_dir ? "true" : "false",
                (i + 1 < exacts.size() ? "," : ""));
        }
        json += R"(],"related_matches":[)";
        for (size_t i = 0; i < relateds.size(); ++i) {
            json += std::format(
                R"({{"name":"{}","path":"{}","is_dir":{}}}{})",
                relateds[i].name,
                relateds[i].path,
                relateds[i].is_dir ? "true" : "false",
                (i + 1 < relateds.size() ? "," : ""));
        }
        json += R"(]})";
        return json;
    }

} // namespace wayer::storage
