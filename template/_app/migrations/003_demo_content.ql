<?
// Demo writers and posts. A migration can also be a function that gets the
// database. Delete this file for an empty site.
return function (db) {
    now = time();
    day = 86400;
    people = [
        ["Ada Lindqvist", "ada@example.com", "Writes about small machines and the people who build them."],
        ["Jonas Berg", "jonas@example.com", "Bakes bread on weekends, debugs compilers on weekdays."],
    ];
    ids = [];
    for (i, p in people) {
        r = db_exec(db, "INSERT INTO users (name, email, password, bio, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
                    [p[0], p[1], hash_password("password"), p[2], now - 30 * day, now - 30 * day]);
        push(ids, r.id);
    }
    posts = [
        [0, 9, "Why I wrote a language for my own website",
         "Every web framework I have used was built on a language someone else designed for a different job.\n\nSo I tried the opposite: a tiny language whose only job is pages. Templates are the default, HTML is escaped unless I say otherwise, and the database is one function call away.\n\nThis blog runs on it. Every page you see went through a router, a controller and a view written in that language."],
        [1, 7, "Sourdough and parsers have a lot in common",
         "Both punish impatience. Both work best when you understand what is happening underneath instead of following a recipe.\n\nA PEG parser tries one thing, and if it fails, backs up and tries the next. A starter does the same with whatever yeast is in your kitchen."],
        [0, 5, "Closures, explained with a coffee shop",
         "A closure is a function that remembers where it was written.\n\nThink of a barista who learned your order on your first visit. Later, a different person can hand them a cup and they still know it is a flat white for you. The order lives in the barista, not in the cup."],
        [1, 3, "Notes from rebuilding a shop in a weekend",
         "The parts that took longest were not the clever ones. Stock that runs out while someone types their address. Forms that must not submit twice. Error messages a person can act on.\n\nThe database transaction at checkout is ten lines. Getting the words right on the error page took longer."],
        [0, 2, "What makes a framework feel like a framework",
         "Routing, middleware, views with layouts, a query builder, migrations, validation, sessions and CSRF protection.\n\nNone of them is hard on its own. The feeling comes from them fitting together, so that the obvious thing to write is also the safe thing."],
        [1, 1, "A short list of good error messages",
         "Say what happened. Say what to do next. Do not apologise three times. Do not blame the person reading it."],
        [0, 0, "Hello from Inkwell",
         "This is a demo blog for Ink, a small framework written in Quill. Register an account to write your own posts, or log in as ada@example.com with the password \"password\"."],
    ];
    post_ids = [];
    for (p in posts) {
        t = now - p[1] * day - random(0, 3600);
        r = db_exec(db, "INSERT INTO posts (user_id, title, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                    [ids[p[0]], p[2], p[3], t, t]);
        push(post_ids, r.id);
    }
    comments = [
        [0, 1, "This is exactly why I started reading compiler books again."],
        [2, 1, "The barista comparison finally made it click. Thanks!"],
        [4, 1, "Middleware was the part I never understood in Laravel. Seeing it as a function that calls the next function helps."],
    ];
    for (c in comments) {
        db_exec(db, "INSERT INTO comments (post_id, user_id, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                [post_ids[c[0]], ids[c[1]], c[2], now - 3600, now - 3600]);
    }
};
?>
