Simple example of generating a lock file with Dune

Helper shell function that generates an opam file for a package:

  $ mkpkg() {
  >   name=$1
  >   mkdir -p mock-opam-repository/packages/$name/$name.0.0.1
  >   cat >mock-opam-repository/packages/$name/$name.0.0.1/opam
  > }
  $ emptypkg() {
  >   mkpkg $1 <<EOF
  > opam-version: "2.0"
  > EOF
  > }
  $ versionpkg() {
  >   name=$1
  >   ver=$2
  >   mkdir -p mock-opam-repository/packages/$name/$name.$ver
  >   cat >mock-opam-repository/packages/$name/$name.$ver/opam
  > }
  $ emptyverpkg() {
  >   versionpkg $1 $2 <<EOF
  > opam-version: "2.0"
  > EOF
  > }

Generate a `dune-project` file.
  $ cat >dune-project <<EOF
  > (lang dune 3.8)
  > (package
  >  (name lockfile_generation_test)
  >  (depends
  >    foo
  >    (bar (>= "0.3"))))
  > EOF
  > mkpkg foo <<EOF
  > opam-version: "2.0"
  > depends: [
  >     "baz" {>= "0.1"}
  >     "bar" {>= "0.2"}
  > ]
  > EOF

Run the solver and generate a lock directory.

  $ dune pkg lock --opam-repository-path=mock-opam-repository
  Solution for dune.lock:
  bar.0.5.0
  baz.0.1.0
  foo.0.0.1
  

Helper to the name and contents of each file in the lock directory separated by
"---", sorting by filename for consistency.
  $ print_all() { find dune.lock -type f | sort | xargs -I{} sh -c "printf '{}:\n\n'; cat {}; printf '\n\n---\n\n'"; }

Print the contents of each file in the lockdir:
  $ print_all
  dune.lock/bar.pkg:
  
  (version 0.5.0)
  
  
  ---
  
  dune.lock/baz.pkg:
  
  (version 0.1.0)
  
  
  ---
  
  dune.lock/foo.pkg:
  
  (version 0.0.1)
  (deps baz bar)
  
  
  ---
  
  dune.lock/lock.dune:
  
  (lang package 0.1)
  
  
  ---
  

Run the solver again preferring oldest versions of dependencies:
  $ dune pkg lock --version-preference=oldest --opam-repository-path=mock-opam-repository
  Solution for dune.lock:
  bar.0.4.0
  baz.0.1.0
  foo.0.0.1
  

  $ print_all
  dune.lock/bar.pkg:
  
  (version 0.4.0)
  
  
  ---
  
  dune.lock/baz.pkg:
  
  (version 0.1.0)
  
  
  ---
  
  dune.lock/foo.pkg:
  
  (version 0.0.1)
  (deps baz bar)
  
  
  ---
  
  dune.lock/lock.dune:
  
  (lang package 0.1)
  
  
  ---
  

Regenerate the `dune-project` file introducing an unsatisfiable constraint.
  $ cat >dune-project <<EOF
  > (lang dune 3.8)
  > (package
  >  (name lockfile_generation_test)
  >  (depends
  >    foo
  >    (bar (>= "0.6"))))
  > EOF

Run the solver again. This time it will fail.
  $ dune pkg lock --opam-repository-path=mock-opam-repository
  Error: Unable to solve dependencies in build context: default
  Can't find all required versions.
  Selected: baz.0.1.0 foo.0.0.1 lockfile_generation_test.dev
  - bar -> (problem)
      foo 0.0.1 requires >= 0.2
      lockfile_generation_test dev requires >= 0.6
      Rejected candidates:
        bar.0.5.0: Incompatible with restriction: >= 0.6
        bar.0.4.0: Incompatible with restriction: >= 0.6
        bar.0.0.1: Incompatible with restriction: >= 0.2
  [1]

We'll also test how the lockfile generation works with alternate solutions.
`bar-or-baz` is a package that depends on either `bar` or `baz` and the solver
should pick one of them.

  $ cat >dune-project <<EOF
  > (lang dune 3.8)
  > (package
  >  (name lockfile_generation_test)
  >  (depends bar-or-baz))
  > EOF
  $ mkpkg bar-or-baz <<EOF
  > opam-version: "2.0"
  > depends: [ "bar" | "baz" ]
  > EOF

After running this we expact a solution that has either `bar` or `baz` but not
both.

  $ dune pkg lock --opam-repository-path=mock-opam-repository
  Solution for dune.lock:
  bar.0.5.0
  bar-or-baz.0.0.1
  
Top level or is simple, but does nested or work? nested-r defines nested or
patterns that can't be simplified

  $ cat >dune-project <<EOF
  > (lang dune 3.8)
  > (package
  >  (name lockfile_generation_test)
  >  (depends nested-or))
  > EOF
  $ emptypkg qux
  > emptypkg quz
  $ emptypkg quux
  $ emptypkg corge
  $ mkpkg nested-or <<EOF
  > opam-version: "2.0"
  > depends: [ "quux" (("baz" | "quz") & ("bar" | "qux")) ]
  > EOF

After runninng we expect the solution to have quux and either baz or quz as
well as bar or qux.

  $ dune pkg lock --opam-repository-path=mock-opam-repository
  Solution for dune.lock:
  bar.0.5.0
  baz.0.1.0
  nested-or.0.0.1
  quux.0.0.1
  
In the dependency formulas, & should bind stronger than | so if we depend on
bar and quux or baz, it should pick the first two or the last one, but nothing
in between.

  $ cat >dune-project <<EOF
  > (lang dune 3.8)
  > (package
  >  (name lockfile_generation_test)
  >  (depends priorities))
  > EOF
  $ mkpkg priorities <<EOF
  > opam-version: "2.0"
  > depends: [ ("bar" & "quux") | "baz" ]
  > EOF

  $ dune pkg lock --opam-repository-path=mock-opam-repository
  Solution for dune.lock:
  bar.0.5.0
  priorities.0.0.1
  quux.0.0.1
  
 
We also want to make sure nested negation in versions work fine. For this we
have the same package with version 1-4 and we want to negate the choice of
versions 1 or 3, as well as making sure it doesn't pick the newest version.
 
  $ emptyverpkg pkg 1
  $ emptyverpkg pkg 2
  $ emptyverpkg pkg 3
  $ emptyverpkg pkg 4
  $ cat >dune-project <<EOF
  > (lang dune 3.8)
  > (package
  >  (name lockfile_generation_test)
  >  (depends negation))
  > EOF
  $ mkpkg negation <<EOF
  > opam-version: "2.0"
  > depends: [ "pkg" {!((= "1") | (= "3")) & (< "4")} ]
  > EOF

With versions 1 and 3 negated and version 4 removed via version constraint,
we'd expect version 2 to be chosen:

  $ dune pkg lock --opam-repository-path=mock-opam-repository
  Solution for dune.lock:
  negation.0.0.1
  pkg.2
  
