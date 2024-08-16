pub const Color = @import("color").Bios;
pub const Style = Color.Style;

/// Write a string to the teletype output.
pub inline fn write_string(string: [*:0]const u8, style: Style) void {
    _write_string(string, style);
}

/// Enable color output
pub inline fn enable_color() void {
    asm volatile (
        \\ .code16;
        \\ int $0x10
        :
        : [_] "{ax}" (0x0012),
        : "ax"
    );
}

fn _write_string(string: [*:0]const u8, style: Style) void {
    var ptr: [*]const u8 = string;

    while (ptr[0] != 0) : (ptr += 1) {
        write_char(ptr[0], style);
    }
}

/// Write a character to the teletype output.
pub inline fn write_char(ch: u8, style: Style) void {
    asm volatile (
        \\ .code16;
        \\ int $0x10
        :
        : [_] "{ax}" (0x0e00 | @as(u16, ch)),
          [_] "{bx}" (0x0000 | @as(u16, style.to_bits())),
        : "ax", "bx"
    );
}
