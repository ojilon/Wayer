// file_organizer.hpp
#pragma once
#include <string>
namespace wayer::storage {
    // Report-only: returns JSON plan of {from, to} moves. Does NOT touch disk.
    std::string plan_organize(const std::string& root_path);

    // Executes a previously-returned plan. Java calls this only after user confirms.
    std::string apply_organize(const std::string& plan_json);
}