// wayer_storage — SQLite stats record. See include/wayer/storage/stats_db.hpp.
#include <wayer/storage/stats_db.hpp>

#include <wayer/core/paths.hpp>

#include <sqlite3.h>

#include <cstdint>
#include <ctime>
#include <filesystem>
#include <string>
#include <system_error>

namespace wayer::storage {
namespace fs = std::filesystem;

bool stats_db_record(const std::string& root, uint64_t total_bytes, uint64_t used_bytes) {
    if (root.empty() || !core::app_paths_initialized()) return false;

    std::error_code ec;
    const fs::path dir = fs::path(core::app_paths().cache) / "stats";
    fs::create_directories(dir, ec);
    if (ec) return false;
    const std::string db_path = (dir / "stats.db").string();

    sqlite3* db = nullptr;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK) {
        sqlite3_close(db);
        return false;
    }

    const char* schema =
        "CREATE TABLE IF NOT EXISTS stats_snapshots("
        "root TEXT PRIMARY KEY, total_bytes INTEGER, used_bytes INTEGER, "
        "computed_unix INTEGER);";
    bool ok = sqlite3_exec(db, schema, nullptr, nullptr, nullptr) == SQLITE_OK;

    sqlite3_stmt* insert = nullptr;
    if (ok) {
        ok = sqlite3_prepare_v2(db,
                                "INSERT OR REPLACE INTO stats_snapshots"
                                "(root, total_bytes, used_bytes, computed_unix)"
                                " VALUES(?, ?, ?, ?);",
                                -1, &insert, nullptr) == SQLITE_OK;
    }
    if (ok) {
        ok = sqlite3_bind_text(insert, 1, root.c_str(), -1, SQLITE_TRANSIENT) == SQLITE_OK;
    }
    if (ok) {
        ok = sqlite3_bind_int64(insert, 2, static_cast<sqlite3_int64>(total_bytes)) == SQLITE_OK;
    }
    if (ok) {
        ok = sqlite3_bind_int64(insert, 3, static_cast<sqlite3_int64>(used_bytes)) == SQLITE_OK;
    }
    if (ok) {
        const long long now = static_cast<long long>(std::time(nullptr));
        ok = sqlite3_bind_int64(insert, 4, static_cast<sqlite3_int64>(now)) == SQLITE_OK;
    }
    if (ok) {
        ok = sqlite3_step(insert) == SQLITE_DONE;
    }
    sqlite3_finalize(insert);
    sqlite3_close(db);
    return ok;
}

} // namespace wayer::storage
