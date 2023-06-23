const std = @import("std");
const page_allocator = std.heap.page_allocator;
const c = @cImport({
    @cInclude("SDL.h");
});

const CPU = @import("./cpu.zig").CPU;
const Bus = @import("./bus.zig").Bus;

const Ram = @import("./ram.zig").Ram;
const MemoryMirror = @import("./memory_mirror.zig").MemoryMirror;
const Rom = @import("./rom.zig").Rom;

pub fn main() !void {
    var bus = Bus.init(null);
    var cpu = try CPU("ZigNES.log").init(&bus);
    defer cpu.deinit();
    // TODO: Add PPU
    // var ppu = PPU.init(&bus);
    
    var cpu_ram = Ram(0x800).init();
    var cpu_ram_mirrors = MemoryMirror(0x0000, 0x0800){};

    // TODO: Add PPU registers
    // ppu_registers_bc = ppu.registers.busCallback();

    var ppu_registers_mirrors = MemoryMirror(0x2000, 0x2008){};

    var snake_rom = Rom.init(page_allocator);
    try snake_rom.load("./test-files/snake.nes");

    bus.set_callbacks(cpu_ram.busCallback(), 0x0000, 0x0800);
    bus.set_callbacks(cpu_ram_mirrors.busCallback(), 0x0800, 0x2000);
    bus.set_callbacks(ppu_registers_mirrors.busCallback(), 0x2008, 0x4000);
    bus.set_callbacks(snake_rom.prg_rom.busCallback(), 0x8000, 0x10000);

    var prg_rom_mirrors = MemoryMirror(0x8000, 0xC000){};

    if (snake_rom.prg_rom.array.items.len <= 0x4000) {
        bus.set_callbacks(prg_rom_mirrors.busCallback(), 0xC000, 0x10000);
    } 

    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    // var window = c.SDL_CreateWindow("ZigNES", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 256, 240, 0);
    var window = c.SDL_CreateWindow("ZigNES", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 32*10, 32*10, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);

    const scale = 4;
    _ = c.SDL_RenderSetScale(renderer, scale, scale);

    var texture = c.SDL_CreateTexture(
        renderer, 
        c.SDL_PIXELFORMAT_RGB24, 
        c.SDL_TEXTUREACCESS_STREAMING, 
        256, 
        240
    );

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_KEYDOWN => {
                    switch (sdl_event.key.keysym.sym) {
                        c.SDLK_w, c.SDLK_UP => {},
                        c.SDLK_a, c.SDLK_LEFT => {},
                        c.SDLK_s, c.SDLK_DOWN => {},
                        c.SDLK_d, c.SDLK_RIGHT => {},
                        else => {}
                    }
                },
                else => {},
            }
        }

        cpu.step();

        // _ = c.SDL_UpdateTexture(texture, null, mapped_screen.data(), 32*3);
        _ = c.SDL_RenderCopy(renderer, texture, null, null);
        c.SDL_RenderPresent(renderer);
    }
}
