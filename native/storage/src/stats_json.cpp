// wayer_storage — stats document writer. See include/wayer/storage/stats_json.hpp.
#include <wayer/storage/stats_json.hpp>

#include <nlohmann/json.hpp>

#include <cstdint>
#include <string>
#include <vector>

namespace wayer::storage {

std::string build_stats_json(const StorageNumbers& numbers) {
    nlohmann::json breakdown;
    breakdown["images"] = numbers.images;
    breakdown["videos"] = numbers.videos;
    breakdown["audio"] = numbers.audio;
    breakdown["documents"] = numbers.documents;
    breakdown["foreign"] = numbers.foreign;
    breakdown["system"] = numbers.system;
    breakdown["others"] = numbers.others;

    nlohmann::json folders = nlohmann::json::array();
    for (const FolderStat& folder : numbers.folders) {
        nlohmann::json entry;
        entry["path"] = folder.name;
        entry["bytes"] = folder.bytes;
        folders.push_back(entry);
    }

    nlohmann::json doc;
    doc["total_bytes"] = numbers.total_bytes;
    doc["used_bytes"] = numbers.used_bytes;
    doc["free_bytes"] = numbers.free_bytes;
    doc["progress_percent"] = numbers.progress_percent;
    doc["breakdown"] = breakdown;
    doc["folders"] = folders;
    return doc.dump();
}

} // namespace wayer::storage
