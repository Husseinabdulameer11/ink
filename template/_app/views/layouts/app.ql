<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= title ?? "Inkwell" ?><?= title ?? false ? " · Inkwell" : "" ?></title>
<link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="masthead">
  <a class="brand" href="<?= ink.url("home") ?>">Inkwell</a>
  <form class="search" action="<?= ink.url("home") ?>" method="get">
    <input name="q" value="<?= request.input("q", "") ?>" placeholder="Search posts" aria-label="Search posts">
  </form>
  <nav>
<? if (user) { ?>
    <a class="write" href="<?= ink.url("posts.create") ?>">Write</a>
    <a href="<?= ink.url("writers.show", {id: user.id}) ?>"><?= user.name ?></a>
    <form method="post" action="<?= ink.url("logout") ?>"><? ink.csrf_field(); ?><button class="link">Log out</button></form>
<? } else { ?>
    <a href="<?= ink.url("login") ?>">Log in</a>
    <a class="write" href="<?= ink.url("register") ?>">Join</a>
<? } ?>
  </nav>
</header>
<? if (notice) { ?>
<p class="notice" role="status"><?= notice ?></p>
<? } ?>
<main>
<? echo content; ?>
</main>
<footer>Inkwell runs on <strong>Ink <?= ink.version ?></strong>, a framework written in Quill.</footer>
</body>
</html>
