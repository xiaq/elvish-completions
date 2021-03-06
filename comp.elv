use re
use github.com/zzamboni/elvish-modules/util

fn decorate [@input &code-suffix='' &display-suffix='' &suffix='' &style='']{
  if (eq (count $input) 0) {
    input = [(all)]
  }
  if (not-eq $suffix '') {
    display-suffix = $suffix
    code-suffix = $suffix
  }
  each [k]{
    edit:complex-candidate &code-suffix=$code-suffix &display-suffix=$display-suffix &style=$style $k
  } $input
}

fn empty { nop }

fn files [arg &regex='' &dirs-only=$false]{
  put {$arg}*[match-hidden][nomatch-ok] | each [x]{
    if (and (or (not $dirs-only) (-is-dir $x)) (or (eq $regex '') (re:match $regex $x))) {
      put $x
    }
  }
}

fn extract-opts [@cmd &regex='(?:-(\w),\s*)?--([\w-]+).*?\s\s(\w.*)$']{
  all | each [l]{
  re:find $regex $l } | each [m]{
    short long desc = $m[groups][1 2 3][text]
    opt = [&]
    if (not-eq $short '') { opt[short] = $short }
    if (not-eq $long  '') { opt[long]  = $long  }
    if (not-eq $desc  '') { opt[desc]  = $desc  }
    if (or (has-key $opt short) (has-key $opt long)) {
      put $opt
    }
  }
}

# Forward declarations to be overriden later
fn sequence { }
fn subcommands { }

fn expand [def @cmd]{
  arg = $cmd[-1]
  what = (kind-of $def)
  if (eq $what 'fn') {
    fnargs = [ (count $def[arg-names]) (not-eq $def[rest-arg] '') ]
    if (eq $fnargs [ 0 $false ]) {
      $def
    } elif (eq $fnargs [ 1 $false ]) {
      $def $arg
    } elif (eq $fnargs [ 0 $true ]) {
      $def $@cmd
    }
  } elif (eq $what 'list') {
    explode $def
  } elif (eq $what 'map') {
    if (has-key $def '-seq') {
      sequence $def $@cmd
    } else {
      subcommands $def $@cmd
    }
  }
}

sequence~ = [def @cmd]{

opts = []
if (has-key $def -opts) {
  expand $def[-opts] $@cmd | each [opt]{
    if (eq (kind-of $opt) map) {
      opts = [ $@opts $opt ]
    } else {
      opts = [$@opts [&long= $opt]]
    }
  }
}

handlers = []
explode $def[-seq] | each [f]{
  new-f = $f
  if (eq (kind-of $f) 'fn') {
    fnargs = [ (count $f[arg-names]) (not-eq $f[rest-arg] '') ]
    if (eq $fnargs [ 0 $false ]) {
      new-f = [_]{ $f }
    } elif (eq $fnargs [ 1 $false ]) {
      new-f = $f
    } elif (eq $fnargs [ 0 $true ]) {
      new-f = [_]{ $f $@cmd }
    }
  } elif (eq (kind-of $f) 'list') {
    new-f = [_]{ explode $f }
  }
  handlers = [ $@handlers $new-f ]
}

edit:complete-getopt $cmd[1:] $opts $handlers
}

subcommands~ = [def @cmd]{
  subcommands = [(keys (dissoc $def -opts))]
  first-subcommand = [(range 1 (count $cmd) | each [i]{
        if (has-value $subcommands $cmd[$i]) { put $cmd[$i] $i }
  })]
  if (not-eq $first-subcommand []) {
    subcommand subcommand-pos = $first-subcommand[0 1]
    if (eq (kind-of $def[$subcommand]) 'string') {
      subcommands $def (explode $cmd[0:$subcommand-pos]) $def[$subcommand] (explode $cmd[(+ $subcommand-pos 1):])
    } else {
      expand $def[$subcommand] (explode $cmd[{$subcommand-pos}:])
    }
  } else {
    top-def = [ &-seq= [ { put $@subcommands }] ]
    if (has-key $def -opts) {
      top-def[-opts] = $def[-opts]
    }
    sequence $top-def $@cmd
  }
}

fn -wrapper-gen [func]{
  put [def]{ put [@cmd]{ $func $def $@cmd } }
}

expand-wrapper~ = (-wrapper-gen $expand~)
sequence-wrapper~ = (-wrapper-gen $sequence~)
subcommands-wrapper~ = (-wrapper-gen $subcommands~)
