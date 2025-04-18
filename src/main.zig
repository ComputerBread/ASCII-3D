const std = @import("std");

const NB_COLS = 206;
const NB_ROWS = 48;

var screen: [NB_ROWS][NB_COLS]u8 = .{.{' '} ** NB_COLS} ** NB_ROWS;
const cleared_screen: [NB_ROWS][NB_COLS]u8 = .{.{' '} ** NB_COLS} ** NB_ROWS;
var buffer: [3 + NB_ROWS * (NB_COLS + 1)]u8 = undefined;

const cube_vertices: [8]Vec3 = .{
    Vec3{ .x = -1, .y = -1, .z = -1 }, // 0
    Vec3{ .x = -1, .y = 1, .z = -1 }, // 1
    Vec3{ .x = 1, .y = 1, .z = -1 }, // 2
    Vec3{ .x = 1, .y = -1, .z = -1 }, // 3
    Vec3{ .x = 1, .y = 1, .z = 1 }, // 4
    Vec3{ .x = 1, .y = -1, .z = 1 }, // 5
    Vec3{ .x = -1, .y = -1, .z = 1 }, // 6
    Vec3{ .x = -1, .y = 1, .z = 1 }, // 7
};

const cube_faces: [12][3]u8 = .{
    // front
    .{ 0, 1, 2 },
    .{ 0, 2, 3 },
    // right
    .{ 3, 2, 4 },
    .{ 3, 4, 5 },
    // back
    .{ 5, 4, 7 },
    .{ 5, 7, 6 },
    // left
    .{ 6, 7, 1 },
    .{ 6, 1, 0 },
    // top
    .{ 6, 0, 3 },
    .{ 6, 3, 5 },
    // bottom
    .{ 1, 7, 4 },
    .{ 1, 4, 2 },
};

const symbols = "$$**++--@@==";
fn drawCube(rx: f32, ry: f32, rz: f32) void {
    const camera_v = Vec3{ .x = 0, .y = 0, .z = -1 };
    for (cube_faces, 0..) |face, m| {
        var vertices: [3]Vec3 = undefined;
        for (face, 0..) |vertex_i, i| {
            // rotate
            var v = cube_vertices[vertex_i];
            v = rotateAroundX(v, rx);
            v = rotateAroundY(v, ry);
            v = rotateAroundZ(v, rz);

            // scale
            const scale = 60;
            v = Vec3{ .x = v.x * scale * 3, .y = v.y * scale, .z = v.z };
            // push inside screen
            v.z += 8;
            vertices[i] = v;
        }
        // cull back
        const v_01 = Vec3{ .x = vertices[1].x - vertices[0].x, .y = vertices[1].y - vertices[0].y, .z = vertices[1].z - vertices[0].z };
        const v_02 = Vec3{ .x = vertices[2].x - vertices[0].x, .y = vertices[2].y - vertices[0].y, .z = vertices[2].z - vertices[0].z };
        const normal = cross_product(v_01, v_02);
        const dot_prod = dot_product(normal, camera_v);
        if (dot_prod <= 0) {
            continue;
        }
        // _ = camera_v;
        var projected_v: [3]Vec2 = undefined;
        for (vertices, 0..) |vertex, i| {
            projected_v[i] = project(vertex);
        }
        // _ = m;

        drawTriangle(projected_v[0], projected_v[1], projected_v[2], symbols[m]);
    }
}

pub fn clear_screen() void {
    screen = cleared_screen;
}

pub fn display_screen(writer: std.fs.File.Writer) !void {
    for (0..NB_ROWS) |i| {
        const offset = 3 + i * (NB_COLS + 1);
        @memcpy(buffer[offset .. offset + NB_COLS], &screen[i]);
        buffer[offset + NB_COLS] = '\n';
    }
    try writer.writeAll(&buffer);
}

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

fn rotateAroundX(v: Vec3, angle_rad: f32) Vec3 {
    return Vec3{
        .x = v.x,
        .y = @cos(angle_rad) * v.y - @sin(angle_rad) * v.z,
        .z = @sin(angle_rad) * v.y + @cos(angle_rad) * v.z,
    };
}
fn rotateAroundY(v: Vec3, angle_rad: f32) Vec3 {
    return Vec3{
        .x = @cos(angle_rad) * v.x + @sin(angle_rad) * v.z,
        .y = v.y,
        .z = -@sin(angle_rad) * v.x + @cos(angle_rad) * v.z,
    };
}
fn rotateAroundZ(v: Vec3, angle_rad: f32) Vec3 {
    return Vec3{
        .x = @cos(angle_rad) * v.x - @sin(angle_rad) * v.y,
        .y = @sin(angle_rad) * v.x + @cos(angle_rad) * v.y,
        .z = v.z,
    };
}

fn cross_product(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}
fn dot_product(a: Vec3, b: Vec3) f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

const Vec2 = struct {
    x: f32,
    y: f32,
};

fn project(v: Vec3) Vec2 {
    return Vec2{
        .x = @round(v.x / v.z + NB_COLS / 2),
        .y = @round(v.y / v.z + NB_ROWS / 2),
    };
}

fn drawTriangle(vec0: Vec2, vec1: Vec2, vec2: Vec2, symbol: u8) void {
    var v0 = vec0;
    var v1 = vec1;
    var v2 = vec2;
    // sort vertices
    if (v0.y > v1.y) {
        const tmp = v0;
        v0 = v1;
        v1 = tmp;
    }
    // here v1 > v0, v2 ?
    if (v1.y > v2.y) {
        const tmp = v2;
        v2 = v1;
        v1 = tmp;
    }
    if (v0.y > v1.y) {
        const tmp = v0;
        v0 = v1;
        v1 = tmp;
    }

    if (v2.y == v1.y) {
        drawFlatBottom(v0, v1, v2, symbol);
        return;
    }
    if (v1.y == v0.y) {
        drawFlatTop(v0, v1, v2, symbol);
        return;
    }

    // brother, working with usize is annoying af
    const midpoint_x = v0.x + @divFloor((v2.x - v0.x) * (v1.y - v0.y), (v2.y - v0.y));
    // find midpoint
    const midpoint = Vec2{
        .x = midpoint_x, // maybe a problem here?
        .y = v1.y,
    };

    drawFlatBottom(v0, v1, midpoint, symbol);
    drawFlatTop(v1, midpoint, v2, symbol);
}

fn drawFlatTop(t1: Vec2, t2: Vec2, b: Vec2, symbol: u8) void {
    // x_inc will have opposite signs, t1, t2 don't need to be ordered properly!!!
    const x_inc_1: f32 = (b.x - t1.x) / (b.y - t1.y);
    const x_inc_2: f32 = (b.x - t2.x) / (b.y - t2.y);

    // if (t1.y < 0 or t1.y > NB_ROWS or b.y < 0 or b.y > NB_ROWS) return;
    const y_start: usize = @intFromFloat(t1.y);
    const y_stop: usize = @intFromFloat(b.y + 1);

    var x_start: f32 = t1.x;
    var x_stop: f32 = t2.x;

    for (y_start..y_stop) |y| {
        drawScanLine(y, @intFromFloat(@round(x_start)), @intFromFloat(@round(x_stop)), symbol);
        x_start += x_inc_1;
        x_stop += x_inc_2;
    }
}

fn drawFlatBottom(t: Vec2, b1: Vec2, b2: Vec2, symbol: u8) void {
    const x_dec_1: f32 = (t.x - b1.x) / (b1.y - t.y);
    const x_dec_2: f32 = (t.x - b2.x) / (b2.y - t.y);

    const y_start: usize = @intFromFloat(t.y);
    const y_stop: usize = @intFromFloat(b1.y + 1);

    var x_start: f32 = t.x;
    var x_stop: f32 = t.x;

    for (y_start..y_stop) |y| {
        drawScanLine(y, @intFromFloat(@round(x_start)), @intFromFloat(@round(x_stop)), symbol);
        x_start -= x_dec_1;
        x_stop -= x_dec_2;
    }
}

fn drawScanLine(y: usize, x0: usize, x1: usize, symbol: u8) void {
    var left = x0;
    var right = x1;
    if (x0 > x1) {
        left = x1;
        right = x0;
    }

    for (left..right + 1) |x| {
        screen[y][x] = symbol;
    }
}

// ----------------------------------------------------------------------------
// ---- questionable time stuff -----------------------------------------------
// ----------------------------------------------------------------------------
var target_delta_time_ns: i128 = 33_333_333;
var prev_time_ns: i128 = undefined;

fn setTargetFPS(fps: i128) void {
    prev_time_ns = std.time.nanoTimestamp();
    target_delta_time_ns = @divTrunc(@as(i128, 1e9), fps); // 1e9/fps;
}

fn getDeltaTime() f32 {
    const now = std.time.nanoTimestamp();
    const delta_t_ns = now - prev_time_ns;
    prev_time_ns = now;
    const sleep_time = target_delta_time_ns - delta_t_ns;
    if (sleep_time > 0) {
        std.time.sleep(@intCast(sleep_time));
    } else {
        return @as(f32, @floatFromInt(delta_t_ns)) * @as(f32, 1e-9);
    }
    return @as(f32, @floatFromInt(target_delta_time_ns)) * @as(f32, 1e-9);
}

pub fn main() !void {
    setTargetFPS(240);
    const stdout = std.io.getStdOut().writer();
    // Clear screen and hide cursor at the start
    try stdout.writeAll("\x1B[2J\x1B[H\x1B[?25l");
    defer stdout.writeAll("\x1B[?25h") catch {}; // Show cursor when done (actually useless, cause we're exiting of the program with SIGINT)

    // Set the cursor positioning sequence at the start of the buffer
    buffer[0] = '\x1B';
    buffer[1] = '[';
    buffer[2] = 'H';
    var rx: f32 = 0;
    var ry: f32 = 0;
    var rz: f32 = 0;
    while (true) {
        const delta_time = getDeltaTime();
        clear_screen();
        drawCube(rx, ry, rz);
        // drawTriangle(.{ .x = 2, .y = 30 }, .{ .x = 10, .y = 5 }, .{ .x = 20, .y = 30 }, 'o');
        // drawTriangle(.{ .x = 22, .y = 20 }, .{ .x = 30, .y = 5 }, .{ .x = 38, .y = 40 }, 'o');
        // drawTriangle(.{ .x = 40, .y = 40 }, .{ .x = 50, .y = 5 }, .{ .x = 65, .y = 30 }, 'a');
        // drawTriangle(.{ .x = 70, .y = 5 }, .{ .x = 70, .y = 30 }, .{ .x = 80, .y = 30 }, 'o');
        // drawTriangle(.{ .x = 82, .y = 30 }, .{ .x = 95, .y = 30 }, .{ .x = 95, .y = 5 }, 'o');
        // drawTriangle(.{ .x = 100, .y = 5 }, .{ .x = 110, .y = 30 }, .{ .x = 120, .y = 5 }, 'o');
        // drawTriangle(.{ .x = 125, .y = 20 }, .{ .x = 140, .y = 5 }, .{ .x = 140, .y = 40 }, 'o');
        // drawTriangle(.{ .x = 145, .y = 5 }, .{ .x = 145, .y = 40 }, .{ .x = 160, .y = 20 }, 'o');
        try display_screen(stdout);
        rx = @mod((rx + 0.8 * delta_time), (2 * std.math.pi));
        ry = @mod((ry + 0.8 * delta_time), (2 * std.math.pi));
        rz = @mod((rz + 0.8 * delta_time), (2 * std.math.pi));
        std.debug.print("delta_time: {d:1.9}", .{delta_time});
    }
}
