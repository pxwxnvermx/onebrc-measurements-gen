const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();
    var args_iter = try init.minimal.args.iterateAllocator(allocator);
    _ = args_iter.next();
    const num_records = std.fmt.parseInt(u64, args_iter.next().?, 10) catch 10_000;

    const weather_stations_csv_file = try Io.Dir.cwd().openFile(io, "./weather_stations.csv", .{});
    var weather_stations_csv_reader_buf: [6 * 1024]u8 = undefined;
    var weather_stations_csv_reader = weather_stations_csv_file.reader(io, &weather_stations_csv_reader_buf);
    const weather_stations_csv_reader_interface = &weather_stations_csv_reader.interface;

    var weather_stations_all: std.ArrayList([]const u8) = try .initCapacity(allocator, 50_000);

    while (try weather_stations_csv_reader_interface.takeDelimiter('\n')) |line| {
        if (std.mem.startsWith(u8, line, "#")) {
            continue;
        }
        const station_name, _ = std.mem.cutScalar(u8, line, ';').?;

        const dupe_station_name = try allocator.dupe(u8, station_name);
        try weather_stations_all.append(allocator, dupe_station_name);
    }

    var prng: std.Random.DefaultPrng = .init(@intCast(std.Io.Clock.now(.real, io).toMilliseconds()));
    const rand = prng.random();
    rand.shuffle([]const u8, weather_stations_all.items);
    weather_stations_all.shrinkRetainingCapacity(10_000);

    const coldest_temp = -99;
    const hottest_temp = 99;

    const measurements_file = try Io.Dir.cwd().createFile(io, "./measurements.txt", .{});
    var measurements_writer_buf: [6 * 1024]u8 = undefined;
    var measurements_writer = measurements_file.writer(io, &measurements_writer_buf);
    const measurements_writer_interface = &measurements_writer.interface;

    for (0..num_records) |_| {
        const pick = rand.uintAtMost(usize, 10_000 - 1);
        const station_name = weather_stations_all.items[pick];
        var temperature: f32 = @floatFromInt(rand.intRangeAtMost(i32, coldest_temp, hottest_temp));
        temperature += rand.float(f32);
        try measurements_writer_interface.print("{s};{d:.1}\n", .{ station_name, temperature });
    }
    try measurements_writer_interface.flush();
}
