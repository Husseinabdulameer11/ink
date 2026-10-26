# Ink

Ink is a small web framework for [Quill](https://github.com/Husseinabdulameer11/quill),
in the spirit of Laravel: routing, middleware, controllers, views with
layouts, a query builder, models, migrations, validation, sessions, CSRF
protection and logins. It is one file of Quill, about 900 lines.

## Installing

Ink is a Quill package. The quickest start is the Inkwell blog template,
which gives you a working app with accounts, posts and comments:

```
quill pkg create-project husseinabdulameer11/inkwell myblog
cd myblog
quill serve . --router index.ql
```

Or add Ink to a project of your own:

```
quill pkg init
quill pkg require husseinabdulameer11/ink
```

That puts Ink in `_vendor/` and records the version in `quill.json` and
`quill.lock`. Ink needs Quill 0.3 or newer; `quill pkg` itself came in 0.4.

## How an Ink app is laid out

```
mysite/
  index.ql                 the front controller: every request comes here
  style.css, images/ ...   plain files, sent as they are
  quill.json, quill.lock   the packages the app uses (never sent to browsers)
  _vendor/                 installed packages, Ink among them
  _app/config.ql           settings
  _app/routes.ql           which URL runs which function
  _app/controllers/*.ql    the functions
  _app/models.ql           your tables
  _app/migrations/*.ql     the database schema, in steps
  _app/views/              templates; layouts/ and errors/ inside
  _data/                   the SQLite database
```

Names starting with `_` are never sent to browsers, so code and data stay
private. Run the site with `--router index.ql`:

```
<?  // index.ql
ink = require("/_vendor/autoload.ql")("ink");
ink.boot(require("/_app/config.ql"));
include("/_app/routes.ql");
ink.run();
?>
```

`ink.boot` opens the database and runs any migrations that have not run yet.
`ink.run` handles the request.

## Configuration

```
<?  // _app/config.ql
return {
    name: "Inkwell",
    debug: env("INK_DEBUG", "1") == "1",   // show error details; turn off in public
    database: "_data/inkwell.db",
    login_url: "/login",                  // where "auth" sends guests
    home_url: "/",                        // where "guest" sends logged-in users
};
?>
```

## Routes

```
ink.get("/", posts.index, {name: "home"});
ink.get("/posts/{id}", posts.show, {name: "posts.show"});
ink.post("/posts", posts.store, {middleware: ["auth"]});
ink.put("/posts/{id}", posts.update);         // PUT and PATCH
ink.delete("/posts/{id}", posts.destroy);
ink.any("/hook", handler);
ink.get("/archive/{year}/{month?}", archive); // {month?} may be left out

ink.group({prefix: "/admin", middleware: ["auth"]}, function () {
    ink.get("/stats", admin.stats);           // /admin/stats
});
```

Routes are tried in the order you write them, so `/posts/new` must come
before `/posts/{id}`. A handler gets the request and then the URL values in
order. It can leave out any it does not need:

```
function show(req, id) { ... }
```

`ink.url("posts.show", {id: 3})` builds `/posts/3` from a route's name. Values
that are not in the path become a query string.

HTML forms can only send GET and POST. To send PUT or DELETE, add
`ink.method_field("DELETE")` inside the form.

## Requests

| | |
|---|---|
| `req.method`, `req.path` | `"POST"`, `"/posts/3"` |
| `req.input("title", default)` | a form field or query value |
| `req.all()`, `req.only(["a", "b"])` | all input, or some of it |
| `req.has("q")` | a value is present and not empty |
| `req.params`, `req.param("id")` | values from the URL pattern |
| `req.header("accept")`, `req.cookies`, `req.ip` | |
| `req.wants_json()` | the path starts with `/api/` or the client asked for JSON |

## Responses

A handler returns what should be sent:

| Return | Sends |
|---|---|
| a string | that HTML |
| a map or a list | JSON |
| `ink.view("posts/show", {post: p})` | a rendered view |
| `ink.redirect("/posts")`, `ink.to_route("posts.show", {id: 3})`, `ink.back()` | a redirect |
| `ink.json(data, 201)` | JSON with a status |
| `ink.response(body, 200, {"X-Thing": "1"})` | anything else |

Add `.with("message", "Saved.")` to any response to show a message on the
next page.

`ink.abort(404)` stops and shows the error page. So does any uncaught
exception, as a 500, with details shown when `debug` is on. Error pages come
from `views/errors/404.ql`, or `views/errors/error.ql` for every code. They
get `code`, `message` and `detail`. For `/api/` paths, errors are JSON.

## Views

Views are Quill templates in `_app/views`. `<?= ?>` escapes HTML.

```
<? ink.layout("app", {title: post.title}); ?>
<h1><?= post.title ?></h1>
<p>By <?= post.author.name ?></p>
```

`ink.layout("app", data)` puts the view inside `views/layouts/app.ql`, which
prints it with `<? echo content; ?>`. Every view also gets:

| | |
|---|---|
| `ink` | the framework, for `ink.url`, `ink.old`, `ink.error`, `ink.csrf_field` ... |
| `user` | the logged-in user, or null |
| `request` | the request |
| `notice` | the message from `.with("message", ...)`, or null |
| `errors` | validation errors by field |

`ink.partial("posts/_card", {post: p})` renders a piece of a view and gives
the HTML. Print it with `echo`. `ink.share("site_name", "Inkwell")` makes a
value available in every view.

## The database

```
ink.table("posts").where("user_id", 3).latest().limit(10).get();   // list of maps
ink.table("posts").where("views", ">", 100).first();               // a map or null
ink.table("posts").find(7);
ink.table("posts").where_in("id", [1, 2, 3]).count();
ink.table("posts").search(["title", "body"], "closure").get();      // LIKE, safely escaped
ink.table("posts").join("users", "users.id", "posts.user_id").select(["posts.*", "users.name"]).get();
ink.table("posts").paginate(15, req.input("page", 1));              // {items, page, pages, total}
ink.table("posts").insert({title: "Hi", body: "..."});              // gives the new id
ink.table("posts").where("id", 7).update({title: "New"});           // gives rows changed
ink.table("posts").where("id", 7).delete();
```

Values always go to SQLite as parameters. Table and column names cannot be
parameters, so Ink only accepts plain names (letters, digits, `_` and one
dot) and refuses anything else. For SQL the builder cannot express, use
`.where_raw("price * qty > ?", [100])`, or `db_query(ink.db(), sql, params)`.

### Models

```
<?  // _app/models.ql
return {
    User: ink.model("users", {fillable: ["name", "email", "password"], hidden: ["password"]}),
    Post: ink.model("posts", {fillable: ["title", "body", "user_id"]}),
};
?>
```

A model has `all()`, `find(id)`, `find_or_fail(id)` (404 when missing),
`where(...)`, `latest()`, `count()`, `paginate(...)`, `query()` for a full
builder, `create(data)`, `update(id, data)` and `destroy(id)`.

`create` and `update` keep only the `fillable` fields, so extra form fields
cannot set columns like `is_admin`. They also fill in `created_at` and
`updated_at` (turn off with `timestamps: false`). `hidden` fields never come
back from queries.

Relations load in one query, however many rows:

```
Post.with_one(posts, "author", User, "user_id");    // each post gets .author
User.with_many(users, "posts", Post, "user_id");    // each user gets .posts
```

### Migrations

Each file in `_app/migrations` runs once, in name order, inside a
transaction. A file returns SQL, or a function that gets the database:

```
<?  // _app/migrations/001_create_posts.ql
return "CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT NOT NULL, ...)";
?>
```

Ink records what has run in the `ink_migrations` table.

## Validation

```
data = ink.validate(req.all(), {
    title: "required|min:3|max:120",
    email: "required|email|unique:users,email",
    password: "required|min:8|confirmed",
    age: "nullable|integer|min:13",
});
```

If anything fails, the user goes back to the form. The messages are in
`ink.error("title")` and what they typed is in `ink.old("title")`; passwords
are never kept. For `/api/` paths the answer is JSON with status 422.
`validate` gives back only the fields in the rules, trimmed, with
`numeric`/`integer` fields as numbers.

Rules: `required`, `nullable`, `min:n`, `max:n` (characters for text, value
for numbers), `email`, `numeric`, `integer`, `in:a,b,c`, `confirmed` (needs a
`field_confirmation`), `same:other_field`, `unique:table,column[,except_id]`
and `exists:table,column`.

`ink.fail({email: "That email and password do not match."})` sends the user
back the same way, for checks of your own.

## Sessions, logins and CSRF

```
ink.session().put("cart", items);
ink.session().get("cart", []);
ink.session().pull("intended");   // get and forget

ink.auth.attempt(email, password);   // true and logged in, or false
ink.auth.login(user);
ink.auth.logout();
ink.auth.user();                     // without the password
ink.auth.id();
ink.auth.intended("/");              // back to the page that asked for a login
```

Logins need a `users` table with `id`, `email` and `password` (from
`hash_password`). The session id changes on every login and logout.

Every POST, PUT, PATCH and DELETE must carry the session's CSRF token, so
another site cannot submit your forms. Add `ink.csrf_field()` to each form.
Paths in the `csrf_except` setting (by default `/api/`) are exempt.

## Middleware

A middleware is a function that gets the request and the next step:

```
ink.middleware("admin", function (req, next) {
    if (!ink.auth.user() || !ink.auth.user().is_admin) { ink.abort(403); }
    return next(req);
});
ink.get("/admin", admin.index, {middleware: ["auth", "admin"]});

ink.use(function (req, next) {            // runs for every request
    res = next(req);
    return res.header("X-Frame-Options", "DENY");
});
```

Built in: `auth` (logged-in users only), `guest` (logged-out users only) and
`csrf` (always on).

## What Ink does not have yet

Ink is version 0.1.0. Things Laravel has that Ink does not: file uploads,
email, queues, a command-line tool, caching, events, and database engines
other than SQLite. Model relations are the two loaders above rather than
methods on rows.
