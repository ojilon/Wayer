// wayer_storage — storage statistics over a root path.
#include <wayer/storage/analyse_storage_space.hpp>

#include <wayer/storage/extension_map.hpp>
#include <wayer/storage/walker.hpp>

#include <cstdint>
#include <filesystem>
#include <format>
#include <string>
#include <sys/statvfs.h>
#include <unordered_map>

namespace wayer::storage {
    namespace fs = std::filesystem;

    // Legacy floor when Java has not supplied a real device capacity.
    // Prefer the known_device_bytes overload; Java should query StorageManager.
    constexpr uint64_t RETAIL_64GB = 64ULL * 1000ULL * 1000ULL * 1000ULL;

    std::string get_storage_stats(const std::string& root_path) {
        return get_storage_stats(root_path, 0);
    }

    std::string get_storage_stats(const std::string& root_path, uint64_t known_device_bytes) {
        struct statvfs stat {};
        if (statvfs(root_path.c_str(), &stat) != 0) {
            return R"({"error": "Failed to read storage statistics"})";
        }

        // Partition metrics from the OS.
        uint64_t partition_total = static_cast<uint64_t>(stat.f_blocks) * stat.f_frsize;
        uint64_t free_bytes = static_cast<uint64_t>(stat.f_bavail) * stat.f_frsize;
        uint64_t partition_used = partition_total > free_bytes ? partition_total - free_bytes : 0;

        uint64_t device_total = known_device_bytes != 0 ? known_device_bytes
            : (partition_total > RETAIL_64GB ? partition_total : RETAIL_64GB);
        if (device_total < partition_total) device_total = partition_total;

        uint64_t system_bytes = device_total > partition_total ? device_total - partition_total : 0;
        uint64_t used_bytes = partition_used + system_bytes;

        int progress_percent =
            device_total > 0 ? static_cast<int>((used_bytes * 100) / device_total) : 0;

        std::unordered_map<std::string, uint64_t> categories = {
            {"images", 0}, {"videos", 0}, {"audio", 0}, {"documents", 0},
            {"foreign", 0}, {"others", 0},
        };

        walk_files(root_path, [&](const fs::directory_entry& entry) {
            std::error_code ec;
            const std::string ext = entry.path().extension().string();
            const uint64_t sz = entry.file_size(ec);
            if (ec) return;
            categories[category_for_extension(ext)] += sz;
        });

        return std::format(
            R"({{)"
            R"("total_bytes":{},"used_bytes":{},"free_bytes":{},"progress_percent":{},)"
            R"("breakdown":{{"images":{},"videos":{},"audio":{},"documents":{},"foreign":{},"system":{},"others":{}}})"
            R"(}})",
            device_total, used_bytes, free_bytes, progress_percent,
            categories["images"], categories["videos"], categories["audio"],
            categories["documents"], categories["foreign"], system_bytes, categories["others"]);
    }
} // namespace wayer::storage
