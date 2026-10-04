// wayer_documents — recursive document filter. Migrated from document_engine.cpp.
#include <wayer/documents/document_engine.hpp>

#include <wayer/core/json_util.hpp>
#include <wayer/core/text.hpp>

#include <array>
#include <filesystem>
#include <format>
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

    for (const auto& entry : fs::recursive_directory_iterator(
             dir_path, fs::directory_options::skip_permission_denied, ec)) {
        if (ec) break;
        if (!entry.is_regular_file(ec) || ec) continue;

        const std::string ext = core::ascii_lower(entry.path().extension().string());

        bool is_doc = false;
        for (std::string_view valid_ext : TARGET_EXTENSIONS) {
            if (ext == valid_ext) {
                is_doc = true;
                break;
            }
        }

        if (is_doc) {
            if (!first) items_json += ",";
            uint64_t size = entry.file_size(ec);
            if (ec) {
                ec.clear();
                size = 0;
            }
            items_json += std::format(
                R"({{"name":"{}","path":"{}","size":{}}})",
                wayer::core::json::escape(entry.path().filename().string()),
                wayer::core::json::escape(entry.path().string()),
                size);
            first = false;
        }
    }

    return std::format(R"({{"path":"{}","documents":[{}]}})",
                       wayer::core::json::escape(std::string(path)), items_json);
}

} // namespace wayer::documents
