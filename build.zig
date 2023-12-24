const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "feint",
        .root_source_file = .{ .path = "src/main.zig" },
    });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");

    run_step.dependOn(&run_exe.step);

    if (b.args) |args| {
        run_exe.addArgs(args);
    }
}
