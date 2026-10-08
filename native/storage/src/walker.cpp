// wayer_storage — shared walk primitive. See include/wayer/storage/walker.hpp.
#include <wayer/storage/walker.hpp>

#include <wayer/storage/safety.hpp>

#include <filesystem>
#include <functional>
#include <string>
#include <system_error>

namespace wayer::storage {

void walk_files(const std::string& root,
                const std::function<void(const fs::directory_entry&)>& visit) {
    std::error_code ec;
    fs::recursive_directory_iterator it(
        root, fs::directory_options::skip_permission_denied, ec);
    fs::recursive_directory_iterator end;

    if (ec) return; // can't even open root

    while (it != end) {
        const fs::directory_entry& entry = *it;

        bool is_dir = entry.is_directory(ec);
        if (ec) {
            ec.clear();
            it.increment(ec);
            continue;
        }

        if (is_dir) {
            if (is_excluded_dir(entry.path())) {
                it.disable_recursion_pending(); // don't step inside this dir
            }
            it.increment(ec);
            continue;
        }

        bool is_file = entry.is_regular_file(ec);
        if (!ec && is_file) visit(entry);

        it.increment(ec);
        if (ec) break; // stop cleanly rather than looping on a broken iterator
    }
}

} // namespace wayer::storage
