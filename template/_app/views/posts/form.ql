<? ink.layout("app", {title: post ? "Edit post" : "Write a post"}); ?>
<h1 class="pagehead"><?= post ? "Edit your post" : "Write a post" ?></h1>
<form method="post" class="stack editor"
      action="<?= post ? ink.url("posts.update", {id: post.id}) : ink.url("posts.store") ?>">
  <? ink.csrf_field(); if (post) { ink.method_field("PUT"); } ?>
  <label for="title">Title</label>
  <input id="title" name="title" value="<?= ink.old("title", post ? post.title : "") ?>" maxlength="120" required>
<? if (ink.error("title")) { ?><p class="error"><?= ink.error("title") ?></p><? } ?>
  <label for="body">Post <span class="muted">· a blank line starts a new paragraph</span></label>
  <textarea id="body" name="body" rows="14" required><?= ink.old("body", post ? post.body : "") ?></textarea>
<? if (ink.error("body")) { ?><p class="error"><?= ink.error("body") ?></p><? } ?>
  <div class="actions">
    <button class="button"><?= post ? "Save changes" : "Publish" ?></button>
    <a href="<?= post ? ink.url("posts.show", {id: post.id}) : ink.url("home") ?>">Cancel</a>
  </div>
</form>
