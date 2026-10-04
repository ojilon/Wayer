// wayer_storage_search — case-insensitive file-name search.
#include <wayer/storage/search.hpp>

#include <wayer/core/json_util.hpp>
#include <wayer/core/text.hpp>

#include <filesystem>
#include <format>
#include <string>
#include <system_error>
#include <vector>

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

    const std::string q_lower = core::ascii_lower(query);
    if (q_lower.empty()) {
        return R"({"exact_matches":[],"related_matches":[]})";
    }

    std::error_code ec;
    for (const auto& entry :
         fs::recursive_directory_iterator(root_path, fs::directory_options::skip_permission_denied, ec)) {
        if (ec) break;

        std::string raw_name = entry.path().filename().string();
        std::string name_lower = core::ascii_lower(raw_name);
        bool is_dir = entry.is_directory(ec);
        if (ec) continue;

        if (name_lower == q_lower) {
            exacts.push_back({raw_name, entry.path().string(), is_dir, 100});
        } else if (name_lower.find(q_lower) != std::string::npos) {
            relateds.push_back({raw_name, entry.path().string(), is_dir, 50});
        }
    }

    // Bulk JSON for Java (escape at output time, not before matching).
    std::string json = R"({"exact_matches":[)";
    for (size_t i = 0; i < exacts.size(); ++i) {
        json += std::format(
            R"({{"name":"{}","path":"{}","is_dir":{}}}{})",
            core::json::escape(exacts[i].name),
            core::json::escape(exacts[i].path),
            exacts[i].is_dir ? "true" : "false",
            (i + 1 < exacts.size() ? "," : ""));
    }
    json += R"(],"related_matches":[)";
    for (size_t i = 0; i < relateds.size(); ++i) {
        json += std::format(
            R"({{"name":"{}","path":"{}","is_dir":{}}}{})",
            core::json::escape(relateds[i].name),
            core::json::escape(relateds[i].path),
            relateds[i].is_dir ? "true" : "false",
            (i + 1 < relateds.size() ? "," : ""));
    }
    json += R"(]})";
    return json;
}

} // namespace wayer::storage
