# Makefile (C/C++; OOS-build support; gmake-form/style; v2022.10.14)
# Cross-platform (bash/sh + CMD/PowerShell)
# `bcc32`, `cl`, `clang`, `embcc32`, and `gcc` (defaults to `CC=clang`)
# * supports multi-binary projects; adapts to project structure
# GNU make (gmake) compatible; ref: <https://www.gnu.org/software/make/manual>
# Copyright (C) 2020-2022 ~ Roy Ivy III <rivy.dev@gmail.com>; MIT+Apache-2.0 license

# NOTE: * requires `make` version 4.0+ (minimum needed for correct path functions); for windows, install using `scoop install make`
# NOTE: `make` doesn't handle spaces within file names without gyrations (see <https://stackoverflow.com/questions/9838384/can-gnu-make-handle-filenames-with-spaces>@@<https://archive.is/PYKKq>)
# NOTE: `make -d` will display full debug output (`make` and makefile messages) during the build/make process
# NOTE: `make MAKEFLAGS_debug=1` will display just the makefile debug messages during the build/make process
# NOTE: use `make ... run -- <OPTIONS>` to pass options to the run TARGET; otherwise, `make` will interpret the options as targeted for itself

# ToDO: investigate portably adding resources to executables; ref: [Embed Resources into Executables](https://caiorss.github.io/C-Cpp-Notes/resources-executable.html) @@ <https://archive.is/pjDzW>
# FixME: [2021-09-26; rivy] clang `llvm-rc` is broken (not preprocessing; see <https://bugzilla.mozilla.org/show_bug.cgi?id=1537703#c1> @@ <https://archive.is/fK3Vi>)
# *=> for `clang` builds requiring resources, `clang` will utilize `windres`, if found on PATH, otherwise gracefully degrades by skipping the resource entirely and linking an empty object file
# * [2022-09-28; rivy] llvm-rc v13 to v15 are still broken when expanding macros

# `make [ARCH=32|64|..] [CC=cl|clang|gcc|..] [CC_DEFINES=<truthy>] [DEBUG=<truthy>] [STATIC=<truthy>] [SUBSYSTEM=console|windows|..] [TARGET=..] [COLOR=<truthy>] [MAKEFLAGS_debug=<truthy>] [VERBOSE=<truthy>] [MAKE_TARGET...]`

####

# spell-checker:ignore (project)

# spell-checker:ignore (targets) realclean vclean veryclean
# spell-checker:ignore (make) BASEPATH CURDIR MAKECMDGOALS MAKEFLAGS SHELLSTATUS TERMERR TERMOUT abspath addprefix addsuffix endef eval findstring firstword gmake ifeq ifneq lastword notdir patsubst prepend undefine wordlist
#
# spell-checker:ignore (CC) DDEBUG DNDEBUG NDEBUG Ofast Werror Wextra Wlinker Xclang Xlinker bcc dumpmachine embcc flto flto-visibility-public-std fpie msdosdjgpp mthreads nodefaultlib nologo nothrow psdk Wpedantic
# spell-checker:ignore (abbrev/acronyms) LCID LCIDs LLVM MSVC MinGW MSDOS POSIX VCvars WinMain
# spell-checker:ignore (jargon) autoset deps depfile depfiles delims executables maint multilib
# spell-checker:ignore (libraries) advapi crtl libcmt libcmtd libgcc libstdc lmsvcrt lmsvcrtd lstdc stdext wsock
# spell-checker:ignore (names) benhoyt rivy Borland Deno Watcom
# spell-checker:ignore (shell/nix) mkdir printf rmdir uname
# spell-checker:ignore (shell/win) COMSPEC SystemDrive SystemRoot findstr findstring mkdir windir
# spell-checker:ignore (utils) goawk ilink windres vcpkg
# spell-checker:ignore (vars) CFLAGS CLICOLOR CPPFLAGS CXXFLAGS DEFINETYPE EXEEXT LDFLAGS LDXFLAGS LIBPATH LIBs MAKEDIR OBJ_deps OBJs OSID PAREN RCFLAGS REZ REZs devnull dotslash falsey fileset filesets globset globsets punct truthy

####

NAME := $()## $()/empty/null => autoset to name of containing folder

SRC_PATH := $()## path to source relative to makefile (defaults to first of ['src','source']); used to create ${SRC_DIR} which is then used as the source base directory path
BUILD_PATH := $()## path to build storage relative to makefile (defaults to '#build'); used to create ${BUILD_DIR} which is then used as the base path for build outputs

DEPS = $()## list of any additional required (common/shared) dependencies (space-separated); note: use delayed expansion (`=`, not `:=`) if referencing a later defined variable (eg, `{SRC_DIR}/defines.h`)
INC_DIRS = $()## list of any additional required (common/shared) include directories (space-separated; defaults to `${BASEPATH}`); note: use delayed expansion (`=`, not `:=`) if referencing a later defined variable (eg, `{SRC_DIR}/defines.h`)
LIB_DIRS = $()## list of any additional required (common/shared) libraries (space-separated); alternatively, *if not using `gcc`*, `#pragma comment(lib, "LIBRARY_NAME")` within code; ref: [`gcc` pragma library?](https://stackoverflow.com/questions/1685206)@@<https://archive.ph/wip/md6Af>; note: use delayed expansion (`=`, not `:=`) if referencing a later defined variable (eg, `{SRC_DIR}/defines.h`)
RES = $()## list of any additional required (common/shared) resources (space-separated); note: use delayed expansion (`=`, not `:=`) if referencing a later defined variable (eg, `{SRC_DIR}/defines.h`)

####

# `make ...` command line flag/option defaults
ARCH := $()## default ARCH for compilation ([$(),...]); $()/empty/null => use CC default ARCH
CC_DEFINES := false## provide compiler info (as `CC_...` defines) to compiling targets ('truthy'-type)
# * COLOR ~ defaults to "auto" mode ("on/true" if STDOUT is tty, "off/false" if STDOUT is redirected); respects CLICOLOR/CLICOLOR_FORCE and NO_COLOR (but overridden by `COLOR=..` on command line); refs: <https://bixense.com/clicolors> , <https://no-color.org>
COLOR := $(or $(if ${CLICOLOR_FORCE},$(if $(filter 0,${CLICOLOR_FORCE}),$(),true),$()),$(if ${MAKE_TERMOUT},$(if $(or $(filter 0,${CLICOLOR}),${NO_COLOR}),$(),true),$()))## enable colorized output ('truthy'-type)
DEBUG := false## enable compiler debug flags/options ('truthy'-type)
STATIC := true## compile to statically linked executable ('truthy'-type)
VERBOSE := false## verbose `make` output ('truthy'-type)
MAKEFLAGS_debug := $(if $(findstring d,${MAKEFLAGS}),true,false)## Makefile debug output ('truthy'-type; default == false) ## NOTE: use `-d` or `MAKEFLAGS_debug=1`, `--debug[=FLAGS]` does not set MAKEFLAGS correctly (see <https://savannah.gnu.org/bugs/?func=detailitem&item_id=58341>)

####

MAKE_VERSION_major := $(word 1,$(subst ., ,${MAKE_VERSION}))
MAKE_VERSION_minor := $(word 2,$(subst ., ,${MAKE_VERSION}))

# require at least `make` v4.0 (minimum needed for correct path functions)
MAKE_VERSION_fail := $(filter ${MAKE_VERSION_major},3 2 1 0)
ifeq (${MAKE_VERSION_major},4)
MAKE_VERSION_fail := $(filter ${MAKE_VERSION_minor},)
endif
ifneq (${MAKE_VERSION_fail},)
# $(call %error,`make` v4.0+ required (currently using v${MAKE_VERSION}))
$(error ERR!: `make` v4.0+ required (currently using v${MAKE_VERSION}))
endif

makefile_path := $(lastword ${MAKEFILE_LIST})## note: *must* precede any makefile imports (ie, `include ...`)

makefile_abs_path := $(abspath ${makefile_path})
makefile_dir := $(abspath $(dir ${makefile_abs_path}))
make_invoke_alias ?= $(if $(filter-out Makefile,${makefile_path}),${MAKE} -f "${makefile_path}",${MAKE})
current_dir := ${CURDIR}
makefile_set := $(wildcard ${makefile_path} ${makefile_path}.config ${makefile_path}.target)
makefile_set_abs := $(abspath ${makefile_set})

#### * determine OS ID

OSID := $(or $(and $(filter .exe,$(patsubst %.exe,.exe,$(subst $() $(),_,${SHELL}))),$(filter win,${OS:Windows_NT=win})),nix)## OSID == [nix,win]
# for Windows OS, set SHELL to `%ComSpec%` or `cmd` (note: environment/${OS}=="Windows_NT" for XP, 2000, Vista, 7, 10 ...)
# * `make` may otherwise use an incorrect shell (eg, `bash`), if found; "syntax error: unexpected end of file" error output is indicative
ifeq (${OSID},win)
# use case and location fallbacks; note: assumes *no spaces* within the path values specified by ${ComSpec}, ${SystemRoot}, or ${windir}
COMSPEC := $(or ${ComSpec},${COMSPEC},${comspec})
SystemRoot := $(or ${SystemRoot},${SYSTEMROOT},${systemroot},${windir})
SHELL := $(firstword $(wildcard ${COMSPEC} ${SystemRoot}/System32/cmd.exe) cmd)
endif

#### * determine compiler ID

# * default to `clang` (with fallback to `gcc`; via a portable shell test)
CC := $(and $(filter-out default,$(origin CC)),${CC})## use any non-Makefile defined value as default; * used to avoid a recursive definition of ${CC} within the the shell ${CC} presence check while determining default ${CC}
CC := $(or ${CC},$(subst -FOUND,,$(filter clang-FOUND,$(shell clang --version 2>&1 && echo clang-FOUND || echo))),gcc)

CC_ID := $(lastword $(subst -,$() $(),${CC}))

#### * ARCH constants

ARCH_default := i686
ARCH_x86 := i386 i586 i686 x86
ARCH_x86_64 := amd64 x64 x86_64 x86_amd64
ARCH_32 := 32 x32 ${ARCH_x86}
ARCH_64 := 64 ${ARCH_x86_64}

#### * determine BASEPATH

# use ${BASEPATH} as an anchor to allow otherwise relative path specification of files
ifneq (${makefile_dir},${current_dir})
BASEPATH := ${makefile_dir:${current_dir}/%=%}
# BASEPATH := $(patsubst ./%,%,${makefile_dir:${current_dir}/%=%}/)
endif
ifeq (${BASEPATH},)
BASEPATH := .
endif

#### * constants and methods

falsey_list := false 0 f n never no none off
falsey := $(firstword ${falsey_list})
false := $()
true := true
truthy := ${true}

devnull := $(if $(filter win,${OSID}),NUL,/dev/null)
int_max := 2147483647## largest signed 32-bit integer; used as arbitrary max expected list length

NULL := $()
BACKSLASH := $()\$()
COMMA := ,
DOLLAR := $$
DOT := .
ESC := $()$()## literal ANSI escape character (required for ANSI color display output; also used for some string matching)
HASH := \#
PAREN_OPEN := $()($()
PAREN_CLOSE := $())$()
SLASH := /
SPACE := $() $()

[lower] := a b c d e f g h i j k l m n o p q r s t u v w x y z
[upper] := A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
[alpha] := ${[lower]} ${[upper]}
[digit] := 1 2 3 4 5 6 7 8 9 0
[punct] := ~ ` ! @ ${HASH} ${DOLLAR} % ^ & * ${PAREN_OPEN} ${PAREN_CLOSE} _ - + = { } [ ] | ${BACKSLASH} : ; " ' < > ${COMMA} ? ${SLASH} ${DOT}

%not = $(if ${1},${false},$(or ${1},${true}))
%eq = $(or $(and $(findstring ${1},${2}),$(findstring ${2},${1})),$(if ${1}${2},${false},${true}))# note: `call %eq,$(),$()` => ${true}
%neq = $(if $(call %eq,${1},${2}),${false},$(or ${1},${2},${true}))# note: ${1} != ${2} => ${false}; ${1} == ${2} => first non-empty value (or ${true})

# %falsey := $(firstword ${falsey})
# %truthy := $(firstword ${truthy})

%as_truthy = $(if $(call %is_truthy,${1}),${truthy},${falsey})# note: returns 'truthy'-type text value (eg, true => 'true' and false => 'false')
%is_truthy = $(if $(filter-out ${falsey_list},$(call %lc,${1})),${1},${false})# note: returns `make`-type boolean value (eg, true => non-empty and false => $()/empty/null)
%is_falsey = $(call %not,$(call %is_truthy,${1}))# note: returns `make`-type boolean value (eg, true => non-empty and false => $()/empty/null)

%range = $(if $(word ${1},${2}),$(wordlist 1,${1},${2}),$(call %range,${1},${2} $(words _ ${2})))
%repeat = $(if $(word ${2},${1}),$(wordlist 1,${2},${1}),$(call %repeat,${1} ${1},${2}))

%head = $(firstword ${1})
%tail = $(wordlist 2,${int_max},${1})
%chop = $(wordlist 2,$(words ${1}),_ ${1})
%append = ${2} ${1}
%prepend = ${1} ${2}
%length = $(words ${1})

%_position_ = $(if $(findstring ${1},${2}),$(call %_position_,${1},$(wordlist 2,$(words ${2}),${2}),_ ${3}),${3})
%position = $(words $(call %_position_,${1},${2}))

%map = $(foreach elem,${2},$(call ${1},${elem}))# %map(fn,list) == [ fn(list[N]),... ]
%filter_by = $(strip $(foreach elem,${3},$(and $(filter $(call ${1},${2}),$(call ${1},${elem})),${elem})))# %filter_by(fn,item,list) == [ list[N] iff fn(item)==fn(list[N]), ... ]
%uniq = $(if ${1},$(firstword ${1}) $(call %uniq,$(filter-out $(firstword ${1}),${1})))

%none = $(if $(call %map,${1},${2}),${false},${true})## %none(fn,list) => all of fn(list_N) == ""
%some = $(if $(call %map,${1},${2}),${true},${false})## %some(fn,list) => any of fn(list_N) != ""
%any = %some## %any(), aka %some(); %any(fn,list) => any of fn(list_N) != ""
%all = $(if $(call %map,%not,$(call %map,${1},${2})),${false},${true})## %all(fn,list) => all of fn(list_N) != ""

%cross = $(foreach a,${2},$(foreach b,${3},$(call ${1},${a},${b})))# %cross(fn,listA,listB) == [ fn(listA[N],listB[M]), ... {for all combinations of listA and listB }]
%join = $(subst ${SPACE},${1},$(strip ${2}))# %join(text,list) == join all list elements with text
%replace = $(foreach elem,${3},$(foreach pat,${1},${elem:${pat}=${2}}))# %replace(pattern(s),replacement,list) == [ ${list[N]:pattern[M]=replacement}, ... ]

%tr = $(strip $(if ${1},$(call %tr,$(wordlist 2,$(words ${1}),${1}),$(wordlist 2,$(words ${2}),${2}),$(subst $(firstword ${1}),$(firstword ${2}),${3})),${3}))
%lc = $(call %tr,${[upper]},${[lower]},${1})
%uc = $(call %tr,${[lower]},${[upper]},${1})

%as_nix_path = $(subst \,/,${1})
%as_win_path = $(subst /,\,${1})
%as_os_path = $(call %as_${OSID}_path,${1})

%strip_leading_cwd = $(patsubst ./%,%,${1})# %strip_leading_cwd(list) == normalize paths; stripping any leading './'
%strip_leading_dotslash = $(patsubst ./%,%,${1})# %strip_leading_dotslash(list) == normalize paths; stripping any leading './'

%dirs_in = $(dir $(wildcard ${1:=/*/.}))
%filename = $(notdir ${1})
%filename_base = $(basename $(notdir ${1}))
%filename_ext = $(suffix ${1})
%filename_stem = $(firstword $(subst ., ,$(basename $(notdir ${1}))))
%recursive_wildcard = $(strip $(foreach entry,$(wildcard ${1:=/*}),$(strip $(call %recursive_wildcard,${entry},${2}) $(filter $(subst *,%,${2}),${entry}))))

%filter_by_stem = $(call %filter_by,%filename_stem,${1},${2})

# * `%is_gui()` tests filenames for a match to '*[-.]gui{${EXEEXT},.${O}}'
%is_gui = $(if $(or $(call %is_gui_exe,${1}),$(call %is_gui_obj,${1})),${1},${false})
%is_gui_exe = $(if $(and $(patsubst %-gui${EXEEXT},,${1}),$(patsubst %.gui${EXEEXT},,${1})),${false},${1})
%is_gui_obj = $(if $(and $(patsubst %-gui.${O},,${1}),$(patsubst %.gui.${O},,${1})),${false},${1})

# %any_gui = $(if $(foreach file,${1},$(call %is_gui,${file})),${true},${false})
# %all_gui = $(if $(foreach file,${1},$(call %not,$(call %is_gui,${file}))),${false},${true})
# %any_gui = $(call %any,%is_gui,${1})
# %all_gui = $(call %all,%is_gui,${1})

ifeq (${OSID},win)
%rm_dir = $(shell if EXIST $(call %as_win_path,${1}) ${RMDIR} $(call %as_win_path,${1}) >${devnull} 2>&1 && ${ECHO} ${true})
%rm_file = $(shell if EXIST $(call %as_win_path,${1}) ${RM} $(call %as_win_path,${1}) >${devnull} 2>&1 && ${ECHO} ${true})
%rm_file_globset = $(shell for %%G in ($(call %as_win_path,${1})) do ${RM} "%%G" >${devnull} 2>&1 && ${ECHO} ${true})
else
%rm_dir = $(shell ls -d ${1} >${devnull} 2>&1 && { ${RMDIR} ${1} >${devnull} 2>&1 && ${ECHO} ${true}; } || true)
%rm_file = $(shell ls -d ${1} >${devnull} 2>&1 && { ${RM} ${1} >${devnull} 2>&1 && ${ECHO} ${true}; } || true)
%rm_file_globset = $(shell for file in ${1}; do ls -d "$${file}" >${devnull} 2>&1 && ${RM} "$${file}"; done && ${ECHO} "${true}"; done)
endif
%rm_dirs = $(strip $(call %map,%rm_dir,${1}))
%rm_dirs_verbose = $(strip $(call %map,$(eval %f=$$(if $$(call %rm_dir,$${1}),$$(call %info,$${1} removed),))%f,${1}))
%rm_files = $(strip $(call %map,%rm_file,${1}))
%rm_files_verbose = $(strip $(call %map,$(eval %f=$$(if $$(call %rm_file,$${1}),$$(call %info,$${1} removed),))%f,${1}))
%rm_file_globsets = $(strip $(call %map,%rm_file_globset,${1}))
%rm_file_globsets_verbose = $(strip $(call %map,$(eval %f=$$(if $$(call %rm_file_globset,$${1}),$$(call %info,$${1} removed),))%f,${1}))

%rm_dirs_verbose_cli = $(call !shell_noop,$(call %rm_dirs_verbose,${1}))

ifeq (${OSID},win)
%shell_escape = $(call %tr,^ | < > %,^^ ^| ^< ^> ^%,${1})
else
%shell_escape = '$(call %tr,','"'"',${1})'
endif

ifeq (${OSID},win)
%shell_quote = "$(call %shell_escape,${1})"
else
%shell_quote = $(call %shell_escape,${1})
endif

# ref: <https://superuser.com/questions/10426/windows-equivalent-of-the-linux-command-touch/764716> @@ <https://archive.is/ZjFSm>
ifeq (${OSID},win)
%touch_cli = type NUL >> $(call %as_win_path,${1}) & copy >NUL /B $(call %as_win_path,${1}) +,, $(call %as_win_path,${1})
else
%touch_cli = touch ${1}
endif

@mkdir_rule = ${1} : ${2} ; ${MKDIR} $(call %shell_quote,$$@)

!shell_noop = ${ECHO} >${devnull}

####

override COLOR := $(call %as_truthy,$(or $(filter-out auto,$(call %lc,${COLOR})),${MAKE_TERMOUT}))
override DEBUG := $(call %as_truthy,${DEBUG})
override STATIC := $(call %as_truthy,${STATIC})
override VERBOSE := $(call %as_truthy,${VERBOSE})

override MAKEFLAGS_debug := $(call %as_truthy,$(or $(call %is_truthy,${MAKEFLAGS_debug}),$(call %is_truthy,${MAKEFILE_debug})))

####

color_black := $(if $(call %is_truthy,${COLOR}),${ESC}[0;30m,)
color_blue := $(if $(call %is_truthy,${COLOR}),${ESC}[0;34m,)
color_cyan := $(if $(call %is_truthy,${COLOR}),${ESC}[0;36m,)
color_green := $(if $(call %is_truthy,${COLOR}),${ESC}[0;32m,)
color_magenta := $(if $(call %is_truthy,${COLOR}),${ESC}[0;35m,)
color_red := $(if $(call %is_truthy,${COLOR}),${ESC}[0;31m,)
color_yellow := $(if $(call %is_truthy,${COLOR}),${ESC}[0;33m,)
color_white := $(if $(call %is_truthy,${COLOR}),${ESC}[0;37m,)
color_bold := $(if $(call %is_truthy,${COLOR}),${ESC}[1m,)
color_dim := $(if $(call %is_truthy,${COLOR}),${ESC}[2m,)
color_reset := $(if $(call %is_truthy,${COLOR}),${ESC}[0m,)
#
color_command := ${color_dim}
color_path := $()
color_target := ${color_green}
color_success := ${color_green}
color_failure := ${color_red}
color_debug := ${color_cyan}
color_info := ${color_blue}
color_warning := ${color_yellow}
color_error := ${color_red}

%error_text = ${color_error}ERR!:${color_reset} ${1}
%debug_text = ${color_debug}debug:${color_reset} ${1}
%info_text = ${color_info}info:${color_reset} ${1}
%success_text = ${color_success}SUCCESS:${color_reset} ${1}
%failure_text = ${color_failure}FAILURE:${color_reset} ${1}
%warning_text = ${color_warning}WARN:${color_reset} ${1}
%error = $(error $(call %error_text,${1}))
%debug = $(if $(call %is_truthy,${MAKEFLAGS_debug}),$(info $(call %debug_text,${1})),)
%info = $(info $(call %info_text,${1}))
%success = $(info $(call %success_text,${1}))
%failure = $(info $(call %failure_text,${1}))
%warn = $(warning $(call %warning_text,${1}))
%warning = $(warning $(call %warning_text,${1}))

%debug_var = $(call %debug,${1}="${${1}}")
%info_var = $(call %info,${1}="${${1}}")

#### * OS-specific tools and vars

EXEEXT_nix := $()
EXEEXT_win := .exe

ifeq (${OSID},win)
OSID_name  := windows
OS_PREFIX  := win.
EXEEXT     := ${EXEEXT_win}
#
AWK        := gawk ## from `scoop install gawk`; or "goawk" from `go get github.com/benhoyt/goawk`
CAT        := "${SystemRoot}\System32\findstr" /r .*
CP         := copy /y
ECHO       := echo
GREP       := grep ## from `scoop install grep`
MKDIR      := mkdir
RM         := del
RM_r       := $(RM) /s
RMDIR      := rmdir /s/q
FIND       := "${SystemRoot}\System32\find"
FINDSTR    := "${SystemRoot}\System32\findstr"
MORE       := "${SystemRoot}\System32\more"
SORT       := "${SystemRoot}\System32\sort"
TYPE       := type
WHICH      := where
#
ECHO_newline := echo.
else
OSID_name  ?= $(shell uname | tr '[:upper:]' '[:lower:]')
OS_PREFIX  := ${OSID_name}.
EXEEXT     := $(if $(call %is_truthy,${CC_is_MinGW_w64}),${EXEEXT_win},${EXEEXT_nix})
#
AWK        := awk
CAT        := cat
CP         := cp
ECHO       := echo
GREP       := grep
MKDIR      := mkdir -p
RM         := rm
RM_r       := ${RM} -r
RMDIR      := ${RM} -r
SORT       := sort
WHICH      := which
#
ECHO_newline := echo
endif

#### * `vcpkg` support (note: delayed expansion b/c of dependency on multiple later defined variables)

ifneq (${VCPKG_ROOT},)
VCPKG_PLATFORM_ID = $(if $(filter 32,${ARCH_ID}),x86,x64)-$(if $(filter win,${OSID}),$(if $(filter gcc,${CC_ID}),mingw,windows),linux)$(if $(filter win,${OSID}),$(if $(call %is_truthy,${STATIC}),-static,),$(if $(call %is_truthy,${STATIC}),,-dynamic))
VCPKG_INC_DIR = ${VCPKG_ROOT}/installed/${VCPKG_PLATFORM_ID}/include
VCPKG_LIB_DIR = ${VCPKG_ROOT}/installed/${VCPKG_PLATFORM_ID}$(if $(call %is_truthy,${DEBUG}),/debug,)/lib
# INC_DIRS += ${VCPKG_INC_DIR}
# LIB_DIRS += ${VCPKG_LIB_DIR}
%VCPKG_LIBS = $(foreach lib,${1},$(addprefix $(if $(filter win,${OSID}),$(if $(filter gcc,${CC_ID}),:,),:),$(notdir $(firstword $(wildcard ${VCPKG_LIB_DIR}/${lib}.lib ${VCPKG_LIB_DIR}/${lib}-*.lib ${VCPKG_LIB_DIR}/lib${lib}.a ${VCPKG_LIB_DIR}/lib${lib}d.a)))))
endif

####

make_ARGS := ${MAKECMDGOALS}
has_runner_target := $(strip $(call %map,$(eval %f=$$(findstring $${1},${MAKECMDGOALS}))%f,run test))
has_runner_first := $(strip $(call %map,$(eval %f=$$(findstring $${1},$$(firstword ${MAKECMDGOALS})))%f,run test))
runner_positions := $(call %map,$(eval %f=$$(call %position,$${1},${MAKECMDGOALS}))%f,${has_runner_target})
runner_position := $(firstword ${runner_positions})

make_runner_ARGS := $(if ${has_runner_target},$(call %tail,$(wordlist ${runner_position},$(call %length,${make_ARGS}),${make_ARGS})),)
override ARGS := $(or $(and ${ARGS},${ARGS}${SPACE})${make_runner_ARGS},${ARGS_default_${has_runner_target}})

$(call %debug_var,has_runner_first)
$(call %debug_var,has_runner_target)
$(call %debug_var,runner_position)
$(call %debug_var,MAKECMDGOALS)
$(call %debug_var,make_ARGS)
$(call %debug_var,make_runner_ARGS)
$(call %debug_var,ARGS_default_${has_runner_target})
$(call %debug_var,ARGS)

has_debug_target := $(strip $(call %map,$(eval %f=$$(findstring $${1},${MAKECMDGOALS}))%f,debug))
ifneq (${has_debug_target},)
override DEBUG := $(call %as_truthy,${true})
endif
$(call %debug_var,has_debug_target)
$(call %debug_var,DEBUG)

####

# include sibling configuration file, if exists (easier project config with a stable base Makefile)
-include ${makefile_path}.config

#### End of basic configuration section ####

# ref: [Understanding and Using Makefile Flags](https://earthly.dev/blog/make-flags) @@ <https://archive.is/vEpEU>

#### * Compiler configurations

# ref: [SO ~ WinOS - difference between subsystem:console and subsystem:windows](https://stackoverflow.com/questions/7316433/difference-between-console-subsystemconsole-and-windows-subsystemwindows)
# ref: [MSDN ~ Entry Point](https://learn.microsoft.com/en-us/cpp/build/reference/entry-entry-point-symbol) @@ <https://archive.isBRjh1>
# ref: [MSDN ~ Subsystem](https://learn.microsoft.com/en-us/cpp/build/reference/subsystem-specify-subsystem) @@ <https://archive.is/3QKS5>

%CPP_flags = ${CPPFLAGS} $(if $(filter-out windows,$(call %lc,$(firstword $(subst ${COMMA},${SPACE},$(if $(filter-out file,$(origin SUBSYSTEM)),${SUBSYSTEM},$(if ${1},${1},${SUBSYSTEM})))))),-D_CONSOLE$(if $(filter win,${OSID}), -D_WINOS_CUI,),$(if $(filter win,${OSID}),-D_WINOS_GUI -D_ENTRY_WinMain -D_ENTRY_WINMAIN,))

INCLUDE_DIRS = $(strip ${INC_DIRS} $(wildcard ${BASEPATH}/include))

SUBSYSTEM := console

OUT_obj_filesets := $()## a union of globsets matching all compiler intermediate build files (for *all* supported compilers; space-separated)

ifeq (,$(filter-out clang gcc,${CC_ID}))
## `clang` or `gcc`
CXX := ${CC:gcc=g}++
LD := ${CXX}
# DONE: [2022-09-27; rivy]; FixME: [2021-09-26; rivy] clang `llvm-rc` is broken (not preprocessing) => use `windres`, if available
# note: `llvm-rc` is broken for `clang` < v13, use `windres` instead, if present, for those versions
available_windres := $(subst -FOUND,,$(filter windres-FOUND,$(shell windres --version 2>&1 && echo windres-FOUND || echo)))
# RC_clang_clang13+_false := $(or $(and ${available_windres},windres),llvm-rc)
# RC_clang_clang13+_true := llvm-rc
RC_clang := $(and ${available_windres},windres)
RC_gcc := windres
RC := ${RC_${CC_ID}}## if empty/null, RC will be determined later, if possible, based on compiler and version
%link = ${LD} ${1} ${LD_o}${2} ${3} ${4} ${5}## $(call %link,LDFLAGS,EXE,OBJs,REZs,LDX_flags); function => requires delayed expansion
# %link = ${LD} ${LDFLAGS} ${LD_o}${1} ${2} ${3} -Wlinker,--start-group ${4} -Wlinker,--end-group## $(call %link,EXE,OBJs,REZs,LIBs); function => requires delayed expansion
# %link = ${LD} ${LDFLAGS} ${LD_o}${1} ${2} ${3} -Xlinker --start-group ${4} -Xlinker --end-group## $(call %link,EXE,OBJs,REZs,LIBs); function => requires delayed expansion
# NOTE: currently (2022-09-27) resource embedding via linking is only supported on Windows platforms
# NOTE: if ${RC} not defined, WARN and use ${CC} to build an empty compiled "resource" file
%rc = $(if $(and $(call %eq,${OSID},win),${RC}),${RC} ${RCFLAGS} ${RC_o}${1} ${2},$(info $(call %warning_text,Unable to find viable resource compiler; using `${CC}` to build an empty compiled resource file as fallback))${CC} ${CFLAGS_COMPILE_ONLY} ${CFLAGS_ARCH_${ARCH_ID}} -w -x c - <${devnull} ${CC_o}${1})## $(call %link,REZ,RES); function => requires delayed expansion
STRIP_CC_clang_OSID_nix := strip
STRIP_CC_clang_OSID_win := llvm-strip
STRIP_CC_gcc := strip
## -g :: produce debugging information
## -v :: verbose output (shows command lines used during run)
## -O<n> :: <n> == [0 .. 3], increasing level of optimization (see <https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html> @@ <https://archive.vn/7YtdI>)
## -pedantic-errors :: error on use of compiler language extensions
## -Werror :: warnings treated as errors
## -Wall :: enable all (usual) warnings
## -Wextra :: enable extra warnings
## -Wpedantic :: warn on use of compiler language extensions
## -Wno-comment :: suppress warnings about trailing comments on directive lines
## -Wno-deprecated-declarations :: suppress deprecation warnings
## -Wno-int-to-void-pointer-cast :: suppress cast to void from int warnings; ref: <https://stackoverflow.com/questions/22751762/how-to-make-compiler-not-show-int-to-void-pointer-cast-warnings>
## -MMD :: create make-compatible dependency information file (a depfile); ref: <https://clang.llvm.org/docs/ClangCommandLineReference.html> , <https://stackoverflow.com/questions/2394609/makefile-header-dependencies>
## -D_CRT_SECURE_NO_WARNINGS :: compiler directive == suppress "unsafe function" compiler warning
## note: CFLAGS == C flags; CPPFLAGS == C PreProcessor flags; CXXFLAGS := C++ flags; ref: <https://stackoverflow.com/questions/495598/difference-between-cppflags-and-cxxflags-in-gnu-make>
CFLAGS = $(call %cflags_incs,${INCLUDE_DIRS}) -Werror -Wall -Wextra -Wpedantic -MMD## requires delayed expansion (b/c uses `%shell_quote` which is defined later)
%cflags_incs = $(call %map,$(eval %f=-I$(call %shell_quote,$${1}))%f,$(strip ${1}))
CFLAGS_COMPILE_ONLY := -c
CFLAGS_ARCH_32 := -m32
CFLAGS_ARCH_64 := -m64
CFLAGS_DEBUG_false := -DNDEBUG -O3
CFLAGS_DEBUG_true := -DDEBUG -D_DEBUG -O0 -g -fno-inline
# CFLAGS_STATIC_false := -shared
# CFLAGS_STATIC_true := -static
CFLAGS_VERBOSE_true := -v
CFLAGS_check := -v
CFLAGS_machine := -dumpmachine
CFLAGS_v := --version
CPPFLAGS += $()
## see <https://stackoverflow.com/questions/42545078/clang-version-5-and-lnk4217-warning/42752769#42752769>@@<https://archive.is/bK4Di>
## see <http://clang-developers.42468.n3.nabble.com/MinGW-Clang-issues-with-static-libstdc-td4056214.html>
## see <https://clang.llvm.org/docs/LTOVisibility.html>
## -Xclang <arg> :: pass <arg> to clang compiler
## -flto-visibility-public-std :: use public LTO visibility for classes in std and stdext namespaces
CXXFLAGS += $()
CXXFLAGS_clang += -Xclang -flto-visibility-public-std
## note: (linux) MinGW gcc cross-compiler will automatically add an extension '.exe' to the output executable
##   ... `-Wl,-oEXECUTABLE_NAME` will suppress the automatic addition of the '.exe' extension ; * ref: <https://stackoverflow.com/a/66603802/43774>
## -Xlinker <arg> :: pass <arg> to linker
## --strip-all :: strip all symbols
LDFLAGS += $()
LDFLAGS_ARCH_32 := ${CFLAGS_ARCH_32}
LDFLAGS_ARCH_64 := ${CFLAGS_ARCH_64}
LDFLAGS_DEBUG_false := $(if $(filter nix,${OSID}),-Xlinker --strip-all,)
LDFLAGS_DEBUG_true := $(if $(filter win,${OSID}),$(if $(filter clang,${CC_ID}),-Xlinker /NODEFAULTLIB:libcmt -Xlinker /NODEFAULTLIB:libcmtd -lmsvcrtd,),)
# LDFLAGS_STATIC_false := -pie
# LDFLAGS_STATIC_false := -shared
# LDFLAGS_STATIC_true := -static -static-libgcc -static-libstdc++
LDFLAGS_STATIC_true := -static
LDFLAGS_clang += $(if $(filter nix,${OSID}),-lstdc++,)
LDFLAGS_gcc += -lstdc++
## * resource compiler
## for `clang`, use `llvm-rc -H` for option help
## for `gcc`, use `windres --help` for option help
RCFLAGS += $()
# RCFLAGS_clang_clang13+_true := -L 0x409$()## `llvm-rc`
# RCFLAGS_clang_clang13+_false := -l 0x409$()## `windres`
RCFLAGS_clang := -l 0x409$()## `windres`
RCFLAGS_gcc := -l 0x409$()
RCFLAGS_ARCH_32 := $()
RCFLAGS_ARCH_64 := $()
RCFLAGS_DEBUG_true := -DDEBUG -D_DEBUG
RCFLAGS_DEBUG_false := -DNDEBUG
RCFLAGS_TARGET_clang_ARCH_32 := --target=$(if $(call %eq,${CC},clang),i686-w64-mingw32,${CC})$()
RCFLAGS_TARGET_clang_ARCH_64 := --target=$(if $(call %eq,${CC},clang),x86_64-w64-mingw32,${CC})$()
RCFLAGS_TARGET_gcc_ARCH_32 := --target=$(if $(or $(call %eq,${CC},gcc),$(call %eq,${CC},i586-pc-msdosdjgpp-gcc)),i686-w64-mingw32,${CC})$()
RCFLAGS_TARGET_gcc_ARCH_64 := --target=$(if $(call %eq,${CC},gcc),x86_64-w64-mingw32,${CC})$()

CC_is_MinGW_w64 := $(call %as_truthy,$(findstring -w64-mingw32-,${CC}))

DEP_ext_${CC_ID} := d
REZ_ext_${CC_ID} := res.o

# RC_clang_clang13+_true_o = /Fo## '/Fo' for `llvm-rc`; '-o' for `windres`
# RC_clang_clang13+_false_o = -o## '/Fo' for `llvm-rc`; '-o' for `windres`
RC_clang_o := -o
RC_gcc_o := -o

# %ld_subsystem = /subsystem:$(if $(filter-out file,$(origin SUBSYSTEM)),${SUBSYSTEM},${1}$(if $(call %is_falsey,${is_CL1600+}),${COMMA}4.00,$(if $(filter ${ARCH_32},${ARCH_ID}),${COMMA}5.01,${COMMA}5.02)))
%ld_subsystem = $(if $(filter win,${OSID}),$(if $(filter-out file,$(origin SUBSYSTEM)),$(if $(filter gcc,${CC_ID}),-m${SUBSYSTEM},-Wl${COMMA}/subsystem:${SUBSYSTEM}),$(if $(call %eq,${SUBSYSTEM},${1}),,$(if ${1},$(if $(filter gcc,${CC_ID}),-m${1},-Wl${COMMA}/subsystem:${1}),))),)
%LDX_flags = $(strip ${LDXFLAGS} $(call %ld_subsystem,${1}) $(foreach dir,${LIB_DIRS},-L$(call %shell_quote,${dir})) $(foreach lib,${LIBS},-l$(call %shell_quote,${lib})))

# ifeq ($(CC),clang)
# LDFLAGS_dynamic := -Wl,-nodefaultlib:libcmt -lmsvcrt # only works for MSVC targets
# endif
# ifeq ($(CC),gcc)
# # CFLAGS_dynamic := -fpie
# # LDFLAGS_dynamic := -fpie
# endif

# FixMe/ToDO: add explanation and links for `dosbox-x` setup and `MSDOS-run.BAT` file
RUNNER_i586-pc-msdosdjgpp-gcc := MSDOS-run
endif ## `clang` or `gcc`
OUT_obj_filesets := ${OUT_obj_filesets} $() *.o *.d## `clang`/`gcc` intermediate files

ifeq (cl,${CC_ID})
## `cl` (MSVC)
CXX := ${CC}
LD := $(if $(filter clang-cl,${CC}),clang-cl,link)
RC := $(if $(filter clang-cl,${CC}),llvm-rc,rc)
%link = ${LD} ${1} ${LD_o}${2} ${3} ${4} ${5}## $(call %link,LDFLAGS,EXE,OBJs,REZs,LDX_flags); function => requires delayed expansion
%rc = $(strip ${RC} ${RCFLAGS} ${RC_o}${1} ${2}$(if $(call %is_falsey,${is_CL1600+}),>${devnull},))## $(call %link,REZ,RES); function => requires delayed expansion
STRIP := $()
## ref: <https://docs.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-by-category> @@ <https://archive.is/PTPDN>
## /nologo :: startup without logo display
## /W3 :: set warning level to 3 [1..4, all; increasing level of warning scrutiny]
## /WX :: treat warnings as errors
## /wd4996 :: suppress POSIX function name deprecation warning (#C4996)
## /EHsc :: enable C++ EH (no SEH exceptions) + extern "C" defaults to nothrow (replaces deprecated /GX)
## /D "_CRT_SECURE_NO_WARNING" :: compiler directive == suppress "unsafe function" compiler warning
## /Od :: disable optimization
## /Ox :: maximum optimizations
## /O2 :: maximize speed
## /D "WIN32" :: old/extraneous define
## /D "_CONSOLE" :: old/extraneous define
## /D "DEBUG" :: activate DEBUG changes
## /D "NDEBUG" :: deactivate assert()
## /D "_CRT_SECURE_NO_WARNING" :: compiler directive == suppress "unsafe function" compiler warning
## /MT :: static linking
## /MTd :: static debug linking
## /Fd:... :: program database file name
## /TC :: compile all SOURCE files as C
## /TP :: compile all SOURCE files as C++
## /Zi :: generate complete debug information (as a *.PDB file)
## /Z7 :: generate complete debug information within each object file (no *.PDB file)
## * `link`
## ref: <https://docs.microsoft.com/en-us/cpp/build/reference/linker-options> @@ <https://archive.is/wip/61bbL>
## ref: <https://learn.microsoft.com/en-us/cpp/build/reference/subsystem-specify-subsystem> @@ <https://archive.is/3QKS5>
## /incremental:no :: disable incremental linking (avoids size increase, useless for cold builds, with minimal time cost)
## /machine:I386 :: specify the target machine platform
## /subsystem:console :: generate "Win32 character-mode" console application
## ref: <https://devblogs.microsoft.com/cppblog/windows-xp-targeting-with-c-in-visual-studio-2012> @@ <https://archive.is/pWbPR>
## /subsystem:console,4.00 :: generate "Win32 character-mode" console application; 4.00 => minimum supported system is Win9x/NT; supported only by MSVC 9 (`cl` version "15xx" from 2008) or less
## /subsystem:console,5.01 :: generate "Win32 character-mode" console application; 5.01 => minimum supported system is XP; supported by MSVC 10 (`cl` version "16xx") or later when compiling for 32-bit
## /subsystem:console,5.02 :: generate "Win32 character-mode" console application; 5.02 => minimum supported system is XP; supported by MSVC 10 (`cl` version "16xx") or later when compiling for 64-bit
CFLAGS = /nologo /W3 /WX /EHsc $(call %cflags_incs,${INCLUDE_DIRS})## requires delayed expansion (b/c uses `%shell_quote` which is defined later)
%cflags_incs = $(call %map,$(eval %f=/I $(call %shell_quote,$${1}))%f,$(strip ${1}))
CFLAGS_COMPILE_ONLY := -c
CFLAGS_ARCH_32 := $(if $(filter clang-cl,${CC}),-m32,)
CFLAGS_ARCH_64 := $(if $(filter clang-cl,${CC}),-m64,)
# CFLAGS_DEBUG_true = /D "DEBUG" /D "_DEBUG" /Od /Zi /Fd"${OUT_DIR_obj}/"
CFLAGS_DEBUG_true := /D "DEBUG" /D "_DEBUG" /Od /Z7
CFLAGS_DEBUG_false := /D "NDEBUG" /Ox /O2
CFLAGS_DEBUG_true_STATIC_false := /MDd ## debug + dynamic
CFLAGS_DEBUG_false_STATIC_false := /MD ## release + dynamic
CFLAGS_DEBUG_true_STATIC_true := /MTd ## debug + static
CFLAGS_DEBUG_false_STATIC_true := /MT ## release + static
CFLAGS_VERBOSE_true := $()
CFLAGS_check := $(if $(filter clang-cl,${CC}),-v,)
CFLAGS_v := $(if $(filter clang-cl,${CC}),-v,)
CFLAGS_machine := $(if $(filter clang-cl,${CC}),-v,)
CPPFLAGS += $()
CXXFLAGS += $()##$if $(filter clang-cl,${CC}),-Xclang -flto-visibility-public-std,)
LDFLAGS += $()
LDFLAGS_ARCH_32 := ${CFLAGS_ARCH_32}
LDFLAGS_ARCH_64 := ${CFLAGS_ARCH_64}
# VC6-specific flags
## /ignore:4254 :: suppress "merging sections with different attributes" warning (LNK4254)
LDFLAGS_VC6_true := /ignore:4254
#
LDXFLAGS += $(if $(filter clang-cl,${CC}),/link ,)/nologo /incremental:no
LDXFLAGS_ARCH_32 := /machine:I386
# version specific flags
# $(call %info,origin SUBSYSTEM=$(origin SUBSYSTEM))
# LDXFLAGS_CL1600+_false := /subsystem:${SUBSYSTEM},4.00
# LDXFLAGS_CL1600+_true_ARCH_32 := /subsystem:${SUBSYSTEM},5.01
# LDXFLAGS_CL1600+_true_ARCH_64 := /subsystem:${SUBSYSTEM},5.02
# LDXFLAGS_CL1600+_false_SUBSYSTEM_console := /subsystem:console,4.00
# LDXFLAGS_CL1600+_false_SUBSYSTEM_windows := /subsystem:windows,4.00
# LDXFLAGS_CL1600+_true_ARCH_32 := /subsystem:${SUBSYSTEM},5.01
# LDXFLAGS_CL1600+_true_ARCH_64 := /subsystem:${SUBSYSTEM},5.02
# `clang-cl`
## * resource compiler
## /nologo :: startup without logo display
## /l 0x409 :: specify default language using language identifier; "0x409" == "en-US"
## * ref: [MS LCIDs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-lcid/63d3d639-7fd2-4afb-abbe-0d5b5551eef8) @@ <https://archive.is/ReX6o>
RCFLAGS += /l 0x409 $()
RCFLAGS_ARCH_32 = $()
RCFLAGS_ARCH_64 = $()
RCFLAGS_DEBUG_true := /D "DEBUG" /D "_DEBUG"
RCFLAGS_DEBUG_false := /D "NDEBUG"
RCFLAGS_VC6_false := $(if $(filter clang-cl,${CC}),,/nologo)

CC_${CC_ID}_e := /Fe
CC_${CC_ID}_o := /Fo
LD_${CC_ID}_o := $(if $(filter clang-cl,${CC}),/Fe,/out:)
RC_${CC_ID}_o := /Fo

O_${CC_ID} := obj

%ld_subsystem = /subsystem:$(if $(filter-out file,$(origin SUBSYSTEM)),${SUBSYSTEM},$(if ${1},${1},${SUBSYSTEM})$(if $(call %is_falsey,${is_CL1600+}),${COMMA}4.00,$(if $(filter ${ARCH_32},${ARCH_ID}),${COMMA}5.01,${COMMA}5.02)))
%LDX_flags = $(strip ${LDXFLAGS} $(call %ld_subsystem,${1}) $(foreach dir,${LIB_DIRS},/LIBPATH:$(call %shell_quote,${dir})) $(foreach lib,${LIBS},$(call %shell_quote,$(patsubst %.lib,%,${lib}).lib)))
endif ## `cl` (MSVC)
OUT_obj_filesets := ${OUT_obj_filesets} $() *.obj## `cl` intermediate files

ifeq (,$(filter-out bcc32 embcc32,${CC_ID}))
## `bcc32` (Borland C++ 5.5.1 free command line tools) or `embcc` (Embarcadero Borland C++ free command line tools)
CXX := ${CC}
LD := ilink32
RC := rc
RC_CC_bcc32 := brc32
RC_CC_embcc32 := rc
RC := ${RC_CC_${CC_ID}}
# note: `ILINK32 [@<respFile>] [<options>] <startup> <myObjs>, [<exe>], [<mapFile>], [<libraries>], [<defFile>], [<resFile>]`
%link = ${LD} -I$(call %shell_quote,$(call %as_win_path,${OUT_DIR_obj})) ${1} ${5} $(call %as_win_path,${3}), $(call %as_win_path,${2}),,$(call %as_win_path,${LIBS}),,$(call %as_win_path,${4})## $(call %link,LDFLAGS,EXE,OBJs,REZs,LDX_flags); function => requires delayed expansion
%rc = ${RC} ${RCFLAGS} ${RC_o}${1} ${2} >${devnull}## $(call %link,REZ,RES); function => requires delayed expansion
STRIP := $()

# * find CC base directory (for include and library directories plus initialization code, as needed); note: CMD/PowerShell is assumed as `bcc32` is DOS/Windows-only
CC_BASEDIR := $(subst /,\,$(abspath $(firstword $(shell scoop which ${CC} 2>NUL) $(shell which ${CC} 2>NUL) $(shell where ${CC} 2>NUL))\..\..))
INCLUDE_DIRS += ${CC_BASEDIR}\include
LD_INIT_OBJ = $(call %shell_quote,${CC_BASEDIR}\lib\c0$(if $(filter windows,${SUBSYSTEM}),w,x)32.obj)## requires delayed expansion (b/c uses `%shell_quote` which is defined later)
LIB_DIRS = $(if $(filter bcc32,${CC_ID}),$(call %shell_quote,${CC_BASEDIR}\lib),$(call %shell_quote,${CC_BASEDIR}\lib\win32c\release);$(call %shell_quote,${CC_BASEDIR}\lib\win32c\release\psdk))## requires delayed expansion (b/c uses `%shell_quote` which is defined later)

# ref: BCCTool help file
# ref: <http://docs.embarcadero.com/products/rad_studio/delphiAndcpp2009/HelpUpdate2/EN/html/devwin32/bcc32_xml.html> @@ <https://archive.is/q23nS>
# -q :: "quiet" * suppress compiler identification banner
# -O2 :: generate fastest possible code (optimize for speed)
# -Od :: disable all optimization
# -TWC :: specify assembler option(s) ("WC")
# -P-c :: compile SOURCE.cpp as C++, all other extensions as C, and sets the default extension to .c
# -d :: merge duplicate strings
# -f- :: no floating point (avoids linking floating point libraries when not using floating point; linker errors will occur if floating point operations are used)
# -ff- :: use strict ANSI floating point rules (disables "fast floating point" optimizations)
# -v- :: turn off source level debugging and inline expansion on
# -vi :: turn on inline function expansion
# -w! :: warnings as errors
CFLAGS = -q -P-c -d -f- $(if $(filter bcc32,${CC_ID}),-ff-,) -w! $(call %cflags_incs,${INCLUDE_DIRS})## requires delayed expansion (b/c uses `%shell_quote` which is defined later)
%cflags_incs = $(call %map,$(eval %f=-I$(call %shell_quote,$${1}))%f,$(strip ${1}))
CFLAGS_COMPILE_ONLY := -c
CFLAGS_DEBUG_false := -D"NDEBUG" -O2 -v- -vi
CFLAGS_DEBUG_true := -D"DEBUG" -D"_DEBUG" -Od
CFLAGS_check := $(if $(filter embcc32,${CC_ID}),--version,)
CFLAGS_v := $(if $(filter embcc32,${CC_ID}),--version,)
CPPFLAGS += $()
# -P :: compile all SOURCE files as C++ (regardless of extension)
CXXFLAGS += -P
# ref: <http://docs.embarcadero.com/products/rad_studio/delphiAndcpp2009/HelpUpdate2/EN/html/devwin32/ilink32_xml.html> @@ <https://archive.is/Xe4VK>
# -q :: suppress command line banner
# -ap :: builds 32-bit console application
# -c :: treats case as significant in public and external symbols
# -L... :: specifies library search path
# -GF:AGGRESSIVE :: aggressively trims the working set of an application when the application is idle
# -Gn :: disable incremental linking (suppresses creation of linker state files)
# -Tpe :: targets 32-bit windows EXE
# -V4.0 :: specifies minimum expected Windows version (4.0 == Windows 9x/NT+)
# -v- :: disable debugging information
# -x :: suppress creation of a MAP file
LDFLAGS += -q -Tpe$(if $(filter windows,${SUBSYSTEM}),, -ap) -c -V4.0 -GF:AGGRESSIVE -L${LIB_DIRS} ${LD_INIT_OBJ}## requires delayed expansion (b/c indirectly uses %shell_quote for ${LIB_DIRS} and ${LS_INIT_OBJ})
LDFLAGS_DEBUG_false := -Gn -v- -x
## * resource compiler; see `rc -?` for options help
## /nologo :: startup without logo display
## /l 0x409 :: specify default language using language identifier; "0x409" == "en-US"
## * ref: [MS LCIDs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-lcid/63d3d639-7fd2-4afb-abbe-0d5b5551eef8) @@ <https://archive.is/ReX6o>
RCFLAGS += /l 0x409 $(if $(filter bcc32,${CC_ID}),-r,) -I$(call %shell_quote,${BASEPATH}) -I$(call %shell_quote,${CC_BASEDIR}\include)$() $(if $(filter embcc32,${CC_ID}),-I$(call %shell_quote,${CC_BASEDIR}\include\windows\crtl) -I$(call %shell_quote,${CC_BASEDIR}\include\windows\sdk),)
RCFLAGS_ARCH_32 := $()
RCFLAGS_ARCH_64 := $()
RCFLAGS_DEBUG_true := /D "DEBUG" /D "_DEBUG"
RCFLAGS_DEBUG_false := /D "NDEBUG"

CC_${CC_ID}_e := -e
CC_${CC_ID}_o := -o
LD_${CC_ID}_o := $()
RC_${CC_ID}_o := /fo

O_${CC_ID} := obj

LIBS := import32.lib cw32.lib
endif ## `bcc32` or `embcc32`
OUT_obj_filesets := ${OUT_obj_filesets} $() *.obj *.ilc *.ild *.ilf *.ils *.tds## `bcc32`/`embcc32` intermediate files

## find/calculate best available `strip`
STRIP_check_flags := --version
# * calculate `strip`; general overrides for ${CC_ID} and ${OSID}
STRIP := $(or ${STRIP_CC_${CC_ID}_OSID_${OSID}},${STRIP_CC_${CC_ID}},${STRIP})
# $(call %debug_var,STRIP)
# * available as ${CC}-prefixed variant?
STRIP_CC_${CC}_name := $(call %neq,${CC:-${CC_ID}=-strip},${CC})
$(call %debug_var,STRIP_CC_${CC}_name)
STRIP_CC_${CC} := $(or ${STRIP_CC_${CC}},$(and ${STRIP_CC_${CC}_name},$(shell "${STRIP_CC_${CC}_name}" ${STRIP_check_flags} >${devnull} 2>&1 && echo ${STRIP_CC_${CC}_name})))
$(call %debug_var,STRIP_CC_${CC})
# * calculate `strip`; specific overrides for ${CC}
STRIP := $(or ${STRIP_CC_${CC}},${STRIP})
# $(call %debug_var,STRIP)
# * and... ${STRIP} available? (missing in some distributions)
STRIP := $(shell "${STRIP}" ${STRIP_check_flags} >${devnull} 2>&1 && echo ${STRIP})
# $(call %debug_var,STRIP)

####

$(call %debug_var,OSID)
$(call %debug_var,SHELL)

$(call %debug_var,COLOR)
$(call %debug_var,DEBUG)
$(call %debug_var,STATIC)
$(call %debug_var,VERBOSE)

$(call %debug_var,MAKEFLAGS_debug)

$(call %debug_var,CC_ID)
$(call %debug_var,CC)
$(call %debug_var,CXX)
$(call %debug_var,LD)
$(call %debug_var,RC)
$(call %debug_var,STRIP)
$(call %debug_var,CFLAGS)
$(call %debug_var,CPPFLAGS)
$(call %debug_var,CXXFLAGS)
$(call %debug_var,LDFLAGS)

$(call %debug_var,CC_is_MinGW_w64)

$(call %debug_var,INCLUDE_DIRS)

$(call %debug_var,OUT_obj_filesets)

CC_e := $(or ${CC_${CC_ID}_e},-o${SPACE})
CC_o := $(or ${CC_${CC_ID}_o},-o${SPACE})
LD_o := $(or ${LD_${CC_ID}_o},-o${SPACE})
RC_o := ${RC_${CC_ID}_o}

$(call %debug_var,CC_e)
$(call %debug_var,CC_o)
$(call %debug_var,LD_o)
$(call %debug_var,RC_o)

D := $(or ${DEP_ext_${CC_ID}},$())

$(call %debug_var,D)

O := $(or ${O_${CC_ID}},o)

$(call %debug_var,O)

REZ := $(or ${REZ_ext_${CC_ID}},res)

$(call %debug_var,REZ)

#### End of compiler configuration section. ####

# NOTE: early configuration; must be done before ${CC_ID} (`clang`) is used as a linker (eg, during configuration)
ifeq (${OSID},win)
# ifneq ($(call %eq,${CC_ID},clang),)
ifneq ($(or $(call %eq,${CC_ID},clang),$(call %eq,${CC},clang-cl)),)
# ifneq ($(or $(filter-out clang,${CC_ID}),$(filter-out clang-cl,${CC})),)
# prior LIB definition may interfere with clang builds when using MSVC
undefine LIB # 'override' not used to allow definition on command line
endif
endif
$(call %debug_var,LIB)

####

# detect ${CC}
ifeq (,$(shell "${CC}" ${CFLAGS_check} >${devnull} 2>&1 <${devnull} && echo ${CC} present))
$(call %error,Missing required compiler (`${CC}`))
endif

ifeq (${SPACE},$(findstring ${SPACE},${makefile_abs_path}))
$(call %error,<SPACE>'s within project directory path are not allowed)## `make` has very limited ability to quote <SPACE> characters
endif

# # Since we rely on paths relative to the makefile location, abort if make isn't being run from there.
# ifneq (${makefile_dir},${current_dir})
# $(call %error,Invalid current directory; this makefile must be invoked from the directory it resides in)
# endif

####

$(call %debug_var,MAKE_VERSION)
$(call %debug_var,MAKE_VERSION_major)
$(call %debug_var,MAKE_VERSION_minor)

$(call %debug_var,MAKE_VERSION_fail)

$(call %debug_var,makefile_path)
$(call %debug_var,makefile_abs_path)
$(call %debug_var,makefile_dir)
$(call %debug_var,current_dir)
$(call %debug_var,make_invoke_alias)
$(call %debug_var,makefile_set)
$(call %debug_var,makefile_set_abs)

$(call %debug_var,BASEPATH)

# discover NAME
NAME := $(strip ${NAME})
ifeq (${NAME},)
# * generate a default NAME from Makefile project path
working_NAME := $(notdir ${makefile_dir})
## remove any generic repo and/or category tag prefix
tags_repo := repo.GH repo.GL repo.github repo.gitlab repo
tags_category := cxx deno djs js-cli js-user js rs rust ts sh
tags_combined := $(call %cross,$(eval %f=$${1}${DOT}$${2})%f,${tags_repo},${tags_category}) ${tags_repo} ${tags_category}
tag_patterns := $(call %map,$(eval %f=$${1}${DOT}% $${1})%f,${tags_combined})
# $(call %debug_var,tags_combined)
# $(call %debug_var,tag_patterns)
clipped_NAMEs := $(strip $(filter-out ${working_NAME},$(call %replace,${tag_patterns},%,$(filter-out ${tags_repo},${working_NAME}))))
# $(call %debug_var,clipped_NAMEs)
working_NAME := $(firstword $(filter-out ${tags_repo},${clipped_NAMEs} ${working_NAME}))
ifeq (${working_NAME},)
working_NAME := $(notdir $(abspath $(dir ${makefile_dir})))
endif
override NAME := ${working_NAME}
endif
$(call %debug_var,working_NAME)
$(call %debug_var,NAME)

####

ARCH_allowed := $(sort ${ARCH_32} ${ARCH_64})
ifneq (${ARCH},$(filter ${ARCH},${ARCH_allowed}))
$(call %error,Unknown architecture "$(ARCH)"; valid values are [""$(subst $(SPACE),$(),$(addprefix ${COMMA}",$(addsuffix ",${ARCH_allowed})))])
endif

SUBSYSTEM_allowed := $(sort console windows posix)
ifneq (${SUBSYSTEM},$(filter ${SUBSYSTEM},${SUBSYSTEM_allowed}))
$(call %error,Unknown subsystem "$(SUBSYSTEM)"; valid values are [""$(subst $(SPACE),$(),$(addprefix ${COMMA}",$(addsuffix ",${SUBSYSTEM_allowed})))])
endif

line_marker := $(if $(filter-out ${CC},clang-cl),1:,2:)
$(call %debug_var,line_marker)
ifeq (${OSID},win)
CC_machine_raw := $(shell ${CC} ${CFLAGS_machine} 2>&1 | ${FINDSTR} /n /r .* | ${FINDSTR} /b /r "${line_marker}")
else ## nix
CC_machine_raw := $(shell ${CC} ${CFLAGS_machine} 2>&1 | ${GREP} -n ".*" | ${GREP} "^${line_marker}" )
endif
CC_machine_raw := $(subst ${ESC}${line_marker},$(),${ESC}${CC_machine_raw})
CC_ARCH := $(or $(filter $(subst -, ,${CC_machine_raw}),${ARCH_x86} ${ARCH_x86_64}),${ARCH_default})
CC_machine := $(or $(and $(filter cl bcc32 embcc32,${CC_ID}),${CC_ARCH}),${CC_machine_raw})
CC_ARCH_ID := $(if $(filter ${CC_ARCH},${ARCH_32}),32,64)
override ARCH := $(or ${ARCH},${CC_ARCH})
ARCH_ID := $(if $(filter ${ARCH},${ARCH_32}),32,64)

$(call %debug_var,CC_machine_raw)
$(call %debug_var,CC_machine)
$(call %debug_var,CC_ARCH)
$(call %debug_var,CC_ARCH_ID)

$(call %debug_var,ARCH)
$(call %debug_var,ARCH_ID)

####

# "version heuristic" => parse first line of ${CC} version output, remove all non-version-compatible characters, take first word that starts with number and contains a ${DOT}
# maint; [2020-05-14;rivy] heuristic is dependant on version output of various compilers; works for all known versions as of

ifeq (${OSID},win)
CC_version_raw := $(shell ${CC} ${CFLAGS_v} 2>&1 | ${FINDSTR} /n /r .* | ${FINDSTR} /b /r "1:")
else ## nix
CC_version_raw := $(shell ${CC} ${CFLAGS_v} 2>&1 | ${GREP} -n ".*" | ${GREP} "^1:" )
endif
$(call %debug_var,CC_version_raw)

s := ${CC_version_raw}

# remove "1:" leader
s := $(subst ${ESC}1:,$(),${ESC}${s})
# $(call %debug_var,s)
# remove all non-version-compatible characters (leaving common version characters [${BACKSLASH} ${SLASH} ${DOT} _ - +])
s := $(call %tr,$(filter-out ${SLASH} ${BACKSLASH} ${DOT} _ - +,${[punct]}),$(),${s})
# $(call %debug_var,s)
# filter_map ${DOT}-containing words
%f = $(and $(findstring ${DOT},${1}),${1})
s := $(strip $(call %map,%f,${s}))
# $(call %debug_var,s)
# filter_map all words with leading digits
%f = $(and $(findstring ${ESC}_,${ESC}$(call %tr,${[digit]} ${ESC},$(call %repeat,_,$(words ${[digit]})),${1})),${1})
s := $(strip $(call %map,%f,${s}))
# $(call %debug_var,s)

# take first word as full version
CC_version := $(firstword ${s})
CC_version_parts := $(strip $(subst ${DOT},${SPACE},${CC_version}))
CC_version_M := $(strip $(word 1,${CC_version_parts}))
CC_version_m := $(strip $(word 2,${CC_version_parts}))
CC_version_r := $(strip $(word 3,${CC_version_parts}))
CC_version_Mm := $(strip ${CC_version_M}.${CC_version_m})

is_clang13+ := $(call %as_truthy,$(and $(call %eq,clang,${CC_ID}),$(call %not,$(filter ${CC_version_M},0 1 2 3 4 5 6 7 8 9 10 11 12)),${true}))
is_CL1600+ := $(call %as_truthy,$(or $(call %eq,clang-cl,${CC}),$(and $(call %eq,cl,${CC}),$(call %not,$(filter ${CC_version_M},0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)),${true})))
is_VC6 := $(call %as_truthy,$(and $(call %eq,cl,${CC}),$(call %eq,12,${CC_version_M}),${true}))

$(call %debug_var,CC_version)
$(call %debug_var,CC_version_parts)
$(call %debug_var,CC_version_M)
$(call %debug_var,CC_version_m)
$(call %debug_var,CC_version_r)
$(call %debug_var,CC_version_Mm)
$(call %debug_var,is_clang13+)
$(call %debug_var,is_CL1600+)
$(call %debug_var,is_VC6)

####

OUT_DIR_EXT := $(if $(call %is_truthy,${STATIC}),,.dynamic)

ifeq (,${TARGET})
OUT_DIR_EXT :=-x${ARCH_ID}
RCFLAGS_TARGET := ${RCFLAGS_TARGET_${CC_ID}_ARCH_${ARCH_ID}}
else
CFLAGS_TARGET := --target=${TARGET}
LDFLAGS_TARGET := --target=${TARGET}
RCFLAGS_TARGET := --target=${TARGET}
OUT_DIR_EXT := ${OUT_DIR_EXT}.${TARGET}
endif

$(call %debug_var,CFLAGS_TARGET)
$(call %debug_var,CXXFLAGS_TARGET)
$(call %debug_var,LDFLAGS_TARGET)
$(call %debug_var,RCFLAGS_TARGET)

$(call %debug_var,ARCH_ID)
$(call %debug_var,TARGET)

$(call %debug_var,OUT_DIR_EXT)

####

# NOTE: [2022-09-29; rivy] `llvm-rc` for `clang`, as of v15, is still broken, unable to compile more than the most simplistic resource file; so, avoid these useless RC fixups
# # * RC/RC_o fixups (based on CC version)
#
# $(call %debug_var,RC)
# $(call %debug_var,RC_${CC_ID}_clang13+_${is_clang13+})
# $(call %debug_var,RC_${CC_ID})
# $(call %debug_var,RC_o)
# $(call %debug_var,RC_${CC_ID}_clang13+_${is_clang13+}_o)
# $(call %debug_var,RC_${CC_ID}_o)
#
# RC := $(or ${RC},${RC_${CC_ID}_clang13+_${is_clang13+}},${RC_${CC_ID}},$(if $(filter win,${OSID}),windres,llvm-rc))
# RC_o := $(or ${RC_o},${RC_${CC_ID}_clang13+_${is_clang13+}_o},${RC_${CC_ID}_o},-o)
# RC := $(or ${RC},${RC_${CC_ID}},$(if $(filter win,${OSID}),windres,llvm-rc))
#
# $(call %debug_var,RC)
# $(call %debug_var,RC_o)

####

CC_DEFINES_CLI := -D_CC=\"${CC}\" -D_CC_ID=\"${CC_ID}\" -D_CC_VERSION=\"${CC_version}\" -D_CC_MACHINE=\"${CC_machine}\" -D_CC_TARGET=\"${TARGET}\" -D_CC_TARGET_ARCH=\"${ARCH}\" -D_CC_TARGET_ARCH_ID=\"${ARCH_ID}\"$()

CFLAGS += ${CFLAGS_ARCH_${ARCH_ID}}
CFLAGS += ${CFLAGS_TARGET}
CFLAGS += ${CFLAGS_DEBUG_${DEBUG}}
CFLAGS += ${CFLAGS_STATIC_${STATIC}}
CFLAGS += ${CFLAGS_DEBUG_${DEBUG}_STATIC_${STATIC}}
CFLAGS += ${CFLAGS_VERBOSE_${VERBOSE}}
CFLAGS += ${CFLAGS_${CC_ID}}
CFLAGS += ${CFLAGS_${CC_ID}_${OSID}}

CPPFLAGS += $(strip $(if $(call %is_truthy,${CC_DEFINES}),${CC_DEFINES_CLI},$()))
CPPFLAGS += ${CPPFLAGS_${CC_ID}}
CPPFLAGS += ${CPPFLAGS_${CC_ID}_${OSID}}

CXXFLAGS += ${CXXFLAGS_${CC_ID}}
CXXFLAGS += ${CXXFLAGS_${CC_ID}_${OSID}}

LDFLAGS += ${LDFLAGS_ARCH_${ARCH_ID}}
LDFLAGS += ${LDFLAGS_TARGET}
LDFLAGS += ${LDFLAGS_DEBUG_${DEBUG}}
LDFLAGS += ${LDFLAGS_STATIC_${STATIC}}
LDFLAGS += ${LDFLAGS_VC6_${is_VC6}}## name-expanded variable is only defined for ${CC_ID}=='cl'
LDFLAGS += ${LDFLAGS_${CC_ID}}
LDFLAGS += ${LDFLAGS_${CC_ID}_${OSID}}

LDXFLAGS += ${LDXFLAGS_CL1600+_${is_CL1600+}}## name-expanded variable is only defined for ${CC_ID}=='cl'
LDXFLAGS += ${LDXFLAGS_CL1600+_${is_CL1600+}_ARCH_${ARCH_ID}}## name-expanded variable is only defined for ${CC_ID}=='cl'
LDXFLAGS += ${LDXFLAGS_${CC_ID}}
LDXFLAGS += ${LDXFLAGS_${CC_ID}_${OSID}}

# RCFLAGS += $(strip $(subst -D_CC,-DCC,$(if $(call %is_truthy,${CC_DEFINES}),${CC_DEFINES_CLI},$())))
# RCFLAGS += $(strip $(if $(call %is_truthy,${CC_DEFINES}),${CC_DEFINES_CLI},$()))
# * MSVC/cl windres is unable to correctly handle backslash-quoted defines; removing them works for the other compilers as well
RCFLAGS += $(strip $(subst ${BACKSLASH}",",$(if $(call %is_truthy,${CC_DEFINES}),${CC_DEFINES_CLI},$())))
RCFLAGS += ${RCFLAGS_ARCH_${ARCH_ID}}
RCFLAGS += ${RCFLAGS_TARGET}
RCFLAGS += ${RCFLAGS_DEBUG_${DEBUG}}
RCFLAGS += ${RCFLAGS_VC6_${is_VC6}}## name-expanded variable is only defined for ${CC_ID}=='cl'
# RCFLAGS += ${RCFLAGS_${CC_ID}_clang13+_${is_clang13+}}## name-expanded variable is only defined for ${CC_ID}=='clang'
RCFLAGS += ${RCFLAGS_${CC_ID}}
RCFLAGS += ${RCFLAGS_${CC_ID}_${OSID}}

CFLAGS := $(strip ${CFLAGS})
CPPFLAGS := $(strip ${CPPFLAGS})
CXXFLAGS := $(strip ${CXXFLAGS})
LDFLAGS := $(strip ${LDFLAGS})
LDXFLAGS := $(strip ${LDXFLAGS})
RCFLAGS := $(strip ${RCFLAGS})

$(call %debug_var,CFLAGS)
$(call %debug_var,CPPFLAGS)
$(call %debug_var,CXXFLAGS)
$(call %debug_var,LDFLAGS)
$(call %debug_var,LDXFLAGS)
$(call %debug_var,RCFLAGS)

####

RUNNER := ${RUNNER_${CC}}

####

# note: work within ${BASEPATH} (build directories may not yet be created)
# note: set LIB as `make` doesn't export the LIB change into `$(shell ...)` invocations
test_file_stem := $(subst ${SPACE},_,${BASEPATH}/__MAKE__${CC}_${ARCH}_${TARGET}_test__)
test_file_cc_string := ${CC_e}$(call %shell_quote,${test_file_stem}${EXEEXT})
test_success_text := ..TEST-COMPILE-SUCCESSFUL..
$(call %debug_var,test_file_stem)
$(call %debug_var,test_file_cc_string)
ifeq (${OSID},win)
# erase the LIB environment variable for non-`cl` compilers (specifically `clang` has issues)
test_lib_setting_win := $(if $(call %neq,cl,${CC}),set "LIB=${LIB}",set "LIB=%LIB%")
$(call %debug_var,test_lib_setting_win)
$(call %debug,${RM} $(call %shell_quote,${test_file_stem}${EXEEXT}) $(call %shell_quote,${test_file_stem}).*)
# test_output := $(shell ${test_lib_setting_win} && ${ECHO} ${HASH}include ^<stdio.h^> > ${test_file_stem}.c && ${ECHO} int main(void){printf("${test_file_stem}");return 0;} >> ${test_file_stem}.c && ${CC} $(filter-out ${CFLAGS_VERBOSE_true},${CFLAGS}) ${test_file_stem}.c ${test_file_cc_string} 2>&1 && ${ECHO} ${test_success_text})
test_output := $(shell ${test_lib_setting_win} && ${ECHO} ${HASH}include ^<stdio.h^> > $(call %shell_quote,${test_file_stem}.c) && ${ECHO} int main(void){printf("${test_file_stem}");return 0;} >> $(call %shell_quote,${test_file_stem}.c) && ${CC} $(filter-out ${CFLAGS_VERBOSE_true},${CFLAGS}) $(call %shell_quote,${test_file_stem}.c) ${test_file_cc_string} 2>&1 && ${ECHO} ${test_success_text}& ${RM} $(call %shell_quote,$(call %as_win_path,${test_file_stem}${EXEEXT})) $(call %shell_quote,$(call %as_win_path,${test_file_stem}).*))
else
test_output := $(shell LIB='${LIB}' && ${ECHO} '${HASH}include <stdio.h>' > $(call %shell_quote,${test_file_stem}.c) && ${ECHO} 'int main(void){printf("${test_file_stem}");return 0;}' >> $(call %shell_quote,${test_file_stem}.c) && ${CC} $(filter-out ${CFLAGS_VERBOSE_true},${CFLAGS}) $(call %shell_quote,${test_file_stem}.c) ${test_file_cc_string} 2>&1 && ${ECHO} ${test_success_text}; ${RM} -f $(call %shell_quote,${test_file_stem}${EXEEXT}) $(call %shell_quote,${test_file_stem}).*)
endif
test_compile_success := $(call %is_truthy,$(findstring ${test_success_text},${test_output}))
test_compile_fail := $(call %not,${test_compile_success})
32bitOnly_CCs := bcc32 embcc32
32bitOnly_CCs_on_non32 := $(call %is_truthy,$(and $(filter ${32bitOnly_CCs},${CC_ID}),$(filter-out 32,${ARCH_ID})))
ARCH_available := $(call %is_truthy,$(and ${test_compile_success},$(call %not,${32bitOnly_CCs_on_non32})))

$(call %debug_var,.SHELLSTATUS)
$(call %debug_var,test_output)
$(call %debug_var,test_compile_fail)
$(call %debug_var,test_compile_success)
$(call %debug_var,32bitOnly_CCs)
$(call %debug_var,32bitOnly_CCs_on_non32)
$(call %debug_var,ARCH_available)

$(call %debug_var,ARCH_ID)
$(call %debug_var,CC_ARCH_ID)

ifeq (${false},$(and ${ARCH_available},$(or $(call %eq,${ARCH_ID},${CC_ARCH_ID}),$(call %neq,cl,${CC}))))
error_text := Unable to build $(if ${TARGET},architecture/target "${ARCH}/${TARGET}",architecture "${ARCH}") for this version of `${CC}` (v${CC_version}/${CC_machine})$(if ${test_compile_fail},; test compilation failed with "${test_output}",)
error_text := $(if $(and $(or $(filter clang,${CC_ID}),$(filter clang-cl,${CC})),$(filter cl,$(shell cl 2>&1 >${devnull} && echo cl || echo))),${error_text}; ${color_warning}NOTE:${color_reset} early versions of `cl` may interfere with `${CC}` builds/compiles,${error_text})
$(call %error,${error_text})
endif

####

BUILD_DIR := ${BASEPATH}/$(or ${BUILD_PATH},${HASH}build)## note: `${HASH}build` causes issues with OpenWatcom-v2.0 [2020-09-01], but `${DOLLAR}build` causes variable expansion issues for VSCode debugging; note: 'target' is a common alternative

SRC_DIR := $(firstword $(wildcard $(foreach segment,${SRC_PATH} src source,${BASEPATH}/${segment})))
SRC_DIR := ${SRC_DIR:/=}
SRC_DIR := ${SRC_DIR:./.=.}

CONFIG := $(if $(call %is_truthy,${DEBUG}),debug,release)

SOURCE_exts = *.c *.cc *.cpp *.cxx
HEADER_exts = *.h *.hh *.hpp *.hxx

SRC_files := $(wildcard $(foreach elem,${SOURCE_exts},${SRC_DIR}/${elem}))

$(call %debug_var,SRC_DIR)
$(call %debug_var,SRC_files)

OUT_DIR := ${BUILD_DIR}/${OS_PREFIX}${CONFIG}$(if $(call %is_truthy,${STATIC}),,.dynamic).(${CC}@${CC_version_Mm})${OUT_DIR_EXT}
OUT_DIR_bin := ${OUT_DIR}/bin
OUT_DIR_obj := ${OUT_DIR}/obj
OUT_DIR_targets := ${OUT_DIR}/targets

$(call %debug_var,OUT_DIR)
$(call %debug_var,OUT_DIR_bin)
$(call %debug_var,OUT_DIR_obj)
$(call %debug_var,OUT_DIR_targets)

# binaries (within first of ['${SRC_DIR}/bin','${SRC_DIR}/bins'] directories)
## * each source file will be compiled to a single target executable within the 'bin' output directory

BIN_DIR := $(firstword $(wildcard $(foreach segment,bin bins,${SRC_DIR}/${segment})))
BIN_DIR_filename := $(notdir ${BIN_DIR})
BIN_OUT_DIR_bin := $(and ${BIN_DIR},${OUT_DIR_bin})
BIN_OUT_DIR_obj := $(and ${BIN_DIR},${OUT_DIR_obj}.${BIN_DIR_filename})
BIN_SRC_files := $(and ${BIN_DIR},$(wildcard $(foreach elem,${SOURCE_exts},${BIN_DIR}/${elem})))
BIN_SRC_sup_files := $(and ${BIN_DIR},$(call %recursive_wildcard,$(patsubst %/,%,$(call %dirs,${BIN_DIR})),${SOURCE_exts}))
BIN_deps := $(and ${BIN_DIR},$(call %recursive_wildcard,${BIN_DIR},${HEADER_exts}))
BIN_OBJ_files := $(foreach file,$(strip ${BIN_SRC_files}),$(basename $(patsubst ${BIN_DIR}/%,${BIN_OUT_DIR_obj}/%,${file})).${O})
BIN_OBJ_sup_files := $(foreach file,${BIN_SRC_sup_files},$(basename $(patsubst ${BIN_DIR}/%,${BIN_OUT_DIR_obj}/%,${file})).${O})
BIN_RES_files := $(call %recursive_wildcard,${BIN_DIR},*.rc)## resource files
BIN_REZ_files := $(BIN_RES_files:${BIN_DIR}/%.rc=${BIN_OUT_DIR_obj}/%.${REZ})## compiled resource files
BIN_cflags_includes := $(call %cflags_incs,$(strip $(call %uniq,$(or ${INCLUDE_DIRS_bin},${BIN_DIR}))))
%BIN_bin_of_src = $(foreach file,${1},$(basename ${BIN_OUT_DIR_bin}/$(patsubst ${BIN_DIR}/%,%,${file}))${EXEEXT})
BIN_bin_files := $(call %BIN_bin_of_src,${BIN_SRC_files})

$(call %debug_var,BIN_DIR)
$(call %debug_var,BIN_DIR_filename)
$(call %debug_var,BIN_SRC_files)
$(call %debug_var,BIN_SRC_sup_files)
$(call %debug_var,BIN_OBJ_files)
$(call %debug_var,BIN_OBJ_sup_files)
$(call %debug_var,BIN_OUT_DIR_bin)
$(call %debug_var,BIN_OUT_DIR_obj)
$(call %debug_var,BIN_bin_files)
$(call %debug_var,BIN_RES_files)
$(call %debug_var,BIN_REZ_files)
$(call %debug_var,BIN_cflags_includes)

SRC_sup_files := $(filter-out ${BIN_SRC_files} ${BIN_SRC_sup_files},$(call %recursive_wildcard,$(patsubst %/,%,$(call %dirs_in,${SRC_DIR})),${SOURCE_exts}))## supplemental source files (eg, common or library code)

$(call %debug_var,SRC_sup_files)

RES_files := $(filter-out ${BIN_RES_files},$(call %recursive_wildcard,${SRC_DIR},*.rc))## resource files
REZ_files := $(RES_files:${SRC_DIR}/%.rc=${OUT_DIR_obj}/%.${REZ})## compiled resource files

$(call %debug_var,RES_files)
$(call %debug_var,REZ_files)

# OBJ_files := ${SRC_files} ${SRC_sup_files}
# OBJ_files := $(OBJ_files:${SRC_DIR}/%.c=${OUT_DIR_obj}/%.${O})
# OBJ_files := $(OBJ_files:${SRC_DIR}/%.cpp=${OUT_DIR_obj}/%.${O})
# OBJ_files := $(OBJ_files:${SRC_DIR}/%.cxx=${OUT_DIR_obj}/%.${O})
OBJ_files := $(foreach file,$(strip ${SRC_files}),$(basename $(patsubst ${SRC_DIR}/%,${OUT_DIR_obj}/%,${file})).${O})
OBJ_sup_files := $(foreach file,${SRC_sup_files},$(basename $(patsubst ${SRC_DIR}/%,${OUT_DIR_obj}/%,${file})).${O})

$(call %debug_var,OBJ_files)
$(call %debug_var,OBJ_sup_files)

DEP_files := $(wildcard $(OBJ_files:%.${O}=%.${D}))
# DEPS := $(%strip_leading_dotslash,${DEPS})
OBJ_deps := $(strip $(or ${DEPS},$(if ${DEP_files},$(),$(filter ${BIN_deps},$(call %recursive_wildcard,${SRC_DIR},${HEADER_exts})))))## common/shared dependencies (fallback to SRC_DIR header files)

$(call %debug_var,DEP_files)
$(call %debug_var,DEPS)
$(call %debug_var,OBJ_deps)

DEPS_common := $(strip ${makefile_set_abs} ${DEPS})
DEPS_target := $(strip ${REZ_files})
$(call %debug_var,DEPS)
$(call %debug_var,DEPS_common)
$(call %debug_var,DEPS_target)

# examples (within first of ['eg','egs','ex', 'exs', 'example', 'examples'] directories)
## * each source file will be compiled to a single target executable within the (same-named) examples output directory

EG_DIR := $(firstword $(wildcard $(foreach segment,eg egs ex exs example examples,${BASEPATH}/${segment})))
EG_DIR_filename := $(notdir ${EG_DIR})
EG_OUT_DIR_bin := $(and ${EG_DIR},${OUT_DIR}/${EG_DIR:${BASEPATH}/%=%})
EG_OUT_DIR_obj := $(and ${EG_DIR},${OUT_DIR_obj}.${EG_DIR_filename})
EG_SRC_files := $(and ${EG_DIR},$(wildcard $(foreach elem,${SOURCE_exts},${EG_DIR}/${elem})))
EG_SRC_sup_files := $(and ${EG_DIR},$(call %recursive_wildcard,$(patsubst %/,%,$(call %dirs,${EG_DIR})),${SOURCE_exts}))
EG_deps := $(and ${EG_DIR},$(call %recursive_wildcard,${EG_DIR},${HEADER_exts}))
EG_OBJ_files := $(foreach file,$(strip ${EG_SRC_files}),$(basename $(patsubst ${EG_DIR}/%,${EG_OUT_DIR_obj}/%,${file})).${O})
EG_OBJ_sup_files := $(foreach file,${EG_SRC_sup_files},$(basename $(patsubst ${EG_DIR}/%,${EG_OUT_DIR_obj}/%,${file})).${O})
EG_RES_files := $(call %recursive_wildcard,${EG_DIR},*.rc)## resource files
EG_REZ_files := $(EG_RES_files:${EG_DIR}/%.rc=${EG_OUT_DIR_obj}/%.${REZ})## compiled resource files
EG_cflags_includes := $(call %cflags_incs,$(strip $(call %uniq,$(or ${INCLUDE_DIRS_eg},${EG_DIR}))))
%EG_bin_of_src = $(foreach file,${1},$(basename ${EG_OUT_DIR_bin}/$(patsubst ${EG_DIR}/%,%,${file}))${EXEEXT})
EG_bin_files := $(call %EG_bin_of_src,${EG_SRC_files})

$(call %debug_var,EG_DIR)
$(call %debug_var,EG_DIR_filename)
$(call %debug_var,EG_SRC_files)
$(call %debug_var,EG_SRC_sup_files)
$(call %debug_var,EG_OBJ_files)
$(call %debug_var,EG_OBJ_sup_files)
$(call %debug_var,EG_OUT_DIR_bin)
$(call %debug_var,EG_OUT_DIR_obj)
$(call %debug_var,EG_bin_files)
$(call %debug_var,EG_RES_files)
$(call %debug_var,EG_REZ_files)
$(call %debug_var,EG_cflags_includes)

# tests (within first of ['t','test','tests'] directories)
## * each source file will be compiled to a single target executable within the (same-named) test output directory

TEST_DIR := $(firstword $(wildcard $(foreach segment,t test tests,${BASEPATH}/${segment})))
TEST_DIR_filename := $(notdir ${TEST_DIR})
TEST_OUT_DIR_bin := $(and ${TEST_DIR},${OUT_DIR}/${TEST_DIR:${BASEPATH}/%=%})
TEST_OUT_DIR_obj := $(and ${TEST_DIR},${OUT_DIR_obj}.$(notdir ${TEST_DIR}))
TEST_SRC_files := $(and ${TEST_DIR},$(wildcard $(foreach elem,${SOURCE_exts},${TEST_DIR}/${elem})))
TEST_SRC_sup_files := $(and ${TEST_DIR},$(call %recursive_wildcard,$(patsubst %/,%,$(call %dirs_in,${TEST_DIR})),${SOURCE_exts}))
TEST_deps := $(and ${TEST_DIR},$(call %recursive_wildcard,${TEST_DIR},${HEADER_exts}))
TEST_OBJ_files := $(foreach file,$(strip ${TEST_SRC_files}),$(basename $(patsubst ${TEST_DIR}/%,${TEST_OUT_DIR_obj}/%,${file})).${O})
TEST_OBJ_sup_files := $(foreach file,${TEST_SRC_sup_files},$(basename $(patsubst ${TEST_DIR}/%,${TEST_OUT_DIR_obj}/%,${file})).${O})
TEST_RES_files := $(call %recursive_wildcard,${TEST_DIR},*.rc)## resource files
TEST_REZ_files := $(TEST_RES_files:${TEST_DIR}/%.rc=${TEST_OUT_DIR_obj}/%.${REZ})## compiled resource files
TEST_cflags_includes := $(call %cflags_incs,$(strip $(call %uniq,$(or ${INCLUDE_DIRS_test},${TEST_DIR}))))
%TEST_bin_of_src = $(foreach file,${1},$(basename ${TEST_OUT_DIR_bin}/$(patsubst ${TEST_DIR}/%,%,${file}))${EXEEXT})
TEST_bin_files := $(call %TEST_bin_of_src,${TEST_SRC_files})

$(call %debug_var,TEST_DIR)
$(call %debug_var,TEST_DIR_filename)
$(call %debug_var,TEST_SRC_files)
$(call %debug_var,TEST_SRC_sup_files)
$(call %debug_var,TEST_OBJ_files)
$(call %debug_var,TEST_OBJ_sup_files)
$(call %debug_var,TEST_OUT_DIR_bin)
$(call %debug_var,TEST_OUT_DIR_obj)
$(call %debug_var,TEST_bin_files)
$(call %debug_var,TEST_RES_files)
$(call %debug_var,TEST_REZ_files)
$(call %debug_var,TEST_cflags_includes)

# $(call %debug,${OBJ_files} ${OBJ_sup_files} ${BIN_OBJ_files} ${BIN_OBJ_sup_files} ${EG_OBJ_files} ${EG_OBJ_sup_files} ${TEST_OBJ_files} ${TEST_OBJ_sup_files} ${BIN_REZ_files} ${EG_REZ_files} ${TEST_REZ_files} ${REZ_files})
# $(call %debug,$(dir ${OBJ_files} ${OBJ_sup_files} ${BIN_OBJ_files} ${BIN_OBJ_sup_files} ${EG_OBJ_files} ${EG_OBJ_sup_files} ${TEST_OBJ_files} ${TEST_OBJ_sup_files} ${BIN_REZ_files} ${EG_REZ_files} ${TEST_REZ_files} ${REZ_files}))

####

DEFAULT_TARGET := ${OUT_DIR_bin}/${NAME}${EXEEXT}
PROJECT_TARGET := ${OUT_DIR_bin}/${NAME}${EXEEXT}

.DEFAULT_GOAL := $(if ${SRC_files},${PROJECT_TARGET},$(if ${BIN_SRC_files},bins,all))# *default* target

$(call %debug_var,PROJECT_TARGET)
$(call %debug_var,.DEFAULT_GOAL)

####

DEBUG_DIR := ${BUILD_DIR}/debug-x${ARCH_ID}
$(call %debug_var,DEBUG_DIR)
$(call %debug_var,DEBUG_FROM)
%drive = $(if $(filter ${OSID},win),$(call %uc,$(firstword $(subst :,:${SPACE},$(abspath ${1})))),)
%abs_path = $(if $(filter ${OSID},win),$(call %as_nix_path,$(lastword $(subst :,:${SPACE},$(abspath ${1})))),$(abspath ${1}))
%norm = $(strip $(call %drive,${1})$(call %abs_path,${1}))
override DEBUG_FROM := $(call %norm,${DEBUG_FROM})
$(call %debug_var,DEBUG_FROM)
BASEPATH_norm := $(call %norm,${BASEPATH})
$(call %debug_var,BASEPATH_norm)
override DEBUG_FROM := $(subst ${BASEPATH_norm}/,,${DEBUG_FROM})
$(call %debug_var,DEBUG_FROM)
override DEBUG_FROM := $(and ${DEBUG_FROM},$(if $(patsubst /%,,${DEBUG_FROM}),${BASEPATH}/${DEBUG_FROM},${DEBUG_FROM}))
$(call %debug_var,DEBUG_FROM)
DEBUG_OUT_TYPE := $(if ${DEBUG_FROM},$(if $(filter ${DEBUG_FROM},${BIN_SRC_files}),BIN,$(if $(filter ${DEBUG_FROM},${EG_SRC_files}),EG,$(if $(filter ${DEBUG_FROM},${TEST_SRC_files}),TEST,))))
DEBUG_OUT_FILE := $(if ${DEBUG_OUT_TYPE},$(call %${DEBUG_OUT_TYPE}_bin_of_src,${DEBUG_FROM}),$(if ${SRC_files},${PROJECT_TARGET},))
$(call %debug_var,DEBUG_OUT_TYPE)
$(call %debug_var,DEBUG_OUT_FILE)
DEBUG_TARGET := ${DEBUG_DIR}/executable${EXEEXT_win}
$(call %debug_var,DEBUG_TARGET)

ifneq (${has_debug_target},)
ifeq (${DEBUG_OUT_FILE},)
$(call %error,unable to determine a TARGET for 'debug' (try `DEBUG_FROM=...`))
endif
endif

####

out_dirs += $(strip $(call %uniq,$(if ${has_debug_target},${DEBUG_DIR},) ${OUT_DIR} $(if $(filter-out all bins,${.DEFAULT_GOAL}),${OUT_DIR_bin},) $(if ${BIN_SRC_files},${BIN_OUT_DIR_bin},) $(if ${EG_SRC_files},${EG_OUT_DIR_bin},) $(if ${TEST_SRC_files},${TEST_OUT_DIR_bin},) $(if $(filter-out all bins,${.DEFAULT_GOAL}),${OUT_DIR_obj},) $(patsubst %/,%,$(dir ${OBJ_files} ${OBJ_sup_files} $(if ${BIN_SRC_files},${BIN_OBJ_files} ${BIN_OBJ_sup_files} ${BIN_REZ_files} ,) $(if ${EG_SRC_files},${EG_OBJ_files} ${EG_OBJ_sup_files} ${EG_REZ_files},) $(if ${TEST_SRC_files},${TEST_OBJ_files} ${TEST_OBJ_sup_files} ${TEST_REZ_files},) ${REZ_files})) ${OUT_DIR_targets}))

out_dirs_for_rules = $(strip $(call %tr,${DOLLAR} ${HASH},${DOLLAR}${DOLLAR} ${BACKSLASH}${HASH},${out_dirs}))

$(call %debug_var,out_dirs)
$(call %debug_var,out_dirs_for_rules)

####

# include automated dependencies (if/when the depfiles exist)
# ref: [Makefile automated header deps](https://stackoverflow.com/questions/2394609/makefile-header-dependencies) @@ <https://archive.is/uUux4>
-include ${DEP_files}

####

all_phony_targets += $()

####

# include sibling target(s) file (if/when sibling file exists; provides easy project customization upon a stable base Makefile)
# * note: `-include ${makefile_path}.target` is placed as late as possible, just prior to any goal/target declarations
-include ${makefile_path}.target

####

ifneq (${NULL},$(filter-out all bins,${.DEFAULT_GOAL}))## define 'run' target only for real executable targets (ignore 'all' or 'bins')
.PHONY: run
all_phony_targets += run
run: ${.DEFAULT_GOAL} ## Build/execute project executable (for ARGS, use `-- [ARGS]` or `ARGS="..."`)
	@$(strip ${RUNNER} $(call %shell_quote,$^)) ${ARGS}
endif

####
ifeq (${false},${has_run_first})## define standard phony targets only when 'run' is not the first target (all text following 'run' is assumed to be arguments for the run; minimizes recipe duplication/overwrite warnings)
####

ifeq (${OSID},win)
shell_filter_targets := ${FINDSTR} "."
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(filter all bins,${.DEFAULT_GOAL}), | ${FINDSTR} -v "^run:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(if ${SRC_files}${BIN_SRC_files}${EG_SRC_files}${TEST_SRC_files},, | ${FINDSTR} -v "^all:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(if ${SRC_files}${BIN_SRC_files}${EG_SRC_files}${TEST_SRC_files},, | ${FINDSTR} -v "^debug:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${SRC_files}), | ${FINDSTR} -v "^build:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${SRC_files}), | ${FINDSTR} -v "^compile:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${SRC_files}), | ${FINDSTR} -v "^rebuild:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${BIN_SRC_files}), | ${FINDSTR} -v "^bins:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${EG_SRC_files}), | ${FINDSTR} -v "^examples:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${TEST_SRC_files}), | ${FINDSTR} -v "^test:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${TEST_SRC_files}), | ${FINDSTR} -v "^tests:"))
else
shell_filter_targets := ${GREP} -P "."
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(filter all bins,${.DEFAULT_GOAL}), | ${GREP} -Pv "^run:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(if ${SRC_files}${BIN_SRC_files}${EG_SRC_files}${TEST_SRC_files},, | ${GREP} -Pv "^all:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(if ${SRC_files}${BIN_SRC_files}${EG_SRC_files}${TEST_SRC_files},, | ${GREP} -Pv "^debug:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${SRC_files}), | ${GREP} -Pv "^build:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${SRC_files}), | ${GREP} -Pv "^compile:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${SRC_files}), | ${GREP} -Pv "^rebuild:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${BIN_SRC_files}), | ${GREP} -Pv "^bins:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${EG_SRC_files}), | ${GREP} -Pv "^examples:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${TEST_SRC_files}), | ${GREP} -Pv "^test:"))
shell_filter_targets := $(strip ${shell_filter_targets} $(and $(call %not,${TEST_SRC_files}), | ${GREP} -Pv "^tests:"))
endif

.PHONY: help
all_phony_targets += help
help: ## Display help
	@${ECHO} $(call %shell_escape,`${color_command}${make_invoke_alias}${color_reset}`)
	@${ECHO} $(call %shell_escape,Usage: `${color_command}${make_invoke_alias} [MAKE_TARGET...] [ARCH=32|64|..] [CC=cl|clang|gcc|..] [CC_DEFINES=<truthy>] [DEBUG=<truthy>] [STATIC=<truthy>] [SUBSYSTEM=console|windows|..] [TARGET=..] [COLOR=<truthy>] [MAKEFLAGS_debug=<truthy>] [VERBOSE=<truthy>]${color_reset}`)
	@${ECHO} $(call %shell_escape,Builds $(if $(filter all bins,${.DEFAULT_GOAL}),'${color_target}${.DEFAULT_GOAL}${color_reset}' targets,"${color_target}$(call %strip_leading_dotslash,${.DEFAULT_GOAL})${color_reset}") within "${color_path}$(call %strip_leading_dotslash,${current_dir})${color_reset}")
ifeq (,${SRC_files}${BIN_SRC_files}${EG_SRC_files}${TEST_SRC_files})
	@${ECHO} $(call %shell_escape,$(call %info_text,Add files to project to enable more MAKEFILE_TARGETs.))
endif
	@${ECHO_newline}
ifneq (,${BIN_SRC_files})
	@${ECHO} $(call %shell_escape,* '${color_target}bins${color_reset}' will be built/stored to "${color_path}$(call %strip_leading_dotslash,${BIN_OUT_DIR_bin})${color_reset}")
endif
ifneq (,${EG_SRC_files})
	@${ECHO} $(call %shell_escape,* '${color_target}examples${color_reset}' will be built/stored to "${color_path}$(call %strip_leading_dotslash,${EG_OUT_DIR_bin})${color_reset}")
endif
ifneq (,${TEST_SRC_files})
	@${ECHO} $(call %shell_escape,* '${color_target}tests${color_reset}' will be built/stored to "${color_path}$(call %strip_leading_dotslash,${TEST_OUT_DIR_bin})${color_reset}")
endif
ifneq (,${EG_SRC_files}${TEST_SRC_files})
	@${ECHO_newline}
endif
	@${ECHO} $(call %shell_escape,MAKE_TARGETs:)
	@${ECHO_newline}
ifeq (${OSID},win)
	@${TYPE} $(call %map,%shell_quote,${makefile_set}) 2>${devnull} | ${FINDSTR} "^[a-zA-Z-]*:.*${HASH}${HASH}" | ${shell_filter_targets} | ${SORT} | for /f "tokens=1-2,* delims=:${HASH}" %%g in ('${MORE}') do @(@call set "t=%%g                " & @call echo ${color_success}%%t:~0,15%%${color_reset} ${color_info}%%i${color_reset})
else
	@${CAT} $(call %map,%shell_quote,${makefile_set}) | ${GREP} -P "(?i)^[[:alpha:]-]+:" | ${shell_filter_targets} | ${SORT} | ${AWK} 'match($$0,"^([[:alpha:]]+):.*?${HASH}${HASH}\\s*(.*)$$",m){ printf "${color_success}%-10s${color_reset}\t${color_info}%s${color_reset}\n", m[1], m[2] }END{printf "\n"}'
endif

####

.PHONY: clean
all_phony_targets += clean
clean: ## Remove build artifacts (for the active configuration, including intermediate artifacts)
# * note: filter-out to avoid removing main directory
	@$(call %rm_dirs_verbose_cli,$(call %map,%shell_quote,$(filter-out ${DOT},${out_dirs})))

.PHONY: realclean
all_phony_targets += realclean
realclean: ## Remove *all* build artifacts (includes all configurations and the build directory)
# * note: 'clean' is not needed as a dependency b/c `${BUILD_DIR}` contains *all* build and intermediate artifacts
	@$(call %rm_dirs_verbose_cli,$(call %shell_quote,$(filter-out ${DOT},${BUILD_DIR})))

####

.PHONY: all build compile rebuild
all_phony_targets += all build compile rebuild
all: $(if $(filter all,${.DEFAULT_GOAL}),,build) $(if ${BIN_SRC_files},bins,$()) $(if ${EG_SRC_files},examples,$()) $(if ${TEST_SRC_files},tests,$()) ## Build all project targets
build: ${.DEFAULT_GOAL} ## Build project
compile: ${OBJ_files} ${OBJ_sup_files} $(if $(filter all bins,${.DEFAULT_GOAL}),${BIN_OBJ_files} ${BIN_sup_files},) $(if $(filter all,${.DEFAULT_GOAL}),${EG_OBJ_files} ${EG_sup_files},)## Build intermediate targets
rebuild: clean build ## Clean and re-build project

####

ifneq (${NULL},${BIN_SRC_files})## define 'bins' target only when bin source files are found
.PHONY: bins
all_phony_targets += bins
bins: ${BIN_bin_files} ## Build extra project binaries
endif
ifneq (${NULL},${EG_SRC_files})## define 'examples' target only when examples source files are found
.PHONY: examples
all_phony_targets += examples
examples: ${EG_bin_files} ## Build project examples
endif
ifneq (${NULL},${TEST_SRC_files})## define 'test' and 'tests' targets only when test source files are found
.PHONY: test tests
all_phony_targets += test tests
test: tests $(addsuffix *[makefile.run]*,${TEST_bin_files}) ## Build/execute project tests
tests: ${TEST_bin_files} ## Build project tests
endif

####

.PHONY: debug ${DEBUG_TARGET}
all_phony_targets += debug ${DEBUG_TARGET}
debug: ${DEBUG_TARGET} ## Build a specific executable for debugging (use `DEBUG_FROM=...` to specify a specific source file)

####
endif ## not ${has_run_first}
####

# ref: [`make` default rules]<https://www.gnu.org/software/make/manual/html_node/Catalogue-of-Rules.html> @@ <https://archive.is/KDNbA>
# ref: [make ~ `eval()`](http://make.mad-scientist.net/the-eval-function) @ <https://archive.is/rpUfG>
# * note: for pattern-based rules/targets, `%` has some special matching mechanics; ref: <https://stackoverflow.com/a/21193953> , <https://www.gnu.org/software/make/manual/html_node/Pattern-Match.html#Pattern-Match> @@ <https://archive.is/GjJ3P>

####

%*[makefile.run]*: %
	@${ECHO} $(call %shell_escape,$(call %info_text,running '$<'))
	@$(strip ${RUNNER_${CC}} $(call %shell_quote,$<)) ${ARGS}

####

${NAME}: ${PROJECT_TARGET}
${PROJECT_TARGET}: ${OBJ_files} ${OBJ_sup_files} ${DEPS_common} ${DEPS_target} | ${OUT_DIR_bin}
	@$(if $(call %is_truthy,${VERBOSE}),${ECHO} $(call %shell_escape,$(call %info_text,'$@' is $(if $(call %is_gui,$@),GUI,console)-type.)),$(call !shell_noop))
	$(call %link,${LDFLAGS},$(call %shell_quote,$@),$(call %map,%shell_quote,${OBJ_files} ${OBJ_sup_files} ${LINKS}),$(call %map,%shell_quote,${REZ_files}),$(call %LDX_flags,$(if $(call %is_gui,$@),windows,)))
	$(if $(and ${STRIP},$(call %is_falsey,${DEBUG})),${STRIP} $(call %shell_quote,$@),)
	@${ECHO} $(call %shell_escape,$(call %success_text,made '$@'.))

####

${OUT_DIR_obj}/%.${O}: ${SRC_DIR}/%.c ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} $(call %shell_quote,$<)

${OUT_DIR_obj}/%.${O}: ${SRC_DIR}/%.cc ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${CXXFLAGS} $(call %shell_quote,$<)

${OUT_DIR_obj}/%.${O}: ${SRC_DIR}/%.cpp ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${CXXFLAGS} $(call %shell_quote,$<)

${OUT_DIR_obj}/%.${O}: ${SRC_DIR}/%.cxx ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${CXXFLAGS} $(call %shell_quote,$<)
# or ${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} $(call %shell_quote,$<)

${OUT_DIR_obj}/%.${REZ}: ${SRC_DIR}/%.rc ${DEPS_common} | ${out_dirs}
	$(call %rc,$(call %shell_quote,$@),$(call %shell_quote,$<))

####

${BIN_OUT_DIR_bin}/%${EXEEXT}: ${BIN_OUT_DIR_obj}/%.${O} ${BIN_OBJ_sup_files} ${BIN_REZ_files} ${OBJ_sup_files} ${DEPS_common} | ${BIN_OUT_DIR_bin}
	@$(if $(call %is_truthy,${VERBOSE}),${ECHO} $(call %shell_escape,$(call %info_text,'$@' is $(if $(call %is_gui,$@),GUI,console)-type.)),$(call !shell_noop))
	$(call %link,${LDFLAGS},$(call %shell_quote,$@),$(call %map,%shell_quote,$< ${BIN_OBJ_sup_files} ${OBJ_sup_files}),$(call %map,%shell_quote,$(call %filter_by_stem,$@,${BIN_REZ_files})),$(call %LDX_flags,$(if $(call %is_gui,$@),windows,${SUBSYSTEM})))
	$(if $(and ${STRIP},$(call %is_falsey,${DEBUG})),${STRIP} $(call %shell_quote,$@),)
	@${ECHO} $(call %shell_escape,$(call %success_text,made '$@'.))

${BIN_OUT_DIR_obj}/%.${O}: ${BIN_DIR}/%.c ${BIN_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${BIN_cflags_includes} $(call %shell_quote,$<)

${BIN_OUT_DIR_obj}/%.${O}: ${BIN_DIR}/%.cc ${BIN_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${BIN_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)

${BIN_OUT_DIR_obj}/%.${O}: ${BIN_DIR}/%.cpp ${BIN_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${BIN_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)

${BIN_OUT_DIR_obj}/%.${O}: ${BIN_DIR}/%.cxx ${BIN_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${BIN_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)
# or ${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} $(call %shell_quote,$<)

${BIN_OUT_DIR_obj}/%.${REZ}: ${BIN_DIR}/%.rc ${DEPS_common} | ${out_dirs}
	$(call %rc,$(call %shell_quote,$@),$(call %shell_quote,$<))

####

${EG_OUT_DIR_bin}/%${EXEEXT}: ${EG_OUT_DIR_obj}/%.${O} ${EG_OBJ_sup_files} ${EG_REZ_files} ${OBJ_sup_files} ${DEPS_common} | ${EG_OUT_DIR_bin}
	@$(if $(call %is_truthy,${VERBOSE}),${ECHO} $(call %shell_escape,$(call %info_text,'$@' is $(if $(call %is_gui,$@),GUI,console)-type.)),$(call !shell_noop))
	$(call %link,${LDFLAGS},$(call %shell_quote,$@),$(call %map,%shell_quote,$< ${EG_OBJ_sup_files} ${OBJ_sup_files}),$(call %map,%shell_quote,$(call %filter_by_stem,$@,${EG_REZ_files})),$(call %LDX_flags,$(if $(call %is_gui,$@),windows,${SUBSYSTEM})))
	$(if $(and ${STRIP},$(call %is_falsey,${DEBUG})),${STRIP} $(call %shell_quote,$@),)
	@${ECHO} $(call %shell_escape,$(call %success_text,made '$@'.))

${EG_OUT_DIR_obj}/%.${O}: ${EG_DIR}/%.c ${EG_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${EG_cflags_includes} $(call %shell_quote,$<)

${EG_OUT_DIR_obj}/%.${O}: ${EG_DIR}/%.cc ${EG_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${EG_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)

${EG_OUT_DIR_obj}/%.${O}: ${EG_DIR}/%.cpp ${EG_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${EG_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)

${EG_OUT_DIR_obj}/%.${O}: ${EG_DIR}/%.cxx ${EG_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${EG_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)
# or ${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} ${CPPFLAGS} ${CFLAGS} $(call %shell_quote,$<)

${EG_OUT_DIR_obj}/%.${REZ}: ${EG_DIR}/%.rc ${DEPS_common} | ${out_dirs}
	$(call %rc,$(call %shell_quote,$@),$(call %shell_quote,$<))

####

${TEST_OUT_DIR_bin}/%${EXEEXT}: ${TEST_OUT_DIR_obj}/%.${O} ${TEST_OBJ_sup_files} ${TEST_REZ_files} ${OBJ_sup_files} ${DEPS_common} | ${TEST_OUT_DIR_bin}
	@$(if $(call %is_truthy,${VERBOSE}),${ECHO} $(call %shell_escape,$(call %info_text,'$@' is $(if $(call %is_gui,$@),GUI,console)-type.)),$(call !shell_noop))
	$(call %link,${LDFLAGS},$(call %shell_quote,$@),$(call %map,%shell_quote,$< ${TEST_OBJ_sup_files} ${OBJ_sup_files}),$(call %map,%shell_quote,$(call %filter_by_stem,$@,${TEST_REZ_files})),$(call %LDX_flags,$(if $(call %is_gui,$@),windows,${SUBSYSTEM})))
	$(if $(and ${STRIP},$(call %is_falsey,${DEBUG})),${STRIP} $(call %shell_quote,$@),)
	@${ECHO} $(call %shell_escape,$(call %success_text,made '$@'.))

${TEST_OUT_DIR_obj}/%.${O}: ${TEST_DIR}/%.c ${TEST_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${TEST_cflags_includes} $(call %shell_quote,$<)

${TEST_OUT_DIR_obj}/%.${O}: ${TEST_DIR}/%.cc ${TEST_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${TEST_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)

${TEST_OUT_DIR_obj}/%.${O}: ${TEST_DIR}/%.cpp ${TEST_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${TEST_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)

${TEST_OUT_DIR_obj}/%.${O}: ${TEST_DIR}/%.cxx ${TEST_deps} ${OBJ_deps} ${DEPS_common} | ${out_dirs}
	${CXX} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} $(call %CPP_flags,$(if $(call %is_gui,$@),windows,)) ${CFLAGS} ${TEST_cflags_includes} ${CXXFLAGS} $(call %shell_quote,$<)
# or ${CC} ${CC_o}$(call %shell_quote,$@) ${CFLAGS_COMPILE_ONLY} ${CPPFLAGS} ${CFLAGS} $(call %shell_quote,$<)

${TEST_OUT_DIR_obj}/%.${REZ}: ${TEST_DIR}/%.rc ${DEPS_common} | ${out_dirs}
	$(call %rc,$(call %shell_quote,$@),$(call %shell_quote,$<))

####

${DEBUG_TARGET}: ${DEBUG_OUT_FILE}
	@${CP} $(call %shell_quote,$(call %as_os_path,$<)) $(call %shell_quote,$(call %as_os_path,${DEBUG_TARGET})) >${devnull}
	@${ECHO} $(call %shell_escape,$(call %success_text,(re-)created '$(call %strip_leading_dotslash,${DEBUG_TARGET})'.))

####

$(foreach dir,$(filter-out . ..,${out_dirs_for_rules}),$(eval $(call @mkdir_rule,${dir})))

####

# suppress auto-deletion of intermediate files
# ref: [`gmake` ~ removing intermediate files](https://stackoverflow.com/questions/47447369/gnu-make-removing-intermediate-files) @@ <https://archive.is/UXrIv>
.SECONDARY:

####

ifeq (${NULL},$(or ${SRC_files},${BIN_SRC_files},${EG_SRC_files}))
$(call %warning,no source files found; is `SRC_DIR` ('${SRC_DIR}') set correctly for the project?)
endif

$(call %debug_var,NULL)
$(call %debug_var,has_runner_target)
$(call %debug_var,all_phony_targets)
$(call %debug_var,make_runner_ARGS)

ifeq (${true},$(call %as_truthy,${has_runner_target}))
ifneq (${NULL},$(if ${has_runner_target},$(filter ${all_phony_targets},${make_runner_ARGS}),${NULL}))
$(call %warning,runner arguments duplicate (and overwrite) standard targets; try using `${make_invoke_alias} run ARGS=...`)
endif
# $(info make_runner_ARGS=:${make_runner_ARGS}:)
$(eval ${make_runner_ARGS}:;@:)
endif
