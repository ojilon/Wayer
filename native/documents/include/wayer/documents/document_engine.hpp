#pragma once
// wayer_documents — document filtering. Migrated from document_engine.hpp.
#include <string>
#include <string_view>

namespace wayer::documents {
std::string filter_documents(std::string_view path);
} // namespace wayer::documents
