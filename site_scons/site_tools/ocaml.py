# Ocaml Tool
# version: 0.2 (12/30/2005)
#
# TODO:
# - testing
# - make it portable (currently only tested on Unix)
# - Lex and Yacc builders
#
# Originally based on: http://www.scons.org/wiki/OcamlBuilder , accessed 11-2-2014

import os
def read_command(cmd):
        """
        Execute the command cmd and return output
        """
        return os.popen(cmd).readlines()
def when_code(env, bytecode, native, toplevel=None):
        """
        Return value depending on output code kind wanted
        """
        if toplevel == None:
                toplevel = bytecode
        if env['OCAML_CODE'] == 'bytecode':
                r = bytecode
        elif env['OCAML_CODE'] == 'native':
                r = native
        elif env['OCAML_CODE'] == 'toplevel':
                r = toplevel
        else:
                print "$OCAML_CODE must be either 'toplevel', 'bytecode' or 'native'"
                env.Exit(1)
        return r
def obj_suffix(env):
        return when_code(env, '.cmo', '.cmx')
def lib_suffix(env):
        return when_code(env, '.cma', '.cmxa')
def set_suffix(f, suffix):
        b, e = os.path.splitext(str(f))
        return b+suffix
def obj_of_src(f, env):
        return set_suffix(f, obj_suffix(env))
def iface_of_src(f):
        return set_suffix(f, '.cmi')
def comp(env):
        """
        Choose a compiler depending on environment variables
        """
        return when_code(env, '$OCAMLC', '$OCAMLOPT', '$OCAMLMKTOP')
def flags(env, t=''):
        """
        Generate flags depending on environment variables
        """
        s = when_code(env, '$OCAMLC_FLAGS', '$OCAMLOPT_FLAGS', '$OCAMLMKTOP_FLAGS')
        if env['OCAML_DEBUG']:
                s += when_code(env, ' -g', '')
        if env['OCAML_PROFILE']:
                s += when_code(env, '', ' -p')
        if env['OCAML_PP']:
                s += ' -pp %s' % env['OCAML_PP']
        if t == 'lib':
                s += ' -a'
        elif t == 'obj':
                s += ' -c'
        elif t == 'pack':
                s += ' -pack'
        return s
def is_installed(exe):
        """
        Return True if an executable is found in path
        """
        path = os.environ['PATH'].split(':')
        for p in path:
                if os.path.exists( os.path.join(p, exe) ):
                        return True
        return False
def norm_suffix(f, suffix):
        """
        Add a suffix if not present
        """
        p = str(f)
        e = p[-len(suffix):]
        if e != suffix:
                p = p + suffix
        return p
def norm_suffix_list(files, suffix):
        return map(lambda x: norm_suffix(x, suffix), files)
def find_packages(env):
        """
        Use ocamlfind to retrieve libraries paths from package names
        """
        packs = env.Split(env['OCAML_PACKS'])
        if not is_installed(env['OCAMLFIND']):
                if len(packs):
                        print "Warning: ocamlfind not found, ignoring ocaml packages"
                return ""
        s = "%s query %%s -separator ' ' %s" % (
                env['OCAMLFIND'], " ".join( packs)
        )
        # Standard bits
        i = read_command(s % '-i-format')
        l = read_command(s % '-l-format')
        code = when_code(env, 'byte', 'native')
        a = read_command(s % '-predicates %s -a-format' % code)
        r = " %s %s %s " % ( l[0][:-1], i[0][:-1], a[0][:-1] ) #-1 to snip newline
        # One more check: Do we need a ppx processor?
        ppx = ''
        for pack in packs:
                package_dir = read_command(s % '')[0][:-1]
                ppx_path = os.path.join(package_dir, 'ppx_' + pack)
                if is_installed(ppx_path):
                        if ppx:
                                ppx += " "
                        ppx += ("-ppx " + ppx_path)
        r += ppx
        return r
def cleaner(files, env, lib=False):
        files = map(str, files)
        r = []
        for f in files:
                r.append(obj_of_src(f, env))
                r.append(iface_of_src(f))
                if env['OCAML_CODE'] == 'native':
                        r.append(set_suffix(f, '.o'))
                        if lib:
                                r.append(set_suffix(f, '.a'))
        return r
def scanner(node, env, path):
        objs = norm_suffix_list(env['OCAML_OBJS'], obj_suffix(env))
        libs = norm_suffix_list(env['OCAML_LIBS'], lib_suffix(env))
        return libs+objs
prog_scanner = lib_scanner = obj_scanner = pack_scanner = scanner
def lib_emitter(target, source, env):
        t = norm_suffix(str(target[0]), lib_suffix(env))
        env.Clean(t, cleaner(source, env, lib=True))
        return (t, source)
def obj_emitter(target, source, env):
        t = norm_suffix(str(target[0]), obj_suffix(env))
        env.Clean(t, cleaner(source+[t], env))
        return (t, source)
def pack_emitter(target, source, env):
        t = norm_suffix(str(target[0]), obj_suffix(env))
        s = norm_suffix_list(source, obj_suffix(env))
        env.Clean(t, cleaner(source+[t], env))
        return (t, source)
def prog_emitter(target, source, env):
        env.Clean(target, cleaner(source, env))
        return (target, source)
def command_gen(source, target, env, comp, flags):
        """
        Generate command
        """
        target = str(target[0])
        objs = norm_suffix_list(env['OCAML_OBJS'], obj_suffix(env))
        objs = " ".join( objs )
        libs = norm_suffix_list(env['OCAML_LIBS'], lib_suffix(env))
        libs = " ".join( libs )
        inc = map(lambda x:'-I '+x, env['OCAML_PATH'])
        inc = " ".join(inc) + find_packages(env)
        s = ("%s %s -o %s %s %s %s $SOURCES" %
                        (comp, flags, target, inc, libs, objs)
        )
        return s
def obj_gen(source, target, env, for_signature):
        return command_gen( source, target, env, comp(env), flags(env, 'obj'))
def pack_gen(source, target, env, for_signature):
        return command_gen(source, target, env, comp(env), flags(env, 'pack'))
def lib_gen(source, target, env, for_signature):
        return command_gen( source, target, env, comp(env), flags(env, 'lib'))
def prog_gen(source, target, env, for_signature):
        return command_gen(source, target, env, comp(env), flags(env))
def generate(env):
        """
        Add Builders and construction variables for Ocaml to an Environment.
        """
        prog_scan = env.Scanner(prog_scanner)
        lib_scan = env.Scanner(lib_scanner)
        obj_scan = env.Scanner(obj_scanner)
        pack_scan = env.Scanner(pack_scanner)
        env.Append(BUILDERS = {
                'OcamlObject': env.Builder(
                        generator=obj_gen,
                        emitter=obj_emitter,
                        source_scanner=obj_scan
                ),
                # Pack several object into one object file
                'OcamlPack': env.Builder(
                        generator=pack_gen,
                        emitter=pack_emitter,
                        source_scanner=pack_scan
                ),
                'OcamlLibrary': env.Builder(
                        generator=lib_gen,
                        emitter=lib_emitter,
                        source_scanner=lib_scan
                ),
                'OcamlProgram': env.Builder(
                        generator=prog_gen,
                        emitter=prog_emitter,
                        source_scanner=prog_scan
                )
        })
        env.AppendUnique(
                OCAMLC='ocamlc',
                OCAMLOPT='ocamlopt',
                OCAMLMKTOP='ocamlmktop',
                OCAMLFIND='ocamlfind',
                #OCAMLDEP='ocamldep',           # not used
                OCAML_PP='',                            # not needed by default
                OCAML_DEBUG=0,
                OCAML_PROFILE=0,
                OCAMLC_FLAGS='',
                OCAMLOPT_FLAGS='',
                OCAMLMKTOP_FLAGS='',
                OCAML_LIBS=[],
                OCAML_OBJS=[],
                OCAML_PACKS=[],
                OCAML_PATH=[],
                OCAML_CODE=''                           # bytecode, toplevel or native
        )
def exists(env):
        return env.Detect('ocaml')

