#include "document_engine.hpp"
#include <filesystem>
#include <format>
#include <algorithm>
#include <array>
#include <string>
#include <string_view>
#include <system_error>

namespace wayer::documents {
    namespace fs = std::filesystem;

    constexpr std::array<std::string_view, 5> TARGET_EXTENSIONS{
        ".pdf", ".epub", ".docx", ".txt", ".md"
    };

    std::string filter_documents(std::string_view path) {
        std::error_code ec;
        const fs::path dir_path{path};

        if (!fs::exists(dir_path, ec) || !fs::is_directory(dir_path, ec)) {
            return R"({"error": "invalid_directory"})";
        }

        std::string items_json;
        bool first = true;

        for (const auto& entry : fs::recursive_directory_iterator(dir_path, fs::directory_options::skip_permission_denied, ec)) {
            if (ec) break;
            if(!entry.is_regular_file(ec)) continue;

            const auto ext = entry.path().extension().string();

            //C++23/20 ranges check against extension list
            const bool is_doc = std::ranges::any_of(TARGET_EXTENSIONS, [&ext](std::string_view valid_ext) {
                return ext == valid_ext;
            });

            if (is_doc) {
                if (!first) {
                    items_json += ",";
                }

                items_json += std::format(
                    R"({{"name":"{}","path":"{}","size":{}}})",
                    entry.path().filename().string(),
                    entry.path().string(),
                    entry.file_size(ec)
                );

                first = false;
            }
        }

        return std::format(R"({{"path":"{}","documents":[{}]}})", path, items_json);
    }

}