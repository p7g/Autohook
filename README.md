# Autohook

**Autohook** is a very, _very_ small Git hook manager with focus on automation.

It consists of one script which acts as the entry point for all the hooks, and
which runs scripts based on symlinks in appropriate directories.

[![Say Thanks!](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)][ty]

[ty]: https://saythanks.io/to/nkantar


## Changes from original repository

In this fork, I added the ability to run hooks only when files with certain
extensions are staged. An example of this can be seen in the hooks directory of
this repo; there is now a lint script located at [`hooks/scripts/lint`][lint],
which is linked to `hooks/pre-commit/sh/lint`. Any global scripts can still be
linked to the git hook directory as described below, but now linking a script
into a directory corresponding to the extension inside the hook directory will
result in that script only being run when files of that type are staged.

[lint]: https://github.com/p7g/Autohook/blob/master/hooks/scripts/lint

Some other changes:

- Every script has access to some environment variables:
  - `AUTOHOOK_REPO_ROOT`: The root of the current repository
  - `AUTOHOOK_STAGED_FILES`: A list of files with the relevant extension that
    are currently staged (only applicable if the script is being run for an
    extension).
  - `AUTOHOOK_HOOK_TYPE`: The current git hook that is being run. This is useful
    if you would like to reuse your script with different hooks, but want some
    slightly different behaviour with some of them.
- Logging has been greatly improved;
  - The application now has no output unless something goes wrong.
    - When something goes wrong, the output of the script that failed is
      displayed
  - For more output (like before this fork), set the `AUTOHOOK_VERBOSE`
    environment variable to something.
  - For _even_ more, set the `AUTOHOOK_DEBUG` variable to something.

## Example

Let's say you have a script to remove `.pyc` files that you want to run after
every `git checkout` and before every `git commit`, and another script that
runs your test suite that you want to run before every `git commit`.

Here's the overview of steps:

1. Put `autohook.sh` in `hooks/`.
2. Run it with `install` parameter (e.g., `./autohook.sh install`).
3. Put your scripts in `hooks/scripts/`.
4. Make sure said scripts are executable (e.g.,
   `chmod +x hooks/scripts/delete-pyc-files`, etc.).
5. Make directories for your hook types (e.g., `mkdir -p hooks/post-checkout
   hooks/pre-commit`).
6. Symlink your scripts to the correct directories, using numbers in symlink
	 names to enforce execution order. Note that your system may require symlinks
	 to be relative to the link. Use full absolute paths (e.g., `ln -s
	 $PWD/hooks/scripts/delete-pyc-files.sh
	 $PWD/hooks/post-checkout/01-delete-pyc-files`, etc.). Or use relative paths
	 (e.g., `cd hooks/post-checkout && ln -s ../scripts/delete-pyc-files.sh
	 01-delete-pyc-files`)

The result should be a tree that looks something like this:

```
repo_root/
├── hooks/
│   ├── autohook.sh
│   ├── post-checkout/
│   │   └── 01-delete-pyc-files # symlink to hooks/scripts/delete-pyc-files.sh
│   ├── pre-commit/
│   │   ├── 01-delete-pyc-files # symlink to hooks/scripts/delete-pyc-files.sh
│   │   └── 02-run-tests        # symlink to hooks/scripts/run-tests.sh
│   └── scripts/
│       ├── delete-pyc-files.sh
│       └── run-tests.sh
├── other_dirs/
└── other_files
```

You're done!


## Contributing

Contributions of all sorts are welcome, be they bug reports, patches, or even
just feedback. Creating a [new issue][new issue] or [pull request][pr] is
probably the best way to get started.

Please note that this project is released with a
[Contributor Code of Conduct][coc]. By participating in this project you agree
to abide by its terms.


[new issue]: https://github.com/nkantar/Autohook/issues/new 'New Issue'
[pr]: https://github.com/nkantar/Autohook/compare 'New Pull Request'
[coc]: https://github.com/nkantar/Autohook/blob/master/CODE_OF_CONDUCT.md 'Autohook Code of Conduct'

## License

This software is licensed under the _MIT License_. Please see the included
`LICENSE.txt` for details.

