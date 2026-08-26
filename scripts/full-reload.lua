-- full-reload: reapply pywal palette, then live-reload the shell.
-- Usage: harmonica scripts full-reload

-- wal is spawned DETACHED: some of its hooks can kill their process group,
-- which would otherwise take this script down before the reload happens
sys.spawn("wal -R")

-- give pywal time to write ~/.cache/wal/colors.json;
-- Theme watches the file reactively once the island reloads
sys.run("sleep 1")
shell.reload()
