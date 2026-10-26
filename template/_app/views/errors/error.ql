<? ink.layout("app", {title: message}); ?>
<div class="errorpage">
  <p class="code"><?= code ?></p>
  <h1><?= message ?></h1>
<? if (code == 404) { ?>
  <p>The page may have moved, or the post was deleted.</p>
<? } elseif (code == 403) { ?>
  <p>Only the writer of a post can change it.</p>
<? } ?>
  <p><a class="button" href="<?= ink.url("home") ?>">Back to the front page</a></p>
<? if (detail) { ?>
  <pre class="detail"><?= detail ?></pre>
<? } ?>
</div>
