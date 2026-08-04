#include "storage_engine.hpp"
#include <filesystem>
#include <sstream>
#include <system_error>

namespace wayer::storage {
    namespace fs = std::filesystem;

    std::string list_files(std::string_view path) {
        std::error_code ec;
        fs::path dir_path(path);

        if(!fs::exists(dir_path, ec) || !fs::is_directory(dir_path, ec)) {
            return R"({"error":"invalid_directory"})";
        }

        std::ostringstream json;
        json << R"({"files": [)";
        bool first = true;

        for (const auto& entry : fs::directory_iterator(dir_path, ec)) {
            if (!first) json << ",";
            json << "\"" << entry.path().filename().string() << "\"";
            first = false;
        }

        json << "]}";
        return json.str();
    }

}