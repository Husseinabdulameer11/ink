<?
/*
 * Ink - a small web framework for Quill, in the spirit of Laravel.
 *
 * Install it with the Quill package manager, in a project folder:
 *
 *     quill pkg require husseinabdulameer11/ink
 *
 * or start a whole app from the Inkwell template:
 *
 *     quill pkg create-project husseinabdulameer11/inkwell myblog
 *
 * An Ink app is a Quill site served with a router page:
 *
 *     quill serve mysite --router index.ql
 *
 *     mysite/
 *       index.ql              ink = require("/_vendor/autoload.ql")("ink"); ink.boot(...); routes; ink.run()
 *       style.css ...         plain files are served as they are
 *       quill.json            the packages the app needs
 *       _vendor/              installed packages, Ink among them
 *       _app/config.ql        returns the settings
 *       _app/migrations/      001_users.ql ... each returns SQL, or a function (db)
 *       _app/views/           views; layouts in views/layouts/, error pages in views/errors/
 *       _data/                the SQLite database
 *
 * What it gives you:
 *   routing     ink.get("/posts/{id}", handler, {name: "posts.show", middleware: ["auth"]})
 *               ink.group({prefix: "/admin", middleware: ["auth"]}, function () { ... })
 *   requests    handler(req, id): req.input("title"), req.all(), req.method, req.path ...
 *   responses   return a string (HTML), a map or list (JSON), or ink.view(), ink.redirect(),
 *               ink.json(), ink.back(); .with("message", "Saved") flashes a message
 *   views       ink.view("posts/show", {post: p}); in a view: ink.layout("app", {title: ..})
 *   database    ink.table("posts").where("id", 3).first(), ink.model("posts", {...})
 *   migrations  run once each, in name order, when the app boots
 *   validation  data = ink.validate(req.all(), {title: "required|min:3|max:120"})
 *   sessions    ink.session().put("key", value), flash messages, old form input
 *   security    CSRF tokens on every form, hashed passwords, ink.auth.attempt(email, pw)
 *   errors      ink.abort(404); exceptions become error pages (details when debug is on)
 */

VERSION = "0.1.0";
NONE = ["<ink: argument not given>"];        // tells "not passed" from null
OPS = ["=", "!=", "<", ">", "<=", ">=", "LIKE", "NOT LIKE"];
WRITES = ["POST", "PUT", "PATCH", "DELETE"];

config = {
    name: "Ink app",
    debug: false,
    database: "_data/app.db",
    app_dir: "/_app",
    login_url: "/login",
    home_url: "/",
    session_days: 30,
    csrf_except: ["/api/"],
};
db = null;
routes = [];
named = {};
group_stack = [];
middleware_map = {};
global_middleware = [];
layout_request = null;
current_req = null;
current_user = null;
session = null;
shared = {};

// ---- small helpers -------------------------------------------------------

function is_ident(s) {
    if (type(s) != "string" || s == "" || len(s) > 64) { return false; }
    for (c in s) {
        ok = (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_" || c == ".";
        if (!ok) { return false; }
    }
    return !starts(s, ".") && !ends(s, ".");
}

// Table and column names cannot be SQL parameters, so they are checked here:
// letters, digits, _ and one dot (table.column). Values always go in as ?.
function ident(s, what = "name") {
    if (!is_ident(s)) { throw {status: 500, message: "Ink: \"" + str(s) + "\" is not a valid " + what}; }
    return s;
}

function merge(a, b) {
    out = {};
    for (k, v in a ?? {}) { out[k] = v; }
    for (k, v in b ?? {}) { out[k] = v; }
    return out;
}

function without(m, names) {
    out = {};
    for (k, v in m ?? {}) {
        if (!contains(names, k)) { out[k] = v; }
    }
    return out;
}

function abort(code, message = null) {
    throw {status: code, message: message ?? status_text(code)};
}

function status_text(code) {
    texts = {
        "400": "Bad request", "401": "Please log in first", "403": "You are not allowed to do that",
        "404": "Page not found", "405": "That method is not allowed here",
        "419": "This form has expired. Go back, reload the page and try again.",
        "422": "The given data was invalid", "500": "Something went wrong on our side",
    };
    return texts[str(code)] ?? "Error " + code;
}

// ---- responses -----------------------------------------------------------

function response(body = "", code = 200, headers = {}) {
    r = {ink_response: true, status: code, headers: headers, body: body};
    // ink.redirect("/").with("message", "Saved") flashes a message for the next page
    r.with = function (key, value) { session.flash(key, value); return r; };
    r.header = function (name, value) { r.headers[name] = value; return r; };
    return r;
}

function json_response(data, code = 200) {
    return response(json(data), code, {"Content-Type": "application/json"});
}

function redirect_to(to, code = 302) {
    return response("", code, {Location: to});
}

// a path on this site, never somewhere else
function local_path(p, fallback = "/") {
    if (type(p) != "string" || !starts(p, "/") || starts(p, "//") || contains(p, "\\")) { return fallback; }
    return p;
}

function back(req, fallback = "/") {
    ref = req.header("referer", "");
    at = find(ref, "://");
    if (at >= 0) {
        rest = substr(ref, at + 3);
        slash = find(rest, "/");
        ref = slash >= 0 ? substr(rest, slash) : "/";
    }
    return redirect_to(local_path(ref, fallback));
}

function to_response(x) {
    if (type(x) == "map" && (x.ink_response ?? false)) { return x; }
    if (type(x) == "string") { return response(x); }
    if (x == null) { return response("", 204); }
    if (type(x) == "map" || type(x) == "list") { return json_response(x); }
    return response(str(x));
}

// ---- views ---------------------------------------------------------------

function view_vars() {
    return {
        ink: M,
        request: current_req,
        user: current_user,
        errors: session ? (session.flashed("errors") ?? {}) : {},
        notice: session ? session.flashed("message") : null,     // set with .with("message", ...)
    };
}

function render_view(name, data = {}) {
    vars = merge(merge(shared, view_vars()), data);
    saved = layout_request;
    layout_request = null;
    html = render(config.app_dir + "/views/" + name + ".ql", vars);
    // a view may ask to be put inside a layout: ink.layout("app", {title: ...})
    while (layout_request) {
        wanted = layout_request;
        layout_request = null;
        lvars = merge(merge(vars, wanted.data), {content: html});
        html = render(config.app_dir + "/views/layouts/" + wanted.name + ".ql", lvars);
    }
    layout_request = saved;
    return html;
}

function view(name, data = {}, code = 200) { return response(render_view(name, data), code); }

function partial(name, data = {}) {
    return render(config.app_dir + "/views/" + name + ".ql", merge(merge(shared, view_vars()), data));
}

function layout(name, data = {}) { layout_request = {name: name, data: data}; }

// ---- routing ---------------------------------------------------------------

function segments(p) {
    t = trim(p, "/");
    return t == "" ? [] : split(t, "/");
}

function add_route(methods, path, handler, opts = {}) {
    prefix = "";
    mws = [];
    for (g in group_stack) {
        prefix += g.prefix ?? "";
        mws = mws + (g.middleware ?? []);
    }
    full = "/" + trim(trim(prefix, "/") + "/" + trim(path, "/"), "/");
    if (type(handler) != "function") { throw {status: 500, message: "Ink: the route " + full + " needs a function"}; }
    r = {methods: methods, path: full, segs: segments(full), handler: handler,
         name: opts.name ?? null, middleware: mws + (opts.middleware ?? [])};
    push(routes, r);
    if (r.name) { named[r.name] = full; }
    return r;
}

function group(opts, body) {
    push(group_stack, opts);
    try { body(); } catch (e) { pop(group_stack); throw e; }
    pop(group_stack);
}

// "/posts/{id}" against "/posts/7" -> {id: "7"}; null when it does not fit
function match_segs(pattern, segs) {
    params = {};
    if (len(segs) > len(pattern)) { return null; }
    for (i, p in pattern) {
        if (starts(p, "{") && ends(p, "}")) {
            pname = substr(p, 1, len(p) - 2);
            optional = ends(pname, "?");
            if (optional) { pname = substr(pname, 0, len(pname) - 1); }
            if (i < len(segs)) { params[pname] = segs[i]; }
            elseif (optional) { params[pname] = null; }
            else { return null; }
        } elseif (i >= len(segs) || p != segs[i]) {
            return null;
        }
    }
    return params;
}

function match_route(method, path) {
    segs = segments(path);
    other_methods = false;
    for (r in routes) {
        params = match_segs(r.segs, segs);
        if (params == null) { continue; }
        if (contains(r.methods, method) || (method == "HEAD" && contains(r.methods, "GET"))) {
            return {route: r, params: params};
        }
        other_methods = true;
    }
    abort(other_methods ? 405 : 404);
}

// url("posts.show", {id: 3}) -> "/posts/3"; extra values become ?query
function route_url(rname, params = {}) {
    pattern = named[rname] ?? null;
    if (pattern == null) { throw {status: 500, message: "Ink: no route is named \"" + rname + "\""}; }
    used = [];
    parts = [];
    for (seg in segments(pattern)) {
        if (starts(seg, "{")) {
            pname = trim(seg, "{}?");
            v = params[pname] ?? null;
            if (v == null) {
                if (ends(seg, "?}")) { continue; }
                throw {status: 500, message: "Ink: route \"" + rname + "\" needs " + pname};
            }
            push(used, pname);
            push(parts, url(str(v)));
        } else {
            push(parts, seg);
        }
    }
    out = "/" + join(parts, "/");
    extra = [];
    for (k, v in params) {
        if (!contains(used, k) && v != null) { push(extra, url(k) + "=" + url(str(v))); }
    }
    return extra ? out + "?" + join(extra, "&") : out;
}

// ---- middleware ----------------------------------------------------------
// A middleware is function (req, next) that returns a response, usually
// next(req). Register named ones with ink.middleware("name", fn).

function wrap(mw, inner) {
    return fn (r) => to_response(mw(r, inner));
}

function pipeline(mws, final_handler) {
    h = final_handler;
    for (i in range(len(mws) - 1, -1, -1)) {
        mw = mws[i];
        if (type(mw) == "string") {
            found = middleware_map[mw] ?? null;
            if (found == null) { throw {status: 500, message: "Ink: no middleware named \"" + mw + "\""}; }
            mw = found;
        }
        h = wrap(mw, h);
    }
    return h;
}

function call_handler(handler, req, params) {
    args = [req] + values(params);
    n = arity(handler);
    if (n >= 0 && len(args) > n) { args = slice(args, 0, n); }    // a handler may skip parameters
    return to_response(apply(handler, args));
}

function make_final(handler, params) {
    return fn (r) => call_handler(handler, r, params);
}

function mw_csrf(req, next) {
    if (contains(WRITES, req.method)) {
        exempt = false;
        for (p in config.csrf_except) { if (starts(req.path, p)) { exempt = true; } }
        sent = req.input("_token", req.header("x-csrf-token", ""));
        if (!exempt && sent != session.token()) { abort(419); }
    }
    return next(req);
}

function mw_auth(req, next) {
    if (!current_user) {
        if (req.wants_json()) { abort(401); }
        if (req.method == "GET") { session.put("intended", req.path + (req.query_string ? "?" + req.query_string : "")); }
        return redirect_to(config.login_url);
    }
    return next(req);
}

function mw_guest(req, next) {
    if (current_user) { return redirect_to(config.home_url); }
    return next(req);
}

// ---- requests --------------------------------------------------------------

function make_request() {
    input = {};
    for (k, v in get) { input[k] = v; }
    if (type(post) == "map") { for (k, v in post) { input[k] = v; } }
    method = request.method;
    // HTML forms can only GET and POST; a hidden _method field says PUT or DELETE
    if (method == "POST" && type(input["_method"] ?? null) == "string") {
        wanted = upper(input["_method"]);
        if (contains(["PUT", "PATCH", "DELETE"], wanted)) { method = wanted; }
    }
    req = {
        method: method, path: request.path, query: get, query_string: request.query,
        params: {}, headers: request.headers, cookies: cookies, ip: request.ip, body: request.body,
    };
    req.input = fn (k, d = null) => input[k] ?? d;
    req.all = fn () => input;
    req.only = function (names) {
        out = {};
        for (n in names) { out[n] = input[n] ?? null; }
        return out;
    };
    req.has = fn (k) => (input[k] ?? "") != "";
    req.param = fn (k, d = null) => req.params[k] ?? d;
    req.header = fn (k, d = null) => req.headers[lower(k)] ?? d;
    req.wants_json = fn () => starts(req.path, "/api/") || contains(req.header("accept", ""), "application/json");
    req.user = fn () => current_user;
    return req;
}

// ---- sessions --------------------------------------------------------------
// The browser keeps a random id in a cookie; the data lives in the database.
// Flash values last for the next request only.

function start_session(req) {
    sid = req.cookies["ink_session"] ?? "";
    row = len(sid) == 64 ? db_one(db, "SELECT data FROM ink_sessions WHERE id = ?", [sid]) : null;
    data = row ? (fromjson(row.data) ?? {}) : {};
    fresh = !row;
    if (fresh) { sid = token(32); }
    old_flash = data["_flash"] ?? {};
    data["_flash"] = {};
    if (!contains(data, "_token")) { data["_token"] = token(20); }

    s = {};
    s.id = fn () => sid;
    s.get = fn (k, d = null) => data[k] ?? d;
    s.put = function (k, v) { data[k] = v; return v; };
    s.has = fn (k) => contains(data, k);
    s.forget = function (k) { remove(data, k); };
    s.pull = function (k, d = null) { v = data[k] ?? d; remove(data, k); return v; };
    s.flash = function (k, v) { data["_flash"][k] = v; };
    s.flashed = fn (k, d = null) => old_flash[k] ?? d;
    s.token = fn () => data["_token"];
    s.all = fn () => without(data, ["_flash", "_token"]);
    // a new id after logging in or out, so an id someone else knew is worthless
    s.regenerate = function () {
        db_exec(db, "DELETE FROM ink_sessions WHERE id = ?", [sid]);
        sid = token(32);
        data["_token"] = token(20);
        fresh = true;
    };
    s.save = function () {
        db_exec(db, "INSERT INTO ink_sessions (id, data, updated) VALUES (?, ?, ?)
                     ON CONFLICT (id) DO UPDATE SET data = excluded.data, updated = excluded.updated",
                [sid, json(data), time()]);
        if (fresh) { setcookie("ink_session", sid, config.session_days * 86400); }
        if (random(1, 100) == 1) {
            db_exec(db, "DELETE FROM ink_sessions WHERE updated < ?", [time() - config.session_days * 86400]);
        }
    };
    return s;
}

// ---- authentication --------------------------------------------------------
// Expects a users table with id, email and password (made by hash_password).

function load_user() {
    uid = session.get("user_id");
    current_user = uid ? db_one(db, "SELECT * FROM users WHERE id = ?", [uid]) : null;
    if (current_user) { remove(current_user, "password"); }
}

auth = {
    user: fn () => current_user,
    id: fn () => current_user ? current_user.id : null,
    check: fn () => current_user != null,
    attempt: function (email, password) {
        u = db_one(db, "SELECT * FROM users WHERE email = ?", [email]);
        if (!u || !verify_password(password ?? "", u.password)) { return false; }
        auth.login(u);
        return true;
    },
    login: function (u) {
        session.regenerate();
        session.put("user_id", u.id);
        current_user = without(u, ["password"]);
    },
    logout: function () {
        session.forget("user_id");
        session.regenerate();
        current_user = null;
    },
    // where to go after logging in: the page that asked for it, or home
    intended: fn (fallback = "/") => redirect_to(local_path(session.pull("intended"), fallback)),
};

// ---- validation ------------------------------------------------------------
// rules: {title: "required|min:3|max:120", email: "required|email|unique:users,email"}
// Gives back the cleaned values; on failure the user is sent back to the form
// with error messages and what they typed (ink.old("title"), ink.error("title")).

function label(field) { return replace(field, "_", " "); }

function check_rule(rname, arg, field, value, data) {
    l = label(field);
    if (rname == "required") { return null; }
    if (rname == "min" || rname == "max") {
        n = num(arg);
        size = type(value) == "string" ? len(value) : (type(value) == "number" ? value : len(value));
        unit = type(value) == "string" ? " characters" : "";
        if (rname == "min" && size < n) { return "The " + l + " must be at least " + arg + unit + "."; }
        if (rname == "max" && size > n) { return "The " + l + " may not be more than " + arg + unit + "."; }
        return null;
    }
    if (rname == "email") {
        at = find(value, "@");
        good = type(value) == "string" && at > 0 && contains(substr(value, at), ".") && !contains(value, " ");
        return good ? null : "The " + l + " must be a valid email address.";
    }
    if (rname == "numeric") { return num(str(value)) != null ? null : "The " + l + " must be a number."; }
    if (rname == "integer") {
        v = num(str(value));
        return v != null && v == floor(v) ? null : "The " + l + " must be a whole number.";
    }
    if (rname == "in") { return contains(split(arg, ","), str(value)) ? null : "The selected " + l + " is not allowed."; }
    if (rname == "confirmed") {
        return (data[field + "_confirmation"] ?? null) == value ? null : "The " + l + " confirmation does not match.";
    }
    if (rname == "same") { return (data[arg] ?? null) == value ? null : "The " + l + " and " + label(arg) + " must match."; }
    if (rname == "unique" || rname == "exists") {
        bits = split(arg, ",");
        tbl = ident(bits[0], "table");
        col = ident(bits[1] ?? field, "column");
        sql = "SELECT COUNT(*) FROM " + tbl + " WHERE " + col + " = ?";
        ps = [value];
        if (len(bits) > 2) { sql += " AND id != ?"; push(ps, num(bits[2]) ?? bits[2]); }
        n = db_value(db, sql, ps);
        if (rname == "unique") { return n > 0 ? "That " + l + " is already taken." : null; }
        return n > 0 ? null : "The selected " + l + " does not exist.";
    }
    if (rname == "nullable") { return null; }
    throw {status: 500, message: "Ink: unknown validation rule \"" + rname + "\""};
}

function validate(data, rules) {
    errs = {};
    clean = {};
    for (field, spec in rules) {
        value = data[field] ?? null;
        if (type(value) == "string") { value = trim(value); }
        present = value != null && value != "";
        for (rule in split(spec, "|")) {
            rname = rule;
            arg = null;
            at = find(rule, ":");
            if (at >= 0) { rname = substr(rule, 0, at); arg = substr(rule, at + 1); }
            if (rname == "required" && !present) {
                errs[field] = ["The " + label(field) + " field is required."];
                break;
            }
            if (!present) { continue; }          // other rules only look at filled-in fields
            msg = check_rule(rname, arg, field, value, data);
            if (msg) { errs[field] = [msg]; break; }
            if (rname == "numeric" || rname == "integer") { value = num(str(value)); }
        }
        clean[field] = present ? value : null;
    }
    if (errs) { fail(errs); }
    return clean;
}

// throw a validation error yourself: ink.fail({email: "Those details do not match."})
function fail(errs) {
    fixed = {};
    for (k, v in errs) { fixed[k] = type(v) == "list" ? v : [v]; }
    throw {validation: true, status: 422, message: "The given data was invalid.", errors: fixed};
}

function old(field, d = "") {
    if (!session) { return d; }
    return (session.flashed("old") ?? {})[field] ?? d;
}

function error_for(field) {
    if (!session) { return null; }
    list = (session.flashed("errors") ?? {})[field] ?? null;
    return list ? list[0] : null;
}

// ---- forms -----------------------------------------------------------------

function csrf_field() {
    echo '<input type="hidden" name="_token" value="' + html(session.token()) + '">';
}

function method_field(m) {
    echo '<input type="hidden" name="_method" value="' + html(upper(m)) + '">';
}

// page links for a result of .paginate()
function pager(p) {
    if (p.pages <= 1) { return; }
    function link(n, text, cls = "") {
        q = merge(current_req.query, {page: str(n)});
        parts = [];
        for (k, v in q) { if (type(v) == "string" && v != "") { push(parts, url(k) + "=" + url(v)); } }
        echo '<a class="' + cls + '" href="' + html(current_req.path + "?" + join(parts, "&")) + '">' + html(text) + '</a>';
    }
    echo '<nav class="pager">';
    if (p.page > 1) { link(p.page - 1, "← Newer", "prev"); }
    echo '<span>Page ' + p.page + ' of ' + p.pages + '</span>';
    if (p.page < p.pages) { link(p.page + 1, "Older →", "next"); }
    echo '</nav>';
}

// ---- the database ----------------------------------------------------------

// ink.table("posts").where("user_id", 3).latest().limit(10).get()
function table(tbl, hide = []) {
    ident(tbl, "table name");
    st = {wheres: [], params: [], orders: [], lim: null, off: 0, cols: "*", joins: ""};
    b = {table: tbl};

    function cond(sql, ps) {
        push(st.wheres, sql);
        st.params = st.params + ps;
        return b;
    }
    function where_sql() { return st.wheres ? " WHERE " + join(st.wheres, " AND ") : ""; }
    function select_sql(cols) {
        sql = "SELECT " + cols + " FROM " + tbl + st.joins + where_sql();
        if (st.orders) { sql += " ORDER BY " + join(st.orders, ", "); }
        if (st.lim != null) { sql += " LIMIT " + st.lim + " OFFSET " + st.off; }
        return sql;
    }
    function tidy(row) {
        for (h in hide) { remove(row, h); }
        return row;
    }

    b.select = function (cols) {
        st.cols = join(map(cols, fn (c) => c == "*" ? "*" : (ends(c, ".*") ? ident(substr(c, 0, len(c) - 2), "table") + ".*" : ident(c, "column"))), ", ");
        return b;
    };
    // where("id", 3), where("price", "<", 100), where("deleted_at", null)
    b.where = function (col, op, val = NONE) {
        if (val == NONE) { val = op; op = "="; }
        op = upper(op);
        if (!contains(OPS, op)) { throw {status: 500, message: "Ink: unknown operator " + op}; }
        ident(col, "column");
        if (val == null) {
            if (op != "=" && op != "!=") { throw {status: 500, message: "Ink: compare with null using = or !="}; }
            return cond(col + (op == "=" ? " IS NULL" : " IS NOT NULL"), []);
        }
        return cond(col + " " + op + " ?", [val]);
    };
    b.where_in = function (col, vals) {
        if (!vals) { return cond("0", []); }
        return cond(ident(col, "column") + " IN (" + join(map(vals, fn (v) => "?"), ", ") + ")", vals);
    };
    // search(["title", "body"], "word") -> (title LIKE %word% OR body LIKE %word%)
    b.search = function (cols, term) {
        like = "%" + replace(replace(replace(term, "\\", "\\\\"), "%", "\\%"), "_", "\\_") + "%";
        parts = map(cols, fn (c) => ident(c, "column") + " LIKE ? ESCAPE '\\'");
        return cond("(" + join(parts, " OR ") + ")", map(cols, fn (c) => like));
    };
    // where_raw("price * qty > ?", [100]) for anything else; only values go in ?
    b.where_raw = fn (sql, ps = []) => cond("(" + sql + ")", ps);
    b.order_by = function (col, dir = "asc") {
        d = upper(dir);
        if (d != "ASC" && d != "DESC") { throw {status: 500, message: "Ink: order must be asc or desc"}; }
        push(st.orders, ident(col, "column") + " " + d);
        return b;
    };
    b.latest = fn (col = "created_at") => b.order_by(col, "desc");
    b.oldest = fn (col = "created_at") => b.order_by(col, "asc");
    b.limit = function (n) { st.lim = int(n) ?? 0; return b; };
    b.offset = function (n) { st.off = int(n) ?? 0; return b; };
    b.join = function (other, left, right, kind = "") {
        st.joins += " " + kind + "JOIN " + ident(other, "table") + " ON " + ident(left, "column") + " = " + ident(right, "column");
        return b;
    };
    b.left_join = fn (other, left, right) => b.join(other, left, right, "LEFT ");

    b.get = function () {
        rows = db_query(db, select_sql(st.cols), st.params);
        for (r in rows) { tidy(r); }
        return rows;
    };
    b.first = function () {
        st.lim = 1;
        rows = b.get();
        return rows ? rows[0] : null;
    };
    b.find = fn (id) => b.where(tbl + ".id", id).first();
    b.count = fn () => db_value(db, "SELECT COUNT(*) FROM " + tbl + st.joins + where_sql(), st.params);
    b.exists = fn () => b.count() > 0;
    b.pluck = function (col) {
        rows = db_query(db, select_sql(ident(col, "column")), st.params);
        return map(rows, fn (r) => values(r)[0]);
    };
    b.paginate = function (per = 15, page = 1) {
        total = b.count();
        pages = max(1, int((total + per - 1) / per));
        page = max(1, min(int(page) ?? 1, pages));
        st.lim = per;
        st.off = (page - 1) * per;
        return {items: b.get(), page: page, pages: pages, total: total, per_page: per};
    };
    b.insert = function (data) {
        cols = map(keys(data), fn (c) => ident(c, "column"));
        sql = "INSERT INTO " + tbl + " (" + join(cols, ", ") + ") VALUES (" + join(map(cols, fn (c) => "?"), ", ") + ")";
        return db_exec(db, sql, values(data)).id;
    };
    b.update = function (data) {
        sets = map(keys(data), fn (c) => ident(c, "column") + " = ?");
        return db_exec(db, "UPDATE " + tbl + " SET " + join(sets, ", ") + where_sql(), values(data) + st.params).changes;
    };
    b.delete = fn () => db_exec(db, "DELETE FROM " + tbl + where_sql(), st.params).changes;
    return b;
}

// Post = ink.model("posts", {fillable: ["title", "body"], hidden: []})
function model(tbl, opts = {}) {
    hide = opts.hidden ?? [];
    fillable = opts.fillable ?? null;
    stamps = opts.timestamps ?? true;
    m = {table: tbl};
    m.query = fn () => table(tbl, hide);
    m.all = fn () => m.query().get();
    m.find = fn (id) => m.query().find(id);
    m.find_or_fail = function (id) {
        row = id == null ? null : m.find(id);
        if (!row) { abort(404); }
        return row;
    };
    m.where = fn (col, op, val = NONE) => m.query().where(col, op, val);
    m.latest = fn (col = "created_at") => m.query().latest(col);
    m.count = fn () => m.query().count();
    m.paginate = fn (per = 15, page = 1) => m.query().paginate(per, page);
    // only the fields the model allows to be filled from user input
    m.fill = function (data) {
        if (fillable == null) { return data; }
        out = {};
        for (k in fillable) { if (contains(data, k)) { out[k] = data[k]; } }
        return out;
    };
    m.create = function (data) {
        row = m.fill(data);
        if (stamps) { row.created_at = time(); row.updated_at = time(); }
        return m.find(table(tbl).insert(row));
    };
    m.update = function (id, data) {
        row = m.fill(data);
        if (stamps) { row.updated_at = time(); }
        if (row) { table(tbl).where("id", id).update(row); }
        return m.find(id);
    };
    m.destroy = fn (id) => table(tbl).where("id", id).delete();
    // Relations. Post.with_one(posts, "author", User, "user_id") gives each
    // post an author; User.with_many(users, "posts", Post, "user_id") gives
    // each user a list of posts. One query each, however many rows.
    m.with_one = function (rows, field, other, fk) {
        ids = [];
        for (r in rows) { if (r[fk] != null && !contains(ids, r[fk])) { push(ids, r[fk]); } }
        by_id = {};
        for (o in other.query().where_in("id", ids).get()) { by_id[o.id] = o; }
        for (r in rows) { r[field] = r[fk] == null ? null : (by_id[r[fk]] ?? null); }
        return rows;
    };
    m.with_many = function (rows, field, other, fk) {
        ids = map(rows, fn (r) => r.id);
        groups = {};
        for (r in rows) { groups[r.id] = []; }
        for (o in other.query().where_in(fk, ids).get()) { push(groups[o[fk]], o); }
        for (r in rows) { r[field] = groups[r.id]; }
        return rows;
    };
    return m;
}

// ---- migrations ------------------------------------------------------------
// Files in _app/migrations run once each, in name order. A file returns SQL,
// or a function (db) that does the work.

function migrate() {
    dir = config.app_dir + "/migrations";
    files = listdir(dir) ?? [];
    done = {};
    for (r in db_query(db, "SELECT name FROM ink_migrations")) { done[r.name] = true; }
    for (f in files) {
        if (!ends(f, ".ql") || contains(done, f)) { continue; }
        db_exec(db, "BEGIN");
        try {
            step = require(dir + "/" + f);
            if (type(step) == "string") { db_exec(db, step); }
            elseif (type(step) == "function") { step(db); }
            db_exec(db, "INSERT INTO ink_migrations (name, ran_at) VALUES (?, ?)", [f, time()]);
            db_exec(db, "COMMIT");
        } catch (e) {
            db_exec(db, "ROLLBACK");
            throw {status: 500, message: "Migration " + f + " failed: " + (type(e) == "map" ? e.message : str(e))};
        }
    }
}

// ---- errors ----------------------------------------------------------------

function handle_error(e, req) {
    if (type(e) == "map" && (e.validation ?? false)) {
        if (req.wants_json()) { return json_response({message: e.message, errors: e.errors}, 422); }
        session.flash("errors", e.errors);
        session.flash("old", without(req.all(), ["password", "password_confirmation", "_token", "_method"]));
        return back(req);
    }
    code = 500;
    message = status_text(500);
    detail = null;
    if (type(e) == "map" && contains(e, "status") && type(e.status) == "number") {
        code = e.status;
        message = e.message ?? status_text(code);
    } elseif (type(e) == "map" && contains(e, "where")) {
        detail = e.message + " (" + e.where + ")";        // a mistake in the code
    } else {
        detail = "uncaught exception: " + (type(e) == "string" ? e : json(e));
    }
    if (code >= 500 && !detail && type(e) == "map") { detail = e.message; }
    if (req.wants_json()) {
        body = {message: message};
        if (config.debug && detail) { body.detail = detail; }
        return json_response(body, code);
    }
    data = {code: code, message: message, detail: config.debug ? detail : null};
    for (name in [str(code), "error"]) {
        if (exists(config.app_dir + "/views/errors/" + name + ".ql")) {
            try { return view("errors/" + name, data, code); }
            catch (e2) { break; }                     // a broken error page: use the plain one
        }
    }
    page = '<!doctype html><meta charset="utf-8"><title>' + code + '</title>' +
           '<body style="font:16px/1.5 system-ui;margin:3em;max-width:40em">' +
           '<h1>' + code + ' · ' + html(message) + '</h1>' +
           (data.detail ? '<pre style="white-space:pre-wrap;background:#f6f0e8;padding:1em">' + html(data.detail) + '</pre>' : '') +
           '</body>';
    return response(page, code);
}

// ---- running the app -------------------------------------------------------

function boot(cfg = {}) {
    config = merge(config, cfg);
    db = db_open(config.database);
    db_exec(db, "CREATE TABLE IF NOT EXISTS ink_sessions (id TEXT PRIMARY KEY, data TEXT NOT NULL, updated INTEGER NOT NULL);
                 CREATE TABLE IF NOT EXISTS ink_migrations (name TEXT PRIMARY KEY, ran_at INTEGER NOT NULL);");
    middleware_map["auth"] = mw_auth;
    middleware_map["guest"] = mw_guest;
    middleware_map["csrf"] = mw_csrf;
    global_middleware = ["csrf"];
    migrate();
}

function send(res) {
    status(res.status);
    for (k, v in res.headers) { header(k, str(v)); }
    if (request.method != "HEAD") { echo res.body; }
}

function run() {
    req = make_request();
    current_req = req;
    session = start_session(req);
    load_user();
    res = null;
    // anything a handler echoes instead of returning still ends up on the page
    printed = capture(function () {
        try {
            m = match_route(req.method, req.path);
            req.params = m.params;
            res = pipeline(global_middleware + m.route.middleware, make_final(m.route.handler, m.params))(req);
        } catch (e) {
            res = handle_error(e, req);
        }
    });
    if (printed != "" && type(res.body) == "string") { res.body = printed + res.body; }
    session.save();
    send(res);
}

M = {
    version: VERSION,
    boot: boot,
    run: run,
    // routes
    get: fn (path, handler, opts = {}) => add_route(["GET"], path, handler, opts),
    post: fn (path, handler, opts = {}) => add_route(["POST"], path, handler, opts),
    put: fn (path, handler, opts = {}) => add_route(["PUT", "PATCH"], path, handler, opts),
    patch: fn (path, handler, opts = {}) => add_route(["PATCH"], path, handler, opts),
    delete: fn (path, handler, opts = {}) => add_route(["DELETE"], path, handler, opts),
    any: fn (path, handler, opts = {}) => add_route(["GET", "POST", "PUT", "PATCH", "DELETE"], path, handler, opts),
    group: group,
    middleware: function (mname, f) { middleware_map[mname] = f; },
    use: function (f) { push(global_middleware, f); },
    url: route_url,
    routes: fn () => map(routes, fn (r) => {methods: r.methods, path: r.path, name: r.name}),
    // responses
    view: view,
    partial: partial,
    layout: layout,
    share: function (k, v) { shared[k] = v; },
    json: json_response,
    response: response,
    redirect: redirect_to,
    to_route: fn (rname, params = {}) => redirect_to(route_url(rname, params)),
    back: fn (fallback = "/") => back(current_req, fallback),
    abort: abort,
    // data
    db: fn () => db,
    table: table,
    model: model,
    validate: validate,
    fail: fail,
    // sessions, users and forms
    session: fn () => session,
    auth: auth,
    old: old,
    error: error_for,
    csrf_token: fn () => session.token(),
    csrf_field: csrf_field,
    method_field: method_field,
    pager: pager,
    config: fn (k, d = null) => config[k] ?? d,
    // small helpers for apps
    merge: merge,
    without: without,
};
return M;
?>
