#include "storage_engine.hpp"

#include <sstream>
#include <string>
#include <filesystem>
#include <sys/statvfs.h>
#include <cstdint>
#include <format>
#include <vector>
#include <algorithm>
#include <unordered_map>

namespace wayer::storage {
    namespace fs = std::filesystem;

    //extension map
    const std::unordered_map<std::string_view, std::string_view> EXTENSION_MAP = {
        {".jpg", "images"}, {".jpeg", "images"}, {".png", "images"}, {".webp", "images"},
        {".mp4", "videos"}, {".mkv", "videos"},   {".avi", "videos"}, {".webm", "videos"},
        {".mp3", "audio"},  {".wav", "audio"},    {".flac", "audio"}, {".m4a", "audio"},
        {".pdf", "documents"}, {".txt", "documents"}, {".docx", "documents"}, {".doc", "documents"},
        {".apk", "foreign"}, {".obb", "foreign"}
    };

    //Hardcoded retail sizes in bytes
    // 64GB = 64'000'000'000 bytes
    constexpr uint64_t RETAIL_64GB = 64ULL * 1000ULL * 1000ULL * 1000ULL;

    std::string list_files(std::string_view path) {
        std::error_code ec;
        fs::path dir_path(path);

        if (!fs::exists(dir_path, ec) || !fs::is_directory(dir_path, ec)) {
            return R"({"error":"invalid_directory"})";
        }

        std::ostringstream json;
        json << R"({"files": [)";
        bool first = true;

        for (const auto& entry : fs::directory_iterator(dir_path, ec)) {
            if (!first) json << ",";
            json << "\"" << entry.path().filename().string() << "\"";
            first = false;
        }

        json << "]}";
        return json.str();
    }

    std::string get_storage_stats(const std::string& root_path) {

        struct statvfs stat {};
        if (statvfs(root_path.c_str(), &stat) != 0) {
            return R"({"error": "Failed to read storage statistics"})";
        }

        //partition metrics from the OS
        uint64_t partition_total = static_cast<uint64_t>(stat.f_blocks) * stat.f_frsize;
        uint64_t free_bytes = static_cast<uint64_t>(stat.f_bavail) * stat.f_frsize;
        uint64_t partition_used = partition_total - free_bytes;

        uint64_t total_bytes = (partition_total > RETAIL_64GB) ? partition_total : RETAIL_64GB;
        uint64_t system_bytes = (total_bytes > partition_total) ? (total_bytes - partition_total) : 0;
        uint64_t used_bytes = partition_used + system_bytes;

        int progress_percent = total_bytes > 0 ? static_cast<int>((used_bytes * 100) / total_bytes) : 0;

        std::unordered_map<std::string, uint64_t> categories = {
            {"images", 0}, {"videos", 0}, {"audio", 0}, {"foreign", 0}, {"others", 0}
        };

        std::error_code ec;
        for (const auto& entry : fs::recursive_directory_iterator(
                 root_path, fs::directory_options::skip_permission_denied, ec)) {
            if (ec) break;
            if (entry.is_regular_file(ec)) {
                auto ext = entry.path().extension().string();
                std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);

                uint64_t sz = entry.file_size(ec);
                if (ec) continue;

                if (auto it = EXTENSION_MAP.find(ext); it != EXTENSION_MAP.end()) {
                    categories[std::string(it -> second)] += sz;
                } else {
                    categories["others"] += sz;
                }
            }
        }

        return std::format(
            R"({{)"
            R"("total_bytes":{},"used_bytes":{},"free_bytes":{},"progress_percent":{},)"
            R"("breakdown":{{"images":{},"videos":{},"audio":{},"documents":{},"foreign":{},"system":{},"others":{}}})"
            R"(}})",
            total_bytes, used_bytes, free_bytes, progress_percent,
            categories["images"], categories["videos"], categories["audio"], 
            categories["documents"], categories["foreign"], system_bytes, categories["others"]
        );
    }

struct LargeEntry {
    std::string name;
    std::string path;
    uint64_t size;
};

std::string find_large_files(const std::string& root_path,
                             uint64_t min_bytes,
                             int max_results) {
    if (max_results <= 0) max_results = 50;
    if (min_bytes == 0) min_bytes = 10ull * 1024 * 1024; // 10 MB default

    std::vector<LargeEntry> found;
    std::error_code ec;

    for (const auto& entry : fs::recursive_directory_iterator(
             root_path, fs::directory_options::skip_permission_denied, ec)) {
        if (ec) break;
        if (!entry.is_regular_file(ec)) continue;

        uint64_t sz = entry.file_size(ec);
        if (ec || sz < min_bytes) continue;

        found.push_back({
            entry.path().filename().string(),
            entry.path().string(),
            sz
        });
    }

    std::sort(found.begin(), found.end(),
              [](const LargeEntry& a, const LargeEntry& b) {
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

} // namespace wayer::storage
