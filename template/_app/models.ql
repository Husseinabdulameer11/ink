<?
return {
    User: ink.model("users", {fillable: ["name", "email", "password", "bio"], hidden: ["password"]}),
    Post: ink.model("posts", {fillable: ["title", "body", "user_id"]}),
    Comment: ink.model("comments", {fillable: ["body", "post_id", "user_id"]}),
};
?>
