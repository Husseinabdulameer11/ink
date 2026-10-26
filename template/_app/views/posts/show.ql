<? ink.layout("app", {title: post.title}); ?>
<article class="post">
  <h1><?= post.title ?></h1>
  <p class="byline">
    By <a href="<?= ink.url("writers.show", {id: post.author.id}) ?>"><?= post.author.name ?></a>
    · <time><?= date("%e %B %Y", post.created_at) ?></time>
<? if (post.updated_at > post.created_at + 60) { ?>· edited<? } ?>
  </p>
<? for (para in split(post.body, "\n\n")) { ?>
  <p><?= trim(para) ?></p>
<? } ?>

<? if (user && user.id == post.user_id) { ?>
  <div class="owner">
    <a class="button ghost" href="<?= ink.url("posts.edit", {id: post.id}) ?>">Edit</a>
    <form method="post" action="<?= ink.url("posts.destroy", {id: post.id}) ?>">
      <? ink.csrf_field(); ink.method_field("DELETE"); ?>
      <button class="button danger">Delete</button>
    </form>
  </div>
<? } ?>
</article>

<section id="comments" class="comments">
  <h2><?= len(comments) ?> comment<?= len(comments) == 1 ? "" : "s" ?></h2>
<? for (c in comments) { ?>
  <div class="comment">
    <p class="byline"><a href="<?= ink.url("writers.show", {id: c.user_id}) ?>"><?= c.author.name ?></a> · <?= date("%e %b, %H:%M", c.created_at) ?></p>
    <p><?= c.body ?></p>
  </div>
<? } ?>
<? if (user) { ?>
  <form method="post" action="<?= ink.url("posts.comment", {id: post.id}) ?>" class="stack">
    <? ink.csrf_field(); ?>
    <label for="body">Add a comment</label>
    <textarea id="body" name="body" rows="3"><?= ink.old("body") ?></textarea>
<? if (ink.error("body")) { ?><p class="error"><?= ink.error("body") ?></p><? } ?>
    <button class="button">Post comment</button>
  </form>
<? } else { ?>
  <p class="muted"><a href="<?= ink.url("login") ?>">Log in</a> to comment.</p>
<? } ?>
</section>
