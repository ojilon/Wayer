// wayer_storage_organizer — plan + apply organization moves.
#include <wayer/storage/organizer.hpp>

#include <wayer/core/json_util.hpp>
#include <wayer/core/text.hpp>
#include <wayer/storage/extension_map.hpp>
#include <wayer/storage/walker.hpp>

#include <nlohmann/json.hpp>

#include <chrono>
#include <filesystem>
#include <format>
#include <fstream>
#include <string>
#include <system_error>
#include <vector>

namespace wayer::storage {
namespace fs = std::filesystem;

namespace {
// One approved move. Plain struct, filled from the plan file Java wrote.
struct Move {
    std::string from;
    std::string to;
};

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

// Only failed moves are listed, capped so a disaster stays small.
constexpr std::size_t kMaxErrors = 100;

void note_error(nlohmann::json& errors, const std::string& from, const std::string& reason) {
    if (errors.size() >= kMaxErrors) return;
    nlohmann::json entry;
    entry["from"] = from;
    entry["reason"] = reason;
    errors.push_back(entry);
}

} // namespace

std::string plan_organize(const std::string& root_path) {
    fs::path root(root_path);
    std::string json = R"({"moves":[)";
    bool first = true;

    walk_files(root_path, [&](const fs::directory_entry& entry) {
        const fs::path& src = entry.path();
        const std::string category = category_for_extension(src.extension().string());

        // Only file types we actually recognize AND intend to relocate.
        // Images stay where they are for now (camera roll / DCIM conventions
        // need separate handling — see flags.md).
        if (category == "others" || category == "images") return;

        std::string bucket = date_bucket(src);
        fs::path dest = root / category / bucket / src.filename();

        if (dest == src) return;

        if (!first) json += ",";
        first = false;
        json += std::format(
            R"({{"from":"{}","to":"{}"}})",
            core::json::escape(src.string()),
            core::json::escape(dest.string()));
    });

    json += "]}";
    return json;
}

std::string plan_organize_to_file(const std::string& root_path, const std::string& out_path) {
    const std::string json = plan_organize(root_path);
    if (!core::write_text_file(out_path, json)) {
        return R"({"status":"error","reason":"write_failed"})";
    }
    return std::format(R"({{"status":"ok","path":"{}"}})", core::json::escape(out_path));
}

std::string apply_organize_file(const std::string& plan_path, const std::string& report_path) {
    std::ifstream in(plan_path, std::ios::binary);
    if (!in) return R"({"status":"error","reason":"bad_plan"})";
    const std::string text((std::istreambuf_iterator<char>(in)), {});

    nlohmann::json plan;
    try {
        plan = nlohmann::json::parse(text);
    } catch (const nlohmann::json::exception&) {
        return R"({"status":"error","reason":"bad_plan"})";
    }
    const auto moves_it = plan.find("moves");
    if (!plan.is_object() || moves_it == plan.end() || !moves_it->is_array()) {
        return R"({"status":"error","reason":"bad_plan"})";
    }

    std::vector<Move> moves;
    for (const auto& item : *moves_it) {
        if (!item.is_object()) return R"({"status":"error","reason":"bad_plan"})";
        const auto from_it = item.find("from");
        const auto to_it = item.find("to");
        if (from_it == item.end() || to_it == item.end()) {
            return R"({"status":"error","reason":"bad_plan"})";
        }
        if (!from_it->is_string() || !to_it->is_string()) {
            return R"({"status":"error","reason":"bad_plan"})";
        }
        moves.push_back(Move{from_it->get<std::string>(), to_it->get<std::string>()});
    }

    int moved = 0;
    int failed = 0;
    int skipped = 0;
    nlohmann::json errors = nlohmann::json::array();
    std::error_code ec;

    for (const Move& move : moves) {
        if (move.from.empty() || move.to.empty()) {
            ++skipped;
            continue;
        }
        const fs::path from(move.from);
        fs::path to(move.to);
        if (!fs::exists(from, ec) || ec) {
            ++skipped;
            continue;
        }

        fs::create_directories(to.parent_path(), ec);
        if (ec) {
            ++failed;
            note_error(errors, move.from, "mkdir_failed");
            continue;
        }

        fs::path dest = to;
        if (fs::exists(dest, ec) && !ec) {
            dest = dest.parent_path() /
                   (dest.stem().string() + "_dup" + dest.extension().string());
        }

        ec.clear();
        fs::rename(from, dest, ec);
        if (ec) {
            ++failed;
            note_error(errors, move.from, "move_failed");
        } else {
            ++moved;
        }
    }

    nlohmann::json report;
    report["moved"] = moved;
    report["failed"] = failed;
    report["skipped"] = skipped;
    report["errors"] = errors;
    if (!core::write_text_file(report_path, report.dump())) {
        return R"({"status":"error","reason":"write_failed"})";
    }
    return std::format(R"({{"status":"ok","path":"{}"}})", core::json::escape(report_path));
}

} // namespace wayer::storage
