// wayer_storage — file-backed cache for stats/index JSON blobs.
#include <wayer/storage/storage_cache.hpp>

#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>
#include <system_error>

namespace wayer::storage {
namespace fs = std::filesystem;

void write_cache(const std::string& cache_path, const std::string& json) {
    std::error_code ec;
    fs::path p(cache_path);
    if (p.has_parent_path()) fs::create_directories(p.parent_path(), ec);
    std::ofstream f(cache_path, std::ios::binary | std::ios::trunc);
    f << json;
}

// Returns "" if missing or older than max_age_seconds.
std::string read_cache_if_fresh(const std::string& cache_path, int max_age_seconds) {
    std::error_code ec;
    if (!fs::exists(cache_path, ec)) return "";

    auto ftime = fs::last_write_time(cache_path, ec);
    if (ec) return "";
    auto now = fs::file_time_type::clock::now();
    auto age = std::chrono::duration_cast<std::chrono::seconds>(now - ftime).count();
    if (age > max_age_seconds) return "";

    std::ifstream f(cache_path, std::ios::binary);
    return std::string((std::istreambuf_iterator<char>(f)), {});
}

bool invalidate_cache(const std::string& cache_path) {
    std::error_code ec;
    return fs::remove(cache_path, ec);
}

} // namespace wayer::storage
