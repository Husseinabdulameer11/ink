<? ink.layout("app", {title: "Join"}); ?>
<div class="narrow">
  <h1 class="pagehead">Join Inkwell</h1>
  <form method="post" action="<?= ink.url("register") ?>" class="stack">
    <? ink.csrf_field(); ?>
<? for (f in [["name", "Name", "text", "name"], ["email", "Email", "email", "email"]]) { ?>
    <label for="<?= f[0] ?>"><?= f[1] ?></label>
    <input id="<?= f[0] ?>" name="<?= f[0] ?>" type="<?= f[2] ?>" value="<?= ink.old(f[0]) ?>" autocomplete="<?= f[3] ?>" required>
<? if (ink.error(f[0])) { ?><p class="error"><?= ink.error(f[0]) ?></p><? } ?>
<? } ?>
    <label for="password">Password <span class="muted">· at least 8 characters</span></label>
    <input id="password" name="password" type="password" autocomplete="new-password" required>
<? if (ink.error("password")) { ?><p class="error"><?= ink.error("password") ?></p><? } ?>
    <label for="password_confirmation">Password again</label>
    <input id="password_confirmation" name="password_confirmation" type="password" autocomplete="new-password" required>
    <button class="button">Make my account</button>
  </form>
  <p class="muted">Already have one? <a href="<?= ink.url("login") ?>">Log in</a>.</p>
</div>
