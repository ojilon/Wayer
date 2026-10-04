#pragma once
// wayer_storage — stats document model + JSON writer (defined in src/stats_json.cpp).
// Split out of analyse_storage_space.cpp so the document shape is buildable
// and testable without touching the filesystem. Field names match what the
// Java screens have always parsed, plus "folders".
#include <cstdint>
#include <string>
#include <vector>

namespace wayer::storage {

struct FolderStat {
    std::string name;
    uint64_t bytes = 0;
};

struct StorageNumbers {
    uint64_t total_bytes = 0;
    uint64_t used_bytes = 0;
    uint64_t free_bytes = 0;
    int progress_percent = 0;
    uint64_t images = 0;
    uint64_t videos = 0;
    uint64_t audio = 0;
    uint64_t documents = 0;
    uint64_t foreign = 0;
    uint64_t system = 0;
    uint64_t others = 0;
    std::vector<FolderStat> folders; // top-level dirs by size, already capped
};

// Built with the JSON lib — no hand-format string surgery as it grows.
std::string build_stats_json(const StorageNumbers& numbers);

} // namespace wayer::storage
