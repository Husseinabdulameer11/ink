<?
models = require("/_app/models.ql");
Post = models.Post;
User = models.User;
Comment = models.Comment;

RULES = {title: "required|min:3|max:120", body: "required|min:10|max:20000"};

// only the writer of a post may change it
function own(post) {
    if (post.user_id != ink.auth.id()) { ink.abort(403); }
    return post;
}

function index(req) {
    q = trim(req.input("q", ""));
    query = Post.latest();
    if (q != "") { query.search(["title", "body"], q); }
    page = query.paginate(6, req.input("page", 1));
    Post.with_one(page.items, "author", User, "user_id");
    for (p in page.items) {
        p.comments = Comment.where("post_id", p.id).count();
    }
    return ink.view("posts/index", {page: page, q: q});
}

function show(req, id) {
    post = Post.find_or_fail(id);
    post.author = User.find(post.user_id);
    comments = Comment.where("post_id", post.id).oldest().get();
    Comment.with_one(comments, "author", User, "user_id");
    return ink.view("posts/show", {post: post, comments: comments});
}

function create(req) {
    return ink.view("posts/form", {post: null});
}

function store(req) {
    data = ink.validate(req.all(), RULES);
    data.user_id = ink.auth.id();
    post = Post.create(data);
    return ink.to_route("posts.show", {id: post.id}).with("message", "Your post is published.");
}

function edit(req, id) {
    return ink.view("posts/form", {post: own(Post.find_or_fail(id))});
}

function update(req, id) {
    own(Post.find_or_fail(id));
    Post.update(id, ink.validate(req.all(), RULES));
    return ink.to_route("posts.show", {id: id}).with("message", "Your changes are saved.");
}

function destroy(req, id) {
    post = own(Post.find_or_fail(id));
    Post.destroy(post.id);
    return ink.to_route("home").with("message", "\"" + post.title + "\" is deleted.");
}

function comment(req, id) {
    post = Post.find_or_fail(id);
    data = ink.validate(req.all(), {body: "required|max:2000"});
    Comment.create({body: data.body, post_id: post.id, user_id: ink.auth.id()});
    return ink.redirect(ink.url("posts.show", {id: post.id}) + "#comments").with("message", "Thanks for your comment.");
}

return {index: index, show: show, create: create, store: store, edit: edit,
        update: update, destroy: destroy, comment: comment};
?>
