#include <filesystem>
#include <string>
#include <sstream>
#include "../utils/json_util.hpp"

/**
 * Lists files in the specified directory and returns them as a JSON string.
 * Uses std::filesystem for directory iteration (recursive_directory_iterator).
 * Uses std::ostringstream for efficient string building.
 *
 * @param path The directory path to list files from.
 * @return JSON string containing file names, e.g., {"files":["file1.txt","file2.pdf"]}.
 *
 * STL usage:
 * - std::filesystem::directory_iterator: iterates over directory entries
 * - std::filesystem::path: represents file system paths
 * - std::ostringstream: efficient string stream for building JSON output
 *
 * Example: list_files("/storage/emulated/0") returns {"files":["doc1.pdf","image.jpg"]}
 */
namespace wayer::storage {
    namespace fs = std::filesystem;

    std::string list_files(std::string_view path) {
        std::error_code ec;
        fs::path dir_path(path);

        if (!fs::exists(dir_path, ec) || !fs::is_directory(dir_path, ec)) {
            return R"({"error":"invalid_directory"})";
        }

        std::ostringstream json;
        json << R"({"files": [)";
        bool first = true;

        for (const auto& entry : fs::directory_iterator(dir_path, ec)) {
            if (!first) json << ",";
            json << "\"" << json::escape(entry.path().filename().string()) << "\"";
            first = false;
        }

        json << "]}";
        return json.str();
    }

}