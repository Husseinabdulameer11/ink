<?
// Every request comes here (quill serve . --router index.ql).
if (!exists("_vendor/autoload.ql")) {
    status(500);
    echo "<p>The packages are not installed yet. In this folder, run: <code>quill pkg install</code></p>";
    exit();
}
ink = require("/_vendor/autoload.ql")("ink");
ink.boot(require("/_app/config.ql"));
include("/_app/routes.ql");
ink.run();
?>
