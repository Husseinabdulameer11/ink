<?
return {
    name: "Inkwell",
    // details of errors on the error page; set INK_DEBUG=0 when the site is public
    debug: env("INK_DEBUG", "1") == "1",
    database: "_data/inkwell.db",
    login_url: "/login",
    home_url: "/",
};
?>
