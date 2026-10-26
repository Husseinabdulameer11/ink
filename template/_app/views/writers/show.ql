<? ink.layout("app", {title: writer.name}); ?>
<header class="writer">
  <div class="avatar" aria-hidden="true"><?= upper(substr(writer.name, 0, 1)) ?></div>
  <div>
    <h1><?= writer.name ?></h1>
<? if (writer.bio) { ?><p><?= writer.bio ?></p><? } ?>
    <p class="muted">Writing here since <?= date("%B %Y", writer.created_at) ?> · <?= len(posts) ?> post<?= len(posts) == 1 ? "" : "s" ?></p>
  </div>
</header>
<ul class="list">
<? for (p in posts) { ?>
  <li><a href="<?= ink.url("posts.show", {id: p.id}) ?>"><?= p.title ?></a> <time><?= date("%e %b %Y", p.created_at) ?></time></li>
<? } ?>
</ul>
