<?
return "
CREATE TABLE users (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    email      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password   TEXT NOT NULL,
    bio        TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
";
?>
