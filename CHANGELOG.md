# Changelog

## 0.1.0

First version, moved out of the Quill repository into a package of its own.

- Routing with URL parameters, optional parts, names and groups
- Middleware (`auth`, `guest`, `csrf`, and your own), controllers
- Views with layouts and partials; values shared with every view
- Query builder, models with `fillable`/`hidden`, relations in one query
- Migrations, validation with old input and messages, sessions, flash
  messages, CSRF protection, logins with hashed passwords
- Error pages from views; JSON answers for `/api/` paths
