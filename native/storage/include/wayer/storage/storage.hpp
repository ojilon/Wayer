#pragma once
// Public facade for the storage module — includes every public header.
#include <wayer/storage/analyse_storage_space.hpp>
#include <wayer/storage/cleaner.hpp>
#include <wayer/storage/extension_map.hpp>
#include <wayer/storage/list_files.hpp>
#include <wayer/storage/organizer.hpp>
#include <wayer/storage/safety.hpp>
#include <wayer/storage/search.hpp>
#include <wayer/storage/storage_cache.hpp>
#include <wayer/storage/walker.hpp>

namespace wayer::storage {

int storage_module_anchor();

} // namespace wayer::storage
