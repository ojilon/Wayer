// file_organizer.cpp (plan portion)
#include "file_organizer.hpp"
#include "dir_walker.hpp"
#include "extension_map.hpp"
#include "../utils/json_util.hpp"
#include <filesystem>
#include <format>
#include <chrono>

namespace wayer::storage {
    namespace fs = std::filesystem;

    namespace {
        std::string date_bucket(const fs::path& p) {
            std::error_code ec;
            auto ftime = fs::last_write_time(p, ec);
            if (ec) return "unknown-date";

            auto sctp = std::chrono::file_clock::to_sys(ftime);
            auto ymd = std::chrono::year_month_day{
                std::chrono::floor<std::chrono::days>(sctp)};

            return std::format("{:04}-{:02}",
                static_cast<int>(ymd.year()), static_cast<unsigned>(ymd.month()));
        }

        std::string category_for(const fs::path& p) {
            std::string ext = p.extension().string();
            std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
            auto it = EXTENSION_MAP.find(ext);
            return it != EXTENSION_MAP.end() ? std::string(it->second) : "others";
        }
    }

    std::string plan_organize(const std::string& root_path) {
        fs::path root(root_path);
        std::string json = R"({"moves":[)";
        bool first = true;

        walk_files(root_path, [&](const fs::directory_entry& entry) {
            const fs::path& src = entry.path();
            std::string category = category_for(src);

            // Only file types we actually recognize AND intend to relocate.
            // Images stay where they are for now (camera roll / DCIM conventions
            // need separate handling — revisit later).
            if (category == "others" || category == "images") return;

            std::string bucket = date_bucket(src);
            fs::path dest = root / category / bucket / src.filename();

            if (dest == src) return;

            if (!first) json += ",";
            first = false;
            json += std::format(
                R"({{"from":"{}","to":"{}"}})",
                json::escape(src.string()),
                json::escape(dest.string()));
        });

        json += "]}";
        return json;
    }

    std::string apply_organize(const std::string& plan_payload) {
        // plan_payload format: "from1|to1|from2|to2|..." — pairs of paths.
        // See storage/flags.md: "JSON parsing gap" for why this isn't JSON.

        std::vector<std::string> parts;
        {
            size_t start = 0;
            while (start <= plan_payload.size()) {
                auto pos = plan_payload.find('|', start);
                if (pos == std::string::npos) {
                    parts.push_back(plan_payload.substr(start));
                    break;
                }
                parts.push_back(plan_payload.substr(start, pos - start));
                start = pos + 1;
            }
        }

        int moved = 0, failed = 0, skipped = 0;
        std::error_code ec;

        // Walk pairs: parts[0]=from, parts[1]=to, parts[2]=from, parts[3]=to, ...
        for (size_t i = 0; i + 1 < parts.size(); i += 2) {
            fs::path from(parts[i]);
            fs::path to(parts[i + 1]);

            if (!fs::exists(from, ec)) { skipped++; continue; }

            fs::create_directories(to.parent_path(), ec);

            fs::path dest = to;
            if (fs::exists(dest, ec)) {
                dest = dest.parent_path() /
                       (dest.stem().string() + "_dup" + dest.extension().string());
            }

            fs::rename(from, dest, ec);
            if (ec) failed++; else moved++;
        }

        return std::format(
            R"({{"moved":{},"failed":{},"skipped":{}}})", moved, failed, skipped);
    }
}