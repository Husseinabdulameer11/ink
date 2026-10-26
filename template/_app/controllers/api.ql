<?
// JSON: return a map or a list and Ink sends it as JSON.
models = require("/_app/models.ql");
Post = models.Post;
User = models.User;

function public_post(p) {
    return {id: p.id, title: p.title, body: p.body, created_at: p.created_at,
            author: p.author ? {id: p.author.id, name: p.author.name} : null,
            url: ink.url("posts.show", {id: p.id})};
}

function posts(req) {
    page = Post.latest().paginate(20, req.input("page", 1));
    Post.with_one(page.items, "author", User, "user_id");
    return {page: page.page, pages: page.pages, total: page.total, posts: map(page.items, public_post)};
}

function post(req, id) {
    p = Post.find_or_fail(id);
    p.author = User.find(p.user_id);
    return public_post(p);
}

return {posts: posts, post: post};
?>
