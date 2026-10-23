package storage

// Storage module - re-exports all storage submodules
// This allows wayer_core.odin to import storage "../storage/src"



// Re-export key types
Category :: extension_map.Category
FolderStat :: stats_json.FolderStat
StorageNumbers :: stats_json.StorageNumbers
SearchResult :: search.SearchResult
Move :: organizer.Move
LargeEntry :: cleaner.LargeEntry
DupFile :: cleaner.DupFile

// Re-export key procedures
list_files :: list_files.list_files
build_index :: index.build_index
index_meta :: index.index_meta
search_index_to_file :: index.search_index_to_file
group_index_by_day :: index.group_index_by_day
write_cache :: cache.write_cache
read_cache_if_fresh :: cache.read_cache_if_fresh
invalidate_cache :: cache.invalidate_cache
write_storage_stats :: analyse_storage_space.write_storage_stats
stats_db_record :: stats_db.stats_db_record
search_files :: search.search_files
search_files_to_file :: search.search_files_to_file
plan_organize :: organizer.plan_organize
plan_organize_to_file :: organizer.plan_organize_to_file
apply_organize_file :: organizer.apply_organize_file
find_large_files :: cleaner.find_large_files
find_large_files_to_file :: cleaner.find_large_files_to_file
find_duplicates :: cleaner.find_duplicates
find_duplicates_to_file :: cleaner.find_duplicates_to_file
build_stats_json :: stats_json.build_stats_json
ascii_lower :: core_heart.ascii_lower
json_escape :: core_heart.json_escape
write_text_file :: core_heart.write_text_file
is_excluded_dir :: safety.is_excluded_dir
category_for_name :: extension_map.category_for_name
category_for_extension :: extension_map.category_for_extension