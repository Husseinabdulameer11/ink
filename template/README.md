# A blog on Ink

Made with `quill pkg create-project husseinabdulameer11/ink`. Accounts,
posts, comments, writer pages, search, pages of results and a JSON API, in
about 400 lines of Quill on the [Ink](https://github.com/Husseinabdulameer11/ink)
framework.

```
quill serve . --router index.ql
```

Open http://127.0.0.1:8080/ and log in as `ada@example.com` with the password
`password`, or make an account. After cloning this project somewhere else,
run `quill pkg install` first.

| | |
|---|---|
| `index.ql` | every request comes here |
| `_app/routes.ql` | which URL runs which function |
| `_app/controllers/` | posts, accounts and the API |
| `_app/models.ql` | users, posts and comments |
| `_app/migrations/` | the tables; `003_demo_content.ql` adds the demo posts (delete it for an empty blog) |
| `_app/views/` | the pages; `layouts/app.ql` is the frame around them |
| `style.css` | the look |
| `quill.json` | the packages: Ink 0.1 |

The database is made on the first visit, in `_data/inkwell.db`. Delete that
file to start over. Set `INK_DEBUG=0` before putting the site online, so
error pages do not show details. Change `name` in `quill.json` to your own.
