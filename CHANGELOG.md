# Changelog

## 0.1.1

- A project template: `quill pkg create-project husseinabdulameer11/ink myblog`
  starts a blog with accounts, posts, comments and a JSON API (the app that
  was Inkwell). It is in `template/` and is left out when Ink is installed
  as a package

## 0.1.0

First version, moved out of the Quill repository into a package of its own.

- Routing with URL parameters, optional parts, names and groups
- Middleware (`auth`, `guest`, `csrf`, and your own), controllers
- Views with layouts and partials; values shared with every view
- Query builder, models with `fillable`/`hidden`, relations in one query
- Migrations, validation with old input and messages, sessions, flash
  messages, CSRF protection, logins with hashed passwords
- Error pages from views; JSON answers for `/api/` paths
