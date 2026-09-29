#pragma once
// wayer_storage — extension → category map. Migrated from extension_map.hpp.
#include <string>
#include <string_view>
#include <unordered_map>

namespace wayer::storage {

inline const std::unordered_map<std::string, std::string> EXTENSION_MAP = {
    {".jpg", "images"}, {".jpeg", "images"}, {".png", "images"}, {".webp", "images"},
    {".mp4", "videos"}, {".mkv", "videos"},   {".avi", "videos"}, {".webm", "videos"},
    {".mp3", "audio"},  {".wav", "audio"},    {".flac", "audio"}, {".m4a", "audio"},
    {".pdf", "documents"}, {".txt", "documents"}, {".docx", "documents"}, {".doc", "documents"},
    {".apk", "foreign"}, {".obb", "foreign"}
};

// Lower-cased extension (including dot) → category, or "others".
inline std::string category_for_extension(std::string ext_lowered) {
    auto it = EXTENSION_MAP.find(ext_lowered);
    return it != EXTENSION_MAP.end() ? it->second : "others";
}

} // namespace wayer::storage
