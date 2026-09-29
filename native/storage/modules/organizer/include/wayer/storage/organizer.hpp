#pragma once
// wayer_storage_organizer — plan/apply file organization.
#include <string>

namespace wayer::storage {
// Report-only: returns JSON plan of {from, to} moves. Does NOT touch disk.
std::string plan_organize(const std::string& root_path);
// Executes a previously-returned plan (pipe-delimited from|to|... — see flags.md).
std::string apply_organize(const std::string& plan_payload);
} // namespace wayer::storage
