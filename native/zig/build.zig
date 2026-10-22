// wayer Zig build script
// Builds all modules into a single shared library for Android JNI

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core module
    const core_module = b.createModule(.{
        .root_source_file = b.path("core/src/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Storage module
    const storage_module = b.createModule(.{
        .root_source_file = b.path("storage/src/storage.zig"),
        .target = target,
        .optimize = optimize,
    });
    storage_module.addImport("core", core_module);

    // Storage search submodule
    const search_module = b.createModule(.{
        .root_source_file = b.path("storage/modules/search/src/file_search.zig"),
        .target = target,
        .optimize = optimize,
    });
    search_module.addImport("core", core_module);
    search_module.addImport("storage", storage_module);

    // Storage cleaner submodule
    const large_files_module = b.createModule(.{
        .root_source_file = b.path("storage/modules/cleaner/src/large_files.zig"),
        .target = target,
        .optimize = optimize,
    });
    large_files_module.addImport("core", core_module);
    large_files_module.addImport("storage", storage_module);

    const duplicate_finder_module = b.createModule(.{
        .root_source_file = b.path("storage/modules/cleaner/src/duplicate_finder.zig"),
        .target = target,
        .optimize = optimize,
    });
    duplicate_finder_module.addImport("core", core_module);
    duplicate_finder_module.addImport("storage", storage_module);

    // Storage organizer submodule
    const organizer_module = b.createModule(.{
        .root_source_file = b.path("storage/modules/organizer/src/file_organizer.zig"),
        .target = target,
        .optimize = optimize,
    });
    organizer_module.addImport("core", core_module);
    organizer_module.addImport("storage", storage_module);

    // Documents module
    const documents_module = b.createModule(.{
        .root_source_file = b.path("documents/src/document_engine.zig"),
        .target = target,
        .optimize = optimize,
    });
    documents_module.addImport("core", core_module);

    // Transfer module
    const transfer_module = b.createModule(.{
        .root_source_file = b.path("transfer/src/transfer_engine.zig"),
        .target = target,
        .optimize = optimize,
    });
    transfer_module.addImport("core", core_module);

    // Preview module
    const preview_module = b.createModule(.{
        .root_source_file = b.path("preview/src/preview.zig"),
        .target = target,
        .optimize = optimize,
    });
    preview_module.addImport("core", core_module);

    // Media module
    const media_module = b.createModule(.{
        .root_source_file = b.path("media/src/media.zig"),
        .target = target,
        .optimize = optimize,
    });
    media_module.addImport("core", core_module);

    // Root module (router)
    const root_module = b.createModule(.{
        .root_source_file = b.path("zig/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("core", core_module);
    root_module.addImport("storage", storage_module);
    root_module.addImport("search", search_module);
    root_module.addImport("large_files", large_files_module);
    root_module.addImport("duplicate_finder", duplicate_finder_module);
    root_module.addImport("organizer", organizer_module);
    root_module.addImport("documents", documents_module);
    root_module.addImport("transfer", transfer_module);
    root_module.addImport("preview", preview_module);
    root_module.addImport("media", media_module);

    // Shared library for Android (loaded by JNI)
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "wayer_core",
        .root_module = root_module,
    });

    // Android NDK target
    if (target.result.os.tag == .linux) {
        lib.linkLibC();
        lib.linkSystemLibrary("log");
        lib.linkSystemLibrary("dl");
        lib.linkSystemLibrary("m");
    }

    // Link SQLite from third_party
    lib.linkSystemLibrary("sqlite3");

    // C-compatible exports
    lib.linkLibC();

    // Export the library for linking from JNI
    const lib_artifact = lib.artifact();

    // Install step
    const install = b.step("install", "Install the library");
    install.addArtifact(lib_artifact);

    // Also add a step to copy to jniLibs for Android
    const copy_to_jni = b.step("copy-jni", "Copy library to jniLibs");
    copy_to_jni.dependOn(&install);
}