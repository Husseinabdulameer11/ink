<?
posts = require("/_app/controllers/posts.ql");
accounts = require("/_app/controllers/accounts.ql");
api = require("/_app/controllers/api.ql");

ink.get("/", posts.index, {name: "home"});

// Order matters: /posts/new must come before /posts/{id}.
ink.group({middleware: ["auth"]}, function () {
    ink.get("/posts/new", posts.create, {name: "posts.create"});
    ink.post("/posts", posts.store, {name: "posts.store"});
    ink.get("/posts/{id}/edit", posts.edit, {name: "posts.edit"});
    ink.put("/posts/{id}", posts.update, {name: "posts.update"});
    ink.delete("/posts/{id}", posts.destroy, {name: "posts.destroy"});
    ink.post("/posts/{id}/comments", posts.comment, {name: "posts.comment"});
    ink.post("/logout", accounts.logout, {name: "logout"});
});
ink.get("/posts/{id}", posts.show, {name: "posts.show"});
ink.get("/writers/{id}", accounts.profile, {name: "writers.show"});

ink.group({middleware: ["guest"]}, function () {
    ink.get("/login", accounts.login_form, {name: "login"});
    ink.post("/login", accounts.login);
    ink.get("/register", accounts.register_form, {name: "register"});
    ink.post("/register", accounts.register);
});

ink.group({prefix: "/api"}, function () {
    ink.get("/posts", api.posts);
    ink.get("/posts/{id}", api.post);
    ink.get("/routes", fn () => ink.routes());
});
?>
