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
                "[{d}]: {s}, {s}x{d} - ${d:.2}/hr\n",
                .{
                    idx,
                    it.cloud,
                    it.gpu_type,
                    it.num_gpus,
                    @as(f32, @floatFromInt(it.hourly_price)) / 100.0,
                },
            );
        }
    }

    pub fn instancesList(self: Cmd) !void {
        const instances = try self.client.getInstances();
        for (instances) |inst| {
            _ = try stdout.print(
                "{s}({s}): {s}\n",
                .{
                    inst.name,
                    inst.id,
                    inst.status,
                },
            );
        }
    }

    pub fn instanceDescribe(self: Cmd, instance_id: []const u8) !void {
        const instance = try self.client.getInstance(instance_id);
        _ = try stdout.print(
            "{s}\n",
            .{std.json.fmt(instance, .{ .whitespace = .indent_2 })},
        );
    }

    pub fn instanceDelete(self: Cmd, instance_id: []const u8) !void {
        try self.client.deleteInstance(instance_id);
        _ = try stdout.print("{s} deleted\n", .{instance_id});
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
                    describe: struct {
                        id: []const u8,
                    },
                    delete: struct {
                        id: []const u8,
                    },
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
                .describe => |d| {
                    try cli.instanceDescribe(d.id);
                },
                .delete => |d| {
                    try cli.instanceDelete(d.id);
                },
                else => return error.NotImplemented,
            }
        },
        else => return error.NotImplemented,
    }
}
