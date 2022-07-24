# ocaml-crunch — convert a filesystem into a static OCaml module

`ocaml-crunch` takes a directory of files and compiles them into a standalone
OCaml module which serves the contents directly from memory.  This can be
convenient for libraries that need a few embedded files (such as a web server)
and do not want to deal with all the trouble of file configuration.

Run `ocaml-crunch --help` for more information:

```
NAME
       ocaml-crunch - Convert a directory structure into a standalone OCaml
       module that can serve the file contents without requiring an external
       filesystem to be present.

SYNOPSIS
       ocaml-crunch [--ext=VALID EXTENSION] [--mode=MODE] [--output=OUTPUT]
       [OPTION]… DIRECTORIES…

ARGUMENTS
       DIRECTORIES (required)
           Directories to recursively walk and crunch.

OPTIONS
       -e VALID EXTENSION, --ext=VALID EXTENSION
           If specified, only these extensions will be included in the
           crunched output. If not specified, then all files will be crunched
           into the output module.

       -m MODE, --mode=MODE (absent=lwt)
           Interface access mode: either lwt or plain. lwt is the default.

       -o OUTPUT, --output=OUTPUT
           Output file for the OCaml module.

       -s, --silent
           Silent mode.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

       --version
           Show version information.

EXIT STATUS
       ocaml-crunch exits with the following status:

       0   on success.

       123 on indiscriminate errors reported on standard error.

       124 on command line parsing errors.

       125 on unexpected internal errors (bugs).

ENVIRONMENT
       These environment variables affect the execution of ocaml-crunch:

       SOURCE_DATE_EPOCH
           Specifies the last modification of crunched files for reproducible
           output.

BUGS
       Email bug reports to <mirage-devel@lists.xenproject.org>.
```
