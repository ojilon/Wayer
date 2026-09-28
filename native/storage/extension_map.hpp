// extension_map.hpp
#pragma once
#include <unordered_map>
#include <string_view>
namespace wayer::storage {
    inline const std::unordered_map<std::string_view, std::string_view> EXTENSION_MAP = {
        {".jpg", "images"}, {".jpeg", "images"}, {".png", "images"}, {".webp", "images"},
        {".mp4", "videos"}, {".mkv", "videos"},   {".avi", "videos"}, {".webm", "videos"},
        {".mp3", "audio"},  {".wav", "audio"},    {".flac", "audio"}, {".m4a", "audio"},
        {".pdf", "documents"}, {".txt", "documents"}, {".docx", "documents"}, {".doc", "documents"},
        {".apk", "foreign"}, {".obb", "foreign"}
    };
}