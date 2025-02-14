Install a glob pattern that uses a relative path.

Test that dune detects an error when we use a pattern such as ../foo/* in the
install stanza. The problem with this pattern is its destination refers to a
path outside the package's install directory.

  $ cat >dune-project <<EOF
  > (lang dune 3.11)
  > (package (name foo))
  > EOF

  $ mkdir -p stanza stuff/xy
  $ touch stuff/foo.txt stuff/xy/bar.txt

normal install stanza in the share directory of the package:

  $ cat >dune <<EOF
  > (install
  >  (section share)
  >  (files stuff/foo.txt))
  > EOF

Incorrect install stanza that would place files outside the package's install directory
  $ cat >stanza/dune <<EOF
  > (install
  >  (files (glob_files_rec ../stuff/*.txt))
  >  (section share))
  > EOF

  $ dune build foo.install
  File "stanza/dune", line 2, characters 24-38:
  2 |  (files (glob_files_rec ../stuff/*.txt))
                              ^^^^^^^^^^^^^^
  Warning: The destination path ../stuff/foo.txt begins with .. which will
  become an error in a future version of Dune. Destinations of files in install
  stanzas beginning with .. will be disallowed to prevent a package's installed
  files from escaping that package's install directories.
  File "stanza/dune", line 2, characters 24-38:
  2 |  (files (glob_files_rec ../stuff/*.txt))
                              ^^^^^^^^^^^^^^
  Warning: The destination path ../stuff/xy/bar.txt begins with .. which will
  become an error in a future version of Dune. Destinations of files in install
  stanzas beginning with .. will be disallowed to prevent a package's installed
  files from escaping that package's install directories.

