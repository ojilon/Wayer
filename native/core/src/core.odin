package core_heart

import json_util "./json_util.odin"
import paths "./paths.odin"
import logging "./logging.odin"
import text "./text.odin"

// Re-export all procedures
json_escape :: json_util.json_escape
bool_to_string :: json_util.bool_to_string

ensure_app_dirs :: paths.ensure_app_dirs
write_paths_manifest :: paths.write_paths_manifest
set_app_paths :: paths.set_app_paths
get_app_paths :: paths.get_app_paths
all_ready :: paths.all_ready
is_app_paths_initialized :: paths.is_app_paths_initialized
AppPaths :: paths.AppPaths
DirEnsure :: paths.DirEnsure
AppDirsReport :: paths.AppDirsReport

info :: logging.info
error :: logging.error
infof :: logging.infof
errorf :: logging.errorf

ascii_lower :: text.ascii_lower
write_text_file :: text.write_text_file