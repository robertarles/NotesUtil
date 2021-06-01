# NotesUtil

This is my first foray into Swift, my language learning project (and will not get updated, it's a learning experience only)

I keep my notes and todo list in markdown format. I use Hugo to publish (privately) my notes but needed a way to quickly create archives and journals based on my todo activity.

This utility will journal "touched" todos, which I note with a "." and archive todos marked completed.

Example, `/path/to/sometodofile.md`:

```md
## TODO

- [ ] . something I "touched" today but did not finish
- [x] . something I touched today AND finished
- [ ] pick up milk
- [ ] add ML to NotesUtil to do the tasks for me and run itslef to mark them "touched" and complete

## my backlog

...

random notes, about random things.
```

Running `NotesUtil /path/to/sometodofile.md` will _create_ a journal entry for the first two items in `sometodofile-journal.md` and _move_ the completed item to `sometodofile-archive.md` for me. Each journal and archive entry is timestamped. The journal also records whether an item was completed, or just touched.

