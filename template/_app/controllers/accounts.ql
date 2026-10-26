<?
models = require("/_app/models.ql");
User = models.User;
Post = models.Post;

function login_form(req) { return ink.view("auth/login"); }

function login(req) {
    data = ink.validate(req.all(), {email: "required|email", password: "required"});
    if (!ink.auth.attempt(data.email, req.input("password"))) {
        // the same answer either way, so the form does not tell who has an account
        ink.fail({email: "That email and password do not match an account."});
    }
    return ink.auth.intended("/").with("message", "Welcome back, " + split(ink.auth.user().name)[0] + ".");
}

function register_form(req) { return ink.view("auth/register"); }

function register(req) {
    data = ink.validate(req.all(), {
        name: "required|min:2|max:60",
        email: "required|email|max:120|unique:users,email",
        password: "required|min:8|max:200|confirmed",
    });
    data.password = hash_password(data.password);
    user = User.create(data);
    ink.auth.login(ink.table("users").find(user.id));
    return ink.redirect("/").with("message", "Welcome to Inkwell, " + split(user.name)[0] + "!");
}

function logout(req) {
    ink.auth.logout();
    return ink.redirect("/").with("message", "You are logged out.");
}

function profile(req, id) {
    writer = User.find_or_fail(id);
    posts = Post.where("user_id", writer.id).latest().get();
    return ink.view("writers/show", {writer: writer, posts: posts});
}

return {login_form: login_form, login: login, register_form: register_form,
        register: register, logout: logout, profile: profile};
?>
