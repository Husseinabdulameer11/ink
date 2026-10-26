<? ink.layout("app", {title: q != "" ? "Search" : null}); ?>
<? if (q != "") { ?>
<h1 class="pagehead"><?= page.total ?> result<?= page.total == 1 ? "" : "s" ?> for “<?= q ?>”</h1>
<p class="muted"><a href="<?= ink.url("home") ?>">Show all posts</a></p>
<? } else { ?>
<h1 class="pagehead">Recent writing</h1>
<? } ?>

<? if (!page.items) { ?>
<p class="empty">Nothing here yet.<? if (user) { ?> <a href="<?= ink.url("posts.create") ?>">Write the first post.</a><? } ?></p>
<? } ?>

<? for (post in page.items) { ?>
<article class="teaser">
  <h2><a href="<?= ink.url("posts.show", {id: post.id}) ?>"><?= post.title ?></a></h2>
  <p class="byline">
    <a href="<?= ink.url("writers.show", {id: post.user_id}) ?>"><?= post.author.name ?></a>
    · <time><?= date("%e %B %Y", post.created_at) ?></time>
<? if (post.comments) { ?>· <?= post.comments ?> comment<?= post.comments == 1 ? "" : "s" ?><? } ?>
  </p>
<? teaser = replace(post.body, "\n\n", " "); ?>
  <p><?= len(teaser) > 220 ? substr(teaser, 0, 220) + "…" : teaser ?></p>
</article>
<? } ?>

<? ink.pager(page); ?>
