const std = @import("std");

const headers_max_size = 1024;
const body_max_size = 1024 * 1024 * 4;

pub const InstanceType = struct {
    cloud: []const u8,
    shade_instance_type: []const u8,
    cloud_instance_type: []const u8,
    configuration: struct {
        memory_in_gb: u16,
        storage_in_gb: u32,
        vcpus: u16,
        num_gpus: u8,
        gpu_type: []const u8,
        interconnect: []const u8,
        nvlink: bool,
        os_options: [][]const u8,
        vram_per_gpu_in_gb: u16,
    },
    memory_in_gb: u16,
    storage_in_gb: u32,
    vcpus: u16,
    num_gpus: u8,
    gpu_type: []const u8,
    interconnect: []const u8,
    nvlink: bool,
    hourly_price: u32,
    availability: []struct {
        region: []const u8,
        available: bool,
    },
};

pub const CreateInstanceReq = struct {
    cloud: []const u8,
    region: []const u8,
    shade_instance_type: []const u8,
    shade_cloud: bool,
    name: []const u8,
};

pub const CreateInstanceRes = struct {
    id: []const u8,
    cloud_assigned_id: []const u8,
};

pub fn newClient(
    allocator: std.mem.Allocator,
    client: std.http.Client,
    api_key: []const u8,
) !Client {
    var headers: []std.http.Header = try allocator.alloc(std.http.Header, 1);
    headers[0] = std.http.Header{ .name = "X-API-KEY", .value = api_key };

    return .{
        .allocator = allocator,
        .api_key = api_key,
        .headers = headers,
        .client = client,
    };
}

pub const Client = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    uri: std.Uri = std.Uri{
        .scheme = "https",
        .host = std.Uri.Component{ .raw = "api.shadeform.ai" },
        .path = std.Uri.Component{ .raw = "/v1" },
    },
    api_key: []const u8,
    headers: []const std.http.Header,

    client: std.http.Client,
    _hbuf: [headers_max_size]u8 = undefined,
    _bbuf: []u8 = undefined,
    _req_opts: std.http.Client.RequestOptions = undefined,

    pub fn printUri(self: Self) void {
        std.debug.print("shadeform.Client.uri = {}\n", .{self.uri});
    }

    pub fn printHeaders(self: Self) void {
        const headers = self.headers;
        for (headers) |header| {
            std.debug.print(
                "{s}: {s}\n",
                .{ header.name, header.value },
            );
        }
    }

    pub fn getInstances(self: *Self) ![]InstanceType {
        self.uri.path = std.Uri.Component{ .raw = "/v1/instances/types" };

        self._req_opts = std.http.Client.RequestOptions{
            .server_header_buffer = &self._hbuf,
            .extra_headers = self.headers,
        };
        var request = try self.client.open(
            std.http.Method.GET,
            self.uri,
            self._req_opts,
        );
        errdefer request.deinit();

        try request.send();
        try request.finish();
        try request.wait();

        // var iter = request.response.iterateHeaders();
        // while (iter.next()) |header| {
        //     std.debug.print("Name:{s}, Value:{s}\n", .{
        //         header.name,
        //         header.value,
        //     });
        // }

        try std.testing.expectEqual(request.response.status, .ok);

        var rdr = request.reader();
        // _ = try rdr.readAll(&self._bbuf);
        self._bbuf = try rdr.readAllAlloc(self.allocator, body_max_size);
        errdefer self.allocator.free(self._bbuf);

        const T = struct { instance_types: []InstanceType };
        const parsed = try std.json.parseFromSliceLeaky(T, self.allocator, self._bbuf, .{});

        return parsed.instance_types;
    }
};