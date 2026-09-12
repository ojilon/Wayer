// storage_cache.cpp
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