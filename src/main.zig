const std = @import("std");
const sfm = @import("shadeform.zig");
const simargs = @import("simargs");
const stdout = std.io.getStdOut().writer();

const Cmd = struct {
    allocator: std.mem.Allocator,

    // TODO: learn const properly to avoid the compiler error
    client: *sfm.Client,

    pub fn instancesListTypes(self: Cmd) !void {
        const instance_types = try self.client.getInstanceTypes();
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

    pub fn instancesList(self: Cmd) !void {
        const instances = try self.client.getInstances();
        for (instances, 0..) |inst, idx| {
            _ = try stdout.print("[{d}]: {s}, {s}, {s} - ${d}/hr\n", .{
                idx,
                inst.id,
                inst.cloud,
                inst.shade_instance_type,
                @as(f32, @floatFromInt(inst.hourly_price)) / 100.0,
            });
        }
    }
};

pub fn main() !void {
    var alloc_impl = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = alloc_impl.deinit();
    const alloc = alloc_impl.allocator();

    var opt = simargs.parse(alloc, struct {
        verbose: ?bool,
        help: bool = false,
        version: bool = false,

        __commands__: union(enum) {

            // TODO: replace anon structs with named ones
            instances: struct {
                __commands__: union(enum) {
                    create: struct {},
                    describe: struct {},
                    delete: struct {},
                    list: struct {},
                    @"list-types": struct {},
                },
            },
            volumes: struct {},
            keys: struct {},

            // pub const __messages__ = .{
            //     .instances = "List instance types",
            // };
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

    const cli = Cmd{ .allocator = alloc, .client = &sf_client };

    switch (opt.args.__commands__) {
        .instances => |cmd| {
            switch (cmd.__commands__) {
                .@"list-types" => {
                    try cli.instancesListTypes();
                },
                .list => {
                    try cli.instancesList();
                },
                else => return error.NotImplemented,
            }
        },
        else => return error.NotImplemented,
    }
}
