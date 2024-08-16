/// Color with a 4-bit depth for use with various BIOS
/// interrupts.
pub const Bios = enum(u4) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_gray = 7,
    dark_gray = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    yellow = 14,
    white = 15,

    /// Get the bit representation of this color.
    pub inline fn to_bits(self: Bios) u4 {
        return @intFromEnum(self);
    }

    /// Create a color from it's bit representation.
    pub inline fn from_bits(bits: u4) Bios {
        return @enumFromInt(bits);
    }

    /// Stores what colors to use for various BIOS interrupts.
    pub const Style = packed struct(u8) {
        /// Foreground color, all are supported.
        fg: Bios = .white,
        /// Background color, usually only supports 8 of the colors.
        bg: Bios = .black,

        /// Get the bit representation of this style.
        pub inline fn to_bits(self: Style) u8 {
            return @bitCast(self);
        }

        /// Create a bit style from it's bit representation.
        pub inline fn from_bits(bits: u8) Style {
            return @bitCast(bits);
        }
    };
};
