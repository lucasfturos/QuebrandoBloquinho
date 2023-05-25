const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const RndGen = std.rand.DefaultPrng;
const math = std.math;

const FPS: i32 = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @intToFloat(f32, FPS);
const WINDOW_WIDTH: i32 = 1000;
const WINDOW_HEIGHT: i32 = 600;
const PROJ_SIZE: f32 = 25;
const PROJ_SPEED: f32 = 500;
const BAR_LEN: f32 = 100;
const BAR_THICCNESS: f32 = PROJ_SIZE;
const BAR_SPEED: f32 = PROJ_SPEED;
const TARGET_WIDTH = BAR_LEN;
const TARGET_HEIGHT = BAR_THICCNESS;
const TARGET_PADDING = 20;
const TARGETS_CAP = 128;

const Target = struct { x: f32, y: f32, dead: bool = false };

const Point = struct { x: f32, y: f32 };

var targets_pool = [_]Target{
    // Primeira linha
    Target{ .x = 100, .y = 100 - TARGET_HEIGHT - TARGET_PADDING },
    Target{ .x = 100 + TARGET_WIDTH + TARGET_PADDING, .y = 100 - TARGET_HEIGHT - TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 2, .y = 100 - TARGET_HEIGHT - TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 3, .y = 100 - TARGET_HEIGHT - TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 4, .y = 100 - TARGET_HEIGHT - TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 5, .y = 100 - TARGET_HEIGHT - TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 6, .y = 100 - TARGET_HEIGHT - TARGET_PADDING },
    // Segunda linha
    Target{ .x = 100, .y = 100 },
    Target{ .x = 100 + TARGET_WIDTH + TARGET_PADDING, .y = 100 },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 2, .y = 100 },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 3, .y = 100 },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 4, .y = 100 },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 5, .y = 100 },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 6, .y = 100 },
    // Terceira linha
    Target{ .x = 100, .y = 100 + TARGET_HEIGHT + TARGET_PADDING },
    Target{ .x = 100 + TARGET_WIDTH + TARGET_PADDING, .y = 100 + TARGET_HEIGHT + TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 2, .y = 100 + TARGET_HEIGHT + TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 3, .y = 100 + TARGET_HEIGHT + TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 4, .y = 100 + TARGET_HEIGHT + TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 5, .y = 100 + TARGET_HEIGHT + TARGET_PADDING },
    Target{ .x = 100 + (TARGET_WIDTH + TARGET_PADDING) * 6, .y = 100 + TARGET_HEIGHT + TARGET_PADDING },
};

var targets_pool_count = 0;
var pause: bool = false;

var bar_p = Point{ .x = @intToFloat(f32, WINDOW_WIDTH) / 2 - BAR_LEN / 2, .y = @intToFloat(f32, WINDOW_HEIGHT) - BAR_THICCNESS - 100 };
var bar_d = Point{ .x = 0, .y = 0 };
var proj_p = Point{ .x = 0, .y = 0 };
var proj_pd = Point{ .x = 1, .y = 1 };
var started = false;

fn init_var() void {
    proj_p.x = @intToFloat(f32, WINDOW_WIDTH) / 2 - PROJ_SIZE / 2;
    proj_p.y = bar_p.y - BAR_THICCNESS / 2 - PROJ_SIZE;
}

fn make_rect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return c.SDL_Rect{ .x = @floatToInt(i32, x), .y = @floatToInt(i32, y), .w = @floatToInt(i32, w), .h = @floatToInt(i32, h) };
}

fn proj_rect(x: f32, y: f32) c.SDL_Rect {
    return make_rect(x, y, PROJ_SIZE, PROJ_SIZE);
}

fn bar_rect() c.SDL_Rect {
    return make_rect(bar_p.x, bar_p.y - BAR_THICCNESS / 2, BAR_LEN, BAR_THICCNESS);
}

fn target_rect(target: Target) c.SDL_Rect {
    return make_rect(target.x, target.y, TARGET_WIDTH, TARGET_HEIGHT);
}

fn render(renderer: *c.SDL_Renderer) void {
    var rnd = RndGen.init(0);
    _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
    _ = c.SDL_RenderFillRect(renderer, &proj_rect(proj_p.x, proj_p.y));

    _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0, 0, 0xFF);
    _ = c.SDL_RenderFillRect(renderer, &bar_rect());

    for (targets_pool) |target| {
        if (!target.dead) {
            _ = c.SDL_SetRenderDrawColor(renderer, @mod(rnd.random().int(u8), 255), @mod(rnd.random().int(u8), 255), @mod(rnd.random().int(u8), 255), @mod(rnd.random().int(u8), 255));
            _ = c.SDL_RenderFillRect(renderer, &target_rect(target));
        }
    }
}

fn update(dt: f32) void {
    if (!pause and started) {
        bar_p.x = math.clamp(bar_p.x + bar_d.x * BAR_SPEED * dt, 0, @intToFloat(f32, WINDOW_WIDTH) - BAR_LEN);

        var proj_nx = proj_p.x + proj_pd.x * PROJ_SPEED * dt;
        var cond_x = proj_nx < 0 or proj_nx + PROJ_SIZE > WINDOW_WIDTH or c.SDL_HasIntersection(&proj_rect(proj_nx, proj_p.y), &bar_rect()) != 0;

        for (&targets_pool) |*target| {
            if (cond_x) {
                break;
            }
            if (!target.dead) {
                cond_x = cond_x or c.SDL_HasIntersection(&proj_rect(proj_nx, proj_p.y), &target_rect(target.*)) != 0;
                if (cond_x) {
                    target.dead = true;
                }
            }
        }

        if (cond_x) {
            proj_pd.x *= -1;
            proj_nx = proj_p.x + proj_pd.x * PROJ_SPEED * dt;
        }
        proj_p.x = proj_nx;

        var proj_ny = proj_p.y + proj_pd.y * PROJ_SPEED * dt;
        var cond_y = proj_ny < 0 or proj_ny + PROJ_SIZE > WINDOW_HEIGHT;
        if (!cond_y) {
            cond_y = cond_y or c.SDL_HasIntersection(&proj_rect(proj_p.x, proj_ny), &bar_rect()) != 0;
            if (cond_y and bar_d.x != 0) {
                proj_pd.x = bar_d.x;
            }
        }
        for (&targets_pool) |*target| {
            if (cond_y) {
                break;
            }
            if (!target.dead) {
                cond_y = cond_y or c.SDL_HasIntersection(&proj_rect(proj_p.x, proj_ny), &target_rect(target.*)) != 0;
                if (cond_y) {
                    target.dead = true;
                }
            }
        }

        if (cond_y) {
            proj_pd.y *= -1;
            proj_ny = proj_p.y + proj_pd.y * PROJ_SPEED * dt;
        }
        proj_p.y = proj_ny;
    }
}

pub fn main() !void {
    init_var();

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Quebrando Bloquinhos", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const keyboard = c.SDL_GetKeyboardState(null);

    var quit: bool = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        'a' => {
                            bar_p.x -= 10;
                        },
                        'd' => {
                            bar_p.x += 10;
                        },
                        ' ' => {
                            pause = !pause;
                        },
                        'q' => {
                            quit = true;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        bar_d.x = 0;
        if (keyboard[c.SDL_SCANCODE_A] != 0) {
            bar_d.x += -1;
            if (!started) {
                proj_pd.x = -1;
                started = true;
            }
        }
        if (keyboard[c.SDL_SCANCODE_D] != 0) {
            bar_d.x += 1;
            if (!started) {
                proj_pd.y = -1;
                started = true;
            }
        }

        update(DELTA_TIME_SEC);

        _ = c.SDL_SetRenderDrawColor(renderer, 0x18, 0x18, 0x18, 0xFF);
        _ = c.SDL_RenderClear(renderer);

        render(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000 / FPS);
    }
}
