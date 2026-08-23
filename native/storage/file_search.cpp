#include "storage_engine.hpp"

#include <filesystem>
#include <string>
#include <vector>
#include <algorithm>
#include <format>

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

        std::string name = entry.path().filename().string();
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
