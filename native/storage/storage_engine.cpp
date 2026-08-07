#include "storage_engine.hpp"
#include <sstream>
#include <string>
#include <filesystem>
#include <sys/statvfs.h> //for statvfs
#include <cstdint> // for unint64_t
#include <format> // for std::format

namespace wayer::storage {
    namespace fs = std::filesystem;

    std::string list_files(std::string_view path) {
        std::error_code ec;
        fs::path dir_path(path);

        if(!fs::exists(dir_path, ec) || !fs::is_directory(dir_path, ec)) {
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
        struct statvfs stat;
        if (statvfs(root_path.c_str(), &stat) != 0) {
            return R"({"error": "Failed to read storage statistics"})";
        }

        uint64_t total_bytes = static_cast<uint64_t>(stat.f_blocks) * stat.f_frsize;
        uint64_t free_bytes = static_cast<uint64_t>(stat.f_bavail) * stat.f_frsize;
        uint64_t used_bytes = total_bytes - free_bytes;
        int progress_percent = static_cast<int>((used_bytes * 100) / total_bytes);

        // Default counters for category breakdown (in bytes)
        uint64_t images_size = 0, video_size = 0, audio_size = 0, docs_size = 0, other_size = 0;

        std::error_code ec;
        for (const auto& entry : fs::recursive_directory_iterator(root_path, fs::directory_options::skip_permission_denied, ec)) {
            if (ec) break;
            if (entry.is_regular_file(ec)) {
                auto ext = entry.path().extension().string();
                uint64_t sz = entry.file_size(ec);

                if (ext == ".jpg" || ext == ".png" || ext == ".webp") images_size += sz;
                else if (ext == ".mp4" || ext == ".mkv" || ext == ".avi") video_size += sz;
                else if (ext == ".mp3" || ext == ".wav" || ext == ".flac") audio_size += sz;
                else if (ext == ".pdf" || ext == ".txt" || ext == ".docx") docs_size += sz;
                else other_size += sz;
            }
        }

        // Build unified large JSON string
        return std::format(
            R"({{)"
            R"("total_bytes":{},"used_bytes":{},"free_bytes":{},"progress_percent":{},)"
            R"("breakdown":{{"images":{},"videos":{},"audio":{},"documents":{},"others":{}}})"
            R"(}})",
            total_bytes, used_bytes, free_bytes, progress_percent,
            images_size, video_size, audio_size, docs_size, other_size
        );
    }

}