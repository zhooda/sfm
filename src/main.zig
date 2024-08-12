const std = @import("std");
const sfm = @import("shadeform.zig");
const simargs = @import("simargs");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var alloc_impl = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = alloc_impl.deinit();
    const alloc = alloc_impl.allocator();

    var opt = simargs.parse(alloc, struct {
        verbose: ?bool,
        help: bool = false,
        version: bool = false,

        __commands__: union(enum) {
            @"instance-types": struct {},

            pub const __messages__ = .{
                .@"instance-types" = "List instance types",
            };
        },

        pub const __shorts__ = .{
            .verbose = .v,
            .help = .h,
            .version = .V,
        };

        pub const __messages__ = .{
            .verbose = "Enable verbose output",
        };
    }, "[command]", "0.1.0\n") catch {
        try stdout.print("USAGE: sfm [OPTIONS] [COMMANDS]\n", .{});
        return;
    };
    defer opt.deinit();

    var http_client = std.http.Client{ .allocator = alloc };
    defer http_client.deinit();

    const api_key = try std.process.getEnvVarOwned(alloc, "SHADEFORM_API_KEY");
    var sf_client = try sfm.newClient(alloc, http_client, api_key);

    if (opt.args.__commands__ == .@"instance-types") {
        const instance_types = try sf_client.getInstances();
        for (instance_types, 0..) |it, idx| {
            _ = try stdout.print(
                "[{d}]: {s}, {s}, {s} - ${d}/hr\n",
                .{
                    idx,
                    it.cloud,
                    it.shade_instance_type,
                    it.cloud_instance_type,
                    @as(f32, @floatFromInt(it.hourly_price)) / 100.0,
                },
            );
        }
    }
}
