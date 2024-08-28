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

pub const Instance = struct {
    id: []const u8,
    cloud: []const u8,
    region: []const u8,
    shade_instance_type: []const u8,
    cloud_instance_type: []const u8,
    cloud_assigned_id: []const u8,
    shade_cloud: bool,
    name: []const u8,
    configuration: Configuration,
    ip: ?[]const u8, // optional
    ssh_user: []const u8,
    ssh_port: ?u16, // extra, optional
    status: []const u8,
    status_details: []const u8, // extra
    cost_estimate: []const u8,
    hourly_price: ?u32,
    launch_configuration: ?LaunchConfiguration = null,
    created_at: []const u8,
    deleted_at: ?[]const u8, // optional
    details: ?struct {} = null,
    ssh_key_id: []const u8, // extra

    pub const Configuration = struct {
        memory_in_gb: u16,
        storage_in_gb: u32,
        vcpus: u16,
        num_gpus: u8,
        gpu_type: []const u8,
        interconnect: []const u8,
        nvlink: bool, // extra
        os: []const u8,
        vram_per_gpu_in_gb: u16,
    };

    pub const LaunchConfiguration = struct {
        type: []const u8,
        docker_configuration: ?struct {
            image: []const u8,
            args: ?[]const u8,
            shared_memory_in_gb: ?u16,
            envs: ?[]struct {
                name: []const u8,
                value: []const u8,
            },
            post_mappings: ?[]struct {
                host_port: u16,
                container_port: u16,
            },
            volume_mounts: ?[]struct {
                host_path: []const u8,
                container_path: []const u8,
            },
        },
        script_configuration: ?struct {
            base64_script: []const u8,
        },
    };
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

    pub fn makeRequest(
        self: *Self,
        method: std.http.Method,
        endpoint: []const u8,
        options: struct { body: ?[]const u8 = null },
    ) !std.http.Client.Request {
        self.uri.path = std.Uri.Component{ .raw = endpoint };
        self._req_opts = std.http.Client.RequestOptions{
            .server_header_buffer = &self._hbuf,
            .extra_headers = self.headers,
        };

        var request = try self.client.open(
            method,
            self.uri,
            self._req_opts,
        );
        errdefer request.deinit();

        const body = options.body orelse &[_]u8{};

        // set content length
        // TODO: RequestTransfer.none may be suitable for empty POSTs
        if (method == .POST)
            request.transfer_encoding = .{ .content_length = body.len };

        try request.send();

        // write body if required
        if (method == .POST) {
            try request.writeAll(body);
        }

        try request.finish();
        try request.wait();

        // var iter = request.response.iterateHeaders();
        // while (iter.next()) |header| {
        //     std.debug.print("Name:{s}, Value:{s}\n", .{
        //         header.name,
        //         header.value,
        //     });
        // }

        return request;
    }

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

    pub fn getInstanceTypes(self: *Self) ![]InstanceType {
        var request = try self.makeRequest(.GET, "/v1/instances/types", .{});

        try std.testing.expectEqual(request.response.status, .ok);

        const T = struct { instance_types: []InstanceType };
        const parsed = try self.parseBodyLeaky(T, &request);

        return parsed.instance_types;
    }

    pub fn getInstances(self: *Self) ![]Instance {
        var request = try self.makeRequest(.GET, "/v1/instances", .{});

        try std.testing.expectEqual(request.response.status, .ok);

        const T = struct { instances: []Instance };
        const parsed = try self.parseBodyLeaky(T, &request);

        return parsed.instances;
    }

    pub fn deleteInstance(self: *Self, instance_id: []const u8) !void {
        var path: [64]u8 = .{0} ** 64;
        _ = try std.fmt.bufPrintZ(
            @as([]u8, &path),
            "/v1/instances/{s}/delete",
            .{instance_id},
        );
        const request = try self.makeRequest(
            .POST,
            std.mem.sliceTo(&path, 0),
            .{},
        );

        try std.testing.expectEqual(.ok, request.response.status);
    }

    pub fn getInstance(self: *Self, instance_id: []const u8) !Instance {
        var path: [64]u8 = .{0} ** 64;
        _ = try std.fmt.bufPrintZ(
            @as([]u8, &path),
            "/v1/instances/{s}/info",
            .{instance_id},
        );
        var request = try self.makeRequest(
            .GET,
            std.mem.sliceTo(&path, 0),
            .{},
        );

        try std.testing.expectEqual(request.response.status, .ok);

        const parsed = try self.parseBodyLeaky(Instance, &request);

        return parsed;
    }

    fn parseBodyLeaky(
        self: *Self,
        comptime T: type,
        request: *std.http.Client.Request,
    ) !T {
        var rdr = request.reader();
        self._bbuf = try rdr.readAllAlloc(self.allocator, body_max_size);
        errdefer self.allocator.free(self._bbuf);

        const parsed = try std.json.parseFromSliceLeaky(
            T,
            self.allocator,
            self._bbuf,
            .{},
        );

        return parsed;
    }
};
