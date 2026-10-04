// wayer_storage — extension → category map.
// See include/wayer/storage/extension_map.hpp.
#include <wayer/storage/extension_map.hpp>

#include <wayer/core/text.hpp>

#include <string>
#include <string_view>
#include <unordered_map>

namespace wayer::storage {

const std::unordered_map<std::string, std::string> EXTENSION_MAP = {
    {".jpg", "images"}, {".jpeg", "images"}, {".png", "images"}, {".webp", "images"},
    {".mp4", "videos"}, {".mkv", "videos"},   {".avi", "videos"}, {".webm", "videos"},
    {".mp3", "audio"},  {".wav", "audio"},    {".flac", "audio"}, {".m4a", "audio"},
    {".pdf", "documents"}, {".txt", "documents"}, {".docx", "documents"}, {".doc", "documents"},
    {".apk", "foreign"}, {".obb", "foreign"}
};

std::string category_for_extension(std::string_view ext) {
    const std::string lowered = core::ascii_lower(std::string(ext));
    const auto found = EXTENSION_MAP.find(lowered);
    if (found == EXTENSION_MAP.end()) return "others";
    return found->second;
}

} // namespace wayer::storage
