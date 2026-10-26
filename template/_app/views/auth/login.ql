<? ink.layout("app", {title: "Log in"}); ?>
<div class="narrow">
  <h1 class="pagehead">Log in</h1>
  <form method="post" action="<?= ink.url("login") ?>" class="stack">
    <? ink.csrf_field(); ?>
    <label for="email">Email</label>
    <input id="email" name="email" type="email" value="<?= ink.old("email") ?>" autocomplete="email" required autofocus>
<? if (ink.error("email")) { ?><p class="error"><?= ink.error("email") ?></p><? } ?>
    <label for="password">Password</label>
    <input id="password" name="password" type="password" autocomplete="current-password" required>
<? if (ink.error("password")) { ?><p class="error"><?= ink.error("password") ?></p><? } ?>
    <button class="button">Log in</button>
  </form>
  <p class="muted">New here? <a href="<?= ink.url("register") ?>">Make an account</a>.</p>
  <p class="hint">Demo account: <code>ada@example.com</code> / <code>password</code></p>
</div>
