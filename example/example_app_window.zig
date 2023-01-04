const std = @import("std");
const root = @import("root");
const Gtk = root.Gtk;
const core = root.core;
const meta = std.meta;
const assert = std.debug.assert;
const ExampleApp = @import("example_app.zig").ExampleApp;

pub const CstrContext = struct {
    pub fn hash(self: CstrContext, key: [*:0]const u8) u64 {
        _ = self;
        return std.hash.Wyhash.hash(0, key[0..std.mem.indexOfSentinel(u8, 0, key)]);
    }

    pub fn eql(self: CstrContext, a: [*:0]const u8, b: [*:0]const u8) bool {
        _ = self;
        return std.cstr.cmp(a, b) == 0;
    }
};

const Static = struct {
    var type_id: core.GType = core.GType.Invalid;
    var parent_class: ?*Gtk.ApplicationWindowClass = null;
};

pub const ExampleAppWindowClass = extern struct {
    parent: Gtk.ApplicationWindowClass,

    pub fn init(self: *ExampleAppWindowClass) callconv(.C) void {
        Static.parent_class = @ptrCast(*Gtk.ApplicationWindowClass, core.typeClassPeek(Gtk.ApplicationWindow.gType()));
        @ptrCast(*core.ObjectClass, self).dispose = &dispose;
        @ptrCast(*Gtk.WidgetClass, self).setTemplateFromResource("/org/gtk/exampleapp/window.ui");
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("stack", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "stack"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("gears", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "gears"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("search", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "search"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("searchbar", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "searchbar"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("searchentry", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "searchentry"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("sidebar", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "sidebar"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("words", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "words"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("lines", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "lines"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateChildFull("lines_label", core.Boolean.False, @offsetOf(ExampleAppWindowImpl, "lines_label"));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateCallbackFull("search_text_changed", @ptrCast(core.Callback, &searchTextChanged));
        @ptrCast(*Gtk.WidgetClass, self).bindTemplateCallbackFull("visible_child_changed", @ptrCast(core.Callback, &visibleChildChanged));
    }

    pub fn dispose(object: core.Object) callconv(.C) void {
        var win = object.tryInto(ExampleAppWindow).?;
        win.callMethod("dispose", .{});
    }

    pub fn searchTextChanged(entry: Gtk.Entry, win: ExampleAppWindow) callconv(.C) void {
        var text = entry.callMethod("getText", .{});
        if (text[0] == 0) return;
        var tab = win.instance.stack.getVisibleChild().into().?.tryInto(Gtk.ScrolledWindow).?;
        var view = tab.getChild().into().?.tryInto(Gtk.TextView).?;
        var buffer = view.getBuffer();
        var start = buffer.getStartIter();
        var ret = start.forwardSearch(text, .CaseInsensitive, null);
        if (ret.ret.into()) {
            var match_start = ret.match_start;
            var match_end = ret.match_end;
            buffer.selectRange(&match_start, &match_end);
            _ = view.scrollToIter(&match_start, 0, core.Boolean.False, 0, 0);
        }
    }

    pub fn visibleChildChanged(stack: Gtk.Stack, pspec: core.ParamSpec, win: ExampleAppWindow) callconv(.C) void {
        _ = pspec;
        if (stack.callMethod("inDestruction", .{}).into()) return;
        win.instance.searchbar.setSearchMode(core.Boolean.False);
        win.updateWords();
        win.updateLines();
    }
};

const ExampleAppWindowImpl = extern struct {
    parent: Gtk.ApplicationWindow.cType(),
    settings: core.Settings,
    stack: Gtk.Stack,
    gears: Gtk.MenuButton,
    search: Gtk.ToggleButton,
    searchbar: Gtk.SearchBar,
    searchentry: Gtk.SearchEntry,
    sidebar: Gtk.Revealer,
    words: Gtk.ListBox,
    lines: Gtk.Label,
    lines_label: Gtk.Label,
};

pub const ExampleAppWindowNullable = packed struct {
    ptr: ?*ExampleAppWindowImpl,

    pub fn from(that: ?ExampleAppWindow) ExampleAppWindowNullable {
        return .{ .ptr = if (that) |some| some.instance else null };
    }

    pub fn get(self: ExampleAppWindowNullable) ?ExampleAppWindow {
        return if (self.ptr) |some| ExampleAppWindow{ .instance = some } else null;
    }
};

pub const ExampleAppWindow = packed struct {
    instance: *ExampleAppWindowImpl,
    traitGObjectObject: void = {},
    traitGObjectInitiallyUnowned: void = {},
    traitGtkWidget: void = {},
    traitGtkWindow: void = {},
    traitGtkApplicationWindow: void = {},
    traitExampleAppWindow: void = {},

    pub fn init(self: ExampleAppWindow) callconv(.C) void {
        self.callMethod("initTemplate", .{});
        var builder = Gtk.Builder.newFromResource("/org/gtk/exampleapp/gears-menu.ui");
        defer builder.callMethod("unref", .{});
        var menu = builder.getObject("menu").into().?.tryInto(core.MenuModel).?;
        self.instance.gears.setMenuModel(menu.asNullable());
        self.instance.settings = core.Settings.new("org.gtk.exampleapp");
        self.instance.settings.bind("transition", self.instance.stack.into(core.Object), "transition-type", .Default);
        self.instance.settings.bind("show-words", self.instance.sidebar.into(core.Object), "reveal-child", .Default);
        _ = self.instance.search.callMethod("bindProperty", .{ "active", self.instance.searchbar.into(core.Object), "search-mode-enabled", .Bidirectional });
        _ = core.connect(self.instance.sidebar, "notify::reveal-child", updateWords, .{self}, .{ .swapped = true }, .{ void, Gtk.Revealer, core.ParamSpec });
        var action1 = self.instance.settings.createAction("show-words");
        defer core.unsafeCast(core.Object, action1).unref();
        self.callMethod("addAction", .{action1});
        var action2 = core.PropertyAction.new("show-lines", core.upCast(core.Object, self.instance.lines), "visible");
        defer action2.callMethod("unref", .{});
        self.callMethod("addAction", .{core.upCast(core.Action, action2)});
        _ = self.instance.lines.callMethod("bindProperty", .{ "visible", self.instance.lines_label.into(core.Object), "visible", .Default });
    }

    pub fn new(app: ExampleApp) ExampleAppWindow {
        var property_names = [_][*:0]const u8{"application"};
        var property_values = std.mem.zeroes([1]core.Value);
        var application = &property_values[0];
        _ = application.init(core.GType.Object);
        application.setObject(app.into(core.Object).asNullable());
        return core.downCast(ExampleAppWindow, core.newObject(gType(), property_names[0..], property_values[0..])).?;
    }

    pub fn dispose(self: ExampleAppWindow) void {
        self.instance.settings.callMethod("unref", .{});
        const dispose_fn = @ptrCast(*core.ObjectClass, Static.parent_class.?).dispose.?;
        dispose_fn(self.into(core.Object));
    }

    pub fn open(self: ExampleAppWindow, file: core.File) void {
        var basename = file.getBasename().?;
        defer core.freeDiscardConst(basename);
        var scrolled = Gtk.ScrolledWindow.new().tryInto(Gtk.ScrolledWindow).?;
        scrolled.callMethod("setHexpand", .{core.Boolean.True});
        scrolled.callMethod("setVexpand", .{core.Boolean.True});
        var view = Gtk.TextView.new().tryInto(Gtk.TextView).?;
        view.setEditable(core.Boolean.False);
        view.setCursorVisible(core.Boolean.False);
        scrolled.setChild(view.into(Gtk.Widget).asNullable());
        _ = self.instance.stack.addTitled(scrolled.into(Gtk.Widget), basename, basename);
        var buffer = view.getBuffer();
        var result = file.loadContents(core.CancellableNullable.from(null));
        switch (result) {
            .Ok => |ok| {
                defer core.free(ok.contents.ptr);
                defer core.freeDiscardConst(ok.etag_out);
                buffer.setText(@ptrCast([*:0]const u8, ok.contents.ptr), @intCast(i32, ok.contents.len));
            },
            .Err => |err| {
                defer err.free();
                std.log.warn("{s}", .{err.message.?});
                return;
            },
        }
        var tag = Gtk.TextTag.new(null);
        _ = buffer.getTagTable().add(tag);
        self.instance.settings.bind("font", core.upCast(core.Object, tag), "font", .Default);
        var start_iter = buffer.getStartIter();
        var end_iter = buffer.getEndIter();
        buffer.applyTag(tag, &start_iter, &end_iter);
        self.instance.search.callMethod("setSensitive", .{core.Boolean.True});
        self.updateWords();
        self.updateLines();
    }

    fn findWord(button: Gtk.Button, win: ExampleAppWindow) void {
        var word = button.getLabel().?;
        win.instance.searchentry.callMethod("setText", .{word});
    }

    pub fn updateWords(self: ExampleAppWindow) void {
        var tab = if (self.instance.stack.getVisibleChild().into()) |some| some.tryInto(Gtk.ScrolledWindow).? else return;
        var view = tab.getChild().into().?.tryInto(Gtk.TextView).?;
        var buffer = view.getBuffer();
        var start = buffer.getStartIter();
        var end: Gtk.TextIter = undefined;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer {
            if (gpa.deinit()) @panic("");
        }
        const allocator = gpa.allocator();
        var strings = std.HashMap([*:0]const u8, void, CstrContext, std.hash_map.default_max_load_percentage).init(allocator);
        defer {
            var iter = strings.keyIterator();
            while (iter.next()) |some| {
                core.freeDiscardConst(some.*);
            }
            strings.deinit();
        }
        outer: while (!start.isEnd().into()) {
            while (!start.startsWord().into()) {
                if (!start.forwardChar().into()) break :outer;
            }
            end = start;
            if (!end.forwardWordEnd().into()) break :outer;
            var word = buffer.getText(&start, &end, core.Boolean.False);
            defer core.freeDiscardConst(word);
            strings.put(core.utf8Strdown(word, -1), {}) catch @panic("");
            start = end;
        }
        while (true) {
            var child = self.instance.words.callMethod("getFirstChild", .{});
            if (child.into()) |some| {
                self.instance.words.remove(some);
            } else {
                break;
            }
        }
        var iter = strings.keyIterator();
        while (iter.next()) |some| {
            var row = Gtk.Button.newWithLabel(some.*).tryInto(Gtk.Button).?;
            row.signalClicked().connect(findWord, .{self}, .{});
            self.instance.words.insert(row.into(Gtk.Widget), -1);
        }
    }

    pub fn updateLines(self: ExampleAppWindow) void {
        var tab = if (self.instance.stack.getVisibleChild().into()) |some| some.tryInto(Gtk.ScrolledWindow).? else return;
        var view = tab.getChild().into().?.tryInto(Gtk.TextView).?;
        var buffer = view.getBuffer();
        var count = buffer.getLineCount();
        var buf: [22]u8 = undefined;
        _ = std.fmt.bufPrint(buf[0..], "{d}{c}", .{ count, 0 }) catch @panic("");
        self.instance.lines.setText(@ptrCast([*:0]const u8, &buf));
    }

    pub fn CallMethod(comptime method: []const u8) ?type {
        if (std.mem.eql(u8, method, "dispose")) return void;
        if (std.mem.eql(u8, method, "open")) return void;
        if (Gtk.ApplicationWindow.CallMethod(method)) |some| return some;
        return null;
    }

    pub fn callMethod(self: ExampleAppWindow, comptime method: []const u8, args: anytype) gen_return_type: {
        if (CallMethod(method)) |some| {
            break :gen_return_type some;
        } else {
            @compileError(std.fmt.comptimePrintf("No such method {s}", .{method}));
        }
    } {
        if (comptime std.mem.eql(u8, method, "dispose")) {
            return @call(.auto, dispose, .{self} ++ args);
        } else if (comptime std.mem.eql(u8, method, "open")) {
            return @call(.auto, open, .{self} ++ args);
        } else if (Gtk.ApplicationWindow.CallMethod(method)) |_| {
            return core.upCast(Gtk.ApplicationWindow, self).callMethod(method, args);
        } else {
            @compileError("No such method");
        }
    }

    pub fn cType() type {
        return ExampleAppWindowImpl;
    }

    pub fn gType() core.GType {
        if (core.onceInitEnter(&Static.type_id).into()) {
            // zig fmt: off
            var type_id = core.typeRegisterStaticSimple(
                Gtk.ApplicationWindow.gType(),
                "ExampleAppWindow",
                @sizeOf(ExampleAppWindowClass), @ptrCast(core.ClassInitFunc, &ExampleAppWindowClass.init),
                @sizeOf(ExampleAppWindowImpl), @ptrCast(core.InstanceInitFunc, &ExampleAppWindow.init),
                .None
            );
            // zig fmt: on
            defer core.onceInitLeave(&Static.type_id, type_id.value);
        }
        return Static.type_id;
    }

    pub fn isAImpl(comptime T: type) bool {
        return meta.trait.hasField("traitExampleAppWindow")(T);
    }

    pub fn into(self: ExampleAppWindow, comptime T: type) T {
        return core.upCast(T, self);
    }

    pub fn tryInto(self: ExampleAppWindow, comptime T: type) ?T {
        return core.downCast(T, self);
    }

    pub fn asNullable(self: ExampleAppWindow) ExampleAppWindowNullable {
        return .{.ptr = self.instance};
    }
};
