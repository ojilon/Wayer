// wayer_storage_cleaner — duplicate detection (size → partial hash → full hash).
#include <wayer/storage/cleaner.hpp>

#include <wayer/core/json_util.hpp>
#include <wayer/storage/walker.hpp>

#include <array>
#include <cstdint>
#include <filesystem>
#include <format>
#include <fstream>
#include <functional>
#include <string>
#include <string_view>
#include <system_error>
#include <unordered_map>
#include <vector>

namespace wayer::storage {

namespace {

// FNV-1a 64 over a byte stream — chunked, so multi-GB files never load fully.
uint64_t fnv1a_stream(std::istream& in, size_t max_bytes = static_cast<size_t>(-1)) {
    constexpr uint64_t kOffset = 14695981039346656037ULL;
    constexpr uint64_t kPrime = 1099511628211ULL;
    uint64_t h = kOffset;
    std::array<char, 8192> buf{};
    size_t remaining = max_bytes;
    while (in && remaining > 0) {
        size_t want = std::min(buf.size(), remaining);
        in.read(buf.data(), static_cast<std::streamsize>(want));
        std::streamsize got = in.gcount();
        if (got <= 0) break;
        for (std::streamsize i = 0; i < got; ++i) {
            h ^= static_cast<unsigned char>(buf[static_cast<size_t>(i)]);
            h *= kPrime;
        }
        remaining -= static_cast<size_t>(got);
    }
    return h;
}

// Cheap partial hash: first 4 KiB mixed with size.
uint64_t partial_hash(const fs::path& p, uint64_t size) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return size ^ 0x9E3779B97F4A7C15ULL;
    uint64_t h = fnv1a_stream(f, 4096);
    return h ^ (size * 0x9E3779B97F4A7C15ULL);
}

// Full hash only used to CONFIRM a partial-hash collision.
uint64_t full_hash(const fs::path& p) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return 0;
    return fnv1a_stream(f);
}

} // namespace

std::string find_duplicates(const std::string& root_path) {
    // Step 1: group by size.
    std::unordered_map<uint64_t, std::vector<fs::path>> by_size;
    walk_files(root_path, [&](const fs::directory_entry& e) {
        std::error_code ec;
        uint64_t sz = e.file_size(ec);
        if (!ec && sz > 0) by_size[sz].push_back(e.path());
    });

    // Step 2: within each size group, group by partial hash.
    std::vector<std::vector<fs::path>> duplicate_groups;
    for (auto& [size, paths] : by_size) {
        if (paths.size() < 2) continue; // unique size, can't be a dup

        std::unordered_map<uint64_t, std::vector<fs::path>> by_partial;
        for (auto& p : paths) by_partial[partial_hash(p, size)].push_back(p);

        // Step 3: confirm with full hash only for partial-hash collisions.
        for (auto& [ph, candidates] : by_partial) {
            (void)ph;
            if (candidates.size() < 2) continue;

            std::unordered_map<uint64_t, std::vector<fs::path>> by_full;
            for (auto& p : candidates) by_full[full_hash(p)].push_back(p);

            for (auto& [fh, confirmed] : by_full) {
                (void)fh;
                if (confirmed.size() > 1) duplicate_groups.push_back(confirmed);
            }
        }
    }

    std::string json = R"({"duplicate_groups":[)";
    for (size_t g = 0; g < duplicate_groups.size(); ++g) {
        json += "[";
        for (size_t i = 0; i < duplicate_groups[g].size(); ++i) {
            json += std::format(R"("{}")", core::json::escape(duplicate_groups[g][i].string()));
            if (i + 1 < duplicate_groups[g].size()) json += ",";
        }
        json += "]";
        if (g + 1 < duplicate_groups.size()) json += ",";
    }
    json += "]}";
    return json;
}

} // namespace wayer::storage
