const Bus = @import("../bus/bus.zig");
const BusCallback = Bus.BusCallback;

const Envelope = @import("./apu.zig").Envelope;
const LengthCounter = @import("./apu.zig").LengthCounter;
const apu_no_read = @import("./apu.zig").apu_no_read;

const Self = @This();

channel_enabled: bool = true,

timer: u11 = 0,
timer_reset: packed union {
    value: u11,
    bytes: packed struct {
        low: u8 = 0,
        high: u3 = 0
    }
} = .{.value = 0},
linear_counter: struct {
    const LinearCounter = @This();

    counter: u7 = 0,
    reload_value: u7 = 0,
    reload: bool = false,

    pub fn step(self: *LinearCounter) void {
        if (self.reload) {
            self.counter = self.reload_value;
        } else {
            if (self.counter != 0) {
                self.counter -= 1;
            }
        }
        var triangle_channel = @fieldParentPtr(Self, "linear_counter", self);
        if (!triangle_channel.length_counter.halt) {
            self.reload = false;
        }
    }
} = .{},
control: bool = false,
waveform_counter: u5 = 0,
length_counter: LengthCounter = .{},

const sequence = [32]u8{
    15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
};

pub fn step(self: *Self) void {
    if (self.timer == 0) {
        self.timer = self.timer_reset.value;
        if (self.length_counter.counter != 0 and self.linear_counter.counter != 0) {
            self.waveform_counter -%= 1;
        }
    } else {
        self.timer -= 1;
    }
}

pub fn output(self: *Self) u8 {
    if (!self.channel_enabled or self.length_counter.counter == 0 or 
        self.linear_counter.counter == 0 or self.timer_reset.value < 2) {
            return 0;
    }
    return sequence[self.waveform_counter];
}

fn linearCounterWrite(self: *Self, bus: *Bus, address: u16, value: u8) void {
    _ = bus;
    _ = address;
    const data: packed union {
        value: u8,
        bits: packed struct {
            counter_reload: u7,
            c: bool
        }
    } = .{.value = value};

    self.linear_counter.reload_value = data.bits.counter_reload;
    self.length_counter.halt = data.bits.c;
}

fn timerLowRegisterWrite(self: *Self, bus: *Bus, address: u16, value: u8) void {
    _ = bus;
    _ = address;
    self.timer_reset.bytes.low = value;
}

fn fourthRegisterWrite(self: *Self, bus: *Bus, address: u16, value: u8) void {
    _ = bus;
    _ = address;
    const data: packed union {
        value: u8,
        bits: packed struct {
            timer_high: u3,
            l: u5
        }
    } = .{.value = value};
    self.timer_reset.bytes.high = data.bits.timer_high;
    if (self.channel_enabled) {
        self.length_counter.load(data.bits.l);
    }
    self.linear_counter.reload = true;
}

pub fn busCallbacks(self: *Self) [4]BusCallback {
    return [_]BusCallback{
        BusCallback.init(
            self, 
            apu_no_read(Self, "Triangle Linear Counter"), 
            Self.linearCounterWrite
        ), // $4008
        BusCallback.init(
            self, 
            apu_no_read(Self, "Triangle Unused"), 
            BusCallback.noWrite(Self, "Triangle Unused", false)
        ), // $4009
        BusCallback.init(
            self, 
            apu_no_read(Self, "Triangle Timer Low"), 
            Self.timerLowRegisterWrite
        ), // $400A
        BusCallback.init(
            self, 
            apu_no_read(Self, "Triangle Fourth"), 
            Self.fourthRegisterWrite
        ), // $400B
    };
}