#pragma once
// wayer_storage — SQLite record of stats snapshots (defined in src/stats_db.cpp).
// Schema v1, best-effort: a failed record never fails the stats call itself.
#include <cstdint>
#include <string>

namespace wayer::storage {

// Insert (or replace) the snapshot row for root. DB lives at
// <app cache>/stats/stats.db and is regenerable, like every other cache.
bool stats_db_record(const std::string& root, uint64_t total_bytes, uint64_t used_bytes);

} // namespace wayer::storage
