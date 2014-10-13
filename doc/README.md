Tcl Web Application Framework
=============================

Introduction
------------

The Tcl Web Application Framework provides a basic framework for application
developers to write web-based applications without having to deal with some
of the common overhead associated with building web-based applications, such
as:

  1. Sessions
  2. Users
  3. Databases

It is intended to be extensible and replacable so that if the developer does
wish to do these things they can do so while retaining the remaining features.

How Does it Work ?
------------------

All calls are directed to a single dispatcher page (index.rvt), which is a
[Rivet](http://tcl.apache.org/rivet/) (or [RivetCGI](https://chiselapp.com/user/rkeene/repository/rivetcgi/)) document.  This document is the "kernel" of the Tcl Web
Application Framework.

Since Rivet (and in some cases, RivetCGI) keeps an interpreter around for
longer than a single request, we utilize the persistent global namespace to
avoid having to do the same work over for every request if it's already been
done globally.

Thus there is a distinction between the "global" or "interpreter" state and
and the "request" state time.

Because we cannot know if this is a new interpreter ahead of request-time, we
must perform all per-interpreter actions if they are needed for every request
followed by the per-request actions.

Developers may write scripts to be called as per-interpreter or per-request
scripts based on the need.  The location of the script determines whether it
is called once-per-interpreter (in which case it should update the global
state) or once-per-request (in which case it should only modify the request
state, such as the ::request namespace or output to the HTTP stream).


Per-Interpreter Paths
---------------------

  1. `modules/load/onlyonce/dbconfig.tcl`
  2. `local/modules/load/onlyonce/dbconfig.tcl`
  3. `local/modules/*/preload/*.tcl`
  4. `modules/*/load/*.tcl`
  5. `modules/load/onlyonce/*.tcl`
  6. `local/modules/*/load/*.tcl`
  7. `local/modules/load/onlyonce/*.tcl`


Per-Request Paths
-----------------

  1. `local/modules/preload/*.tcl` (before the page is displayed)
  2. `modules/load/*.tcl` (before the page is displayed)
  3. `local/modules/load/*.tcl` (before the page is displayed)
  4. `modules/unload/*.tcl` (after the page is displayed)
  5. `local/modules/unload/*.tcl` (after the page is displayed)


Request Processing Is Distinct From Output Processing
-----------------------------------------------------

In the Tcl Web Application Framework, generated output is handled by displaying
Rivet fragments.  These fragments are returned by various modules and the order
determines what the output will be.  The "html" module, for example, supplies
an HTML header and footer (using `[::tclwebappframework::register_initmod]`)
which are Rivet fragments displayed before and after the requested module's
Rivet fragments.

A small note should be made here that all Tcl procedures are called (except for
the "unload" scripts are `[source]`d) before any output is produced.

That is, request processing (taking the user request and deciding what to do
with it by dispatching Rivet fragments is performed entirely before displaying
any Rivet fragments.

The primary benefit to this is that any Tcl procedure called will be evaluated
prior to any Rivet fragments being parsed, so when Rivet fragments are parsed
they are all parsed with the same state (except for any state the Rivet
fragments themselves modify, which is generally bad form).

This is used, for example, to modify CSS from a module's action which is then
parsed and displayed as part of the HTML header's Rivet fragment.


Writing Your Application
========================

All resources for your application should live in the "local" directory
relative to "index.rvt".  This allows for the framework to be replaced around
your application without affecting your application.

As above, the "local" tree is searched along with the framework paths.  In
addition many of the commands from other packages will prefer a "local/"
path if a replacement file can be found there.  Example commands are:

  1. `[display]`
  2. `[web::image]`

Modules
-------
The basic unit of an application is called a "module".  Modules have a simple
structure and are registered using the [module::register] command.

The first thing a module needs is a name.  This name is also the name of the
namespace the module will provide some well-known named functions from.

Generally the module directory name and the module name should be the same.
In that case, if we were creating a module called "example" we would create:

  1. `local/modules/example` (directory)
  2. `local/modules/example/load/example.tcl` (file, per-interpreter script)
  3. `local/modules/example/main.rvt` (file, Rivet script)

The file (all paths will be relative to the module directory of
"local/modules/example") "load/example.tcl" should do all of the
per-interpreter initialization to make this module useful and ready to use for
a request.  That includes:

  1. Creating a namespace named after the module
  2. Creating a procedure called "init" in that namespace (`[::example::init]`)
    which must return some form of "true"
  3. Registering the module with `[module::register]`
  4. Optionally a module may be requested to be called as an "initialization
     module", which means it will accept a "start", "stop", "pre-request" and
     "post-request" action by calling `[::tclwebappframework::register_initmod]`.


