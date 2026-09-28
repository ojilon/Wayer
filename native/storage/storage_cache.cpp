// storage_cache.cpp
/**
 * Provides cache read/write functionality for storage statistics.
 * Cache files are checked for freshness based on max_age_seconds.
 * read_cache_if_fresh returns "" if cache is missing or older than max_age.
 * write_cache overwrites the cache file with new JSON content.
 * 
 * Uses std::filesystem for file existence checks and modification time retrieval.
 * Uses std::ofstream for writing cache files (binary mode, truncate).
 * Uses std::ifstream for reading cache files.
 * 
 * @param cache_path The file path for the cache.
 * @param json The JSON string to write to cache.
 * @param max_age_seconds Maximum age in seconds for cache to be considered fresh.
 * @return The cached JSON string if fresh, otherwise empty string.
 * 
 * STL usage:
 * - std::filesystem::path: file path handling
 * - std::filesystem::file_time_type: file modification time type
 * - std::filesystem::last_write_time: gets file modification time
 * - std::ofstream: writes to cache file
 * - std::ifstream: reads from cache file
 * - std::istreambuf_iterator: reads entire file content
 * - std::chrono::seconds: age calculation
 * 
 * Example: write_cache("/data/data/cache.json", stats_json) writes stats to cache.
 * read_cache_if_fresh("/data/data/cache.json", 300) returns cached stats if less than 5min old.
 */
#include <fstream>
#include <filesystem>

namespace wayer::storage {
    void write_cache(const std::string& cache_path, const std::string& json) {
        std::ofstream f(cache_path, std::ios::binary | std::ios::trunc);
        f << json;
    }

    // Returns "" if missing or older than max_age_seconds.
    std::string read_cache_if_fresh(const std::string& cache_path, int max_age_seconds) {
        namespace fs = std::filesystem;
        std::error_code ec;
        if (!fs::exists(cache_path, ec)) return "";

        auto ftime = fs::last_write_time(cache_path, ec);
        auto now = fs::file_time_type::clock::now();
        auto age = std::chrono::duration_cast<std::chrono::seconds>(now - ftime).count();
        if (age > max_age_seconds) return "";

        std::ifstream f(cache_path, std::ios::binary);
        return std::string((std::istreambuf_iterator<char>(f)), {});
    }
}