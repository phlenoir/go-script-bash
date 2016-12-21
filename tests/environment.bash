#! /bin/bash
#
# Common setup for all tests

. "$_GO_ROOTDIR/lib/bats/assertions"
. "$_GO_ROOTDIR/lib/bats/helpers"

set_bats_test_suite_name "${BASH_SOURCE[0]%/*}"

# Avoid having to fold our test strings. Tests that verify folding behavior will
# override this.
COLUMNS=1000

# Many tests assume the output is generated by running the script directly, so
# we clear the _GO_CMD variable in case the test suite was invoked using a shell
# function.
unset -v _GO_CMD

# Clear all user-definable `readonly` variables (and potentially user-definable
# `export` variables) module variables to avoid interference with test
# conditions.
unset -v _GO_MAX_FILE_DESCRIPTORS "${!_GO_LOG@}" "${!__GO_LOG@}"

# TEST_GO_ROOTDIR contains a space to help ensure that variables are quoted
# properly in most places.
readonly TEST_GO_ROOTDIR="$BATS_TEST_ROOTDIR"
readonly TEST_GO_SCRIPT="$TEST_GO_ROOTDIR/go"
readonly TEST_GO_SCRIPTS_RELATIVE_DIR="scripts"
readonly TEST_GO_SCRIPTS_DIR="$TEST_GO_ROOTDIR/$TEST_GO_SCRIPTS_RELATIVE_DIR"
readonly TEST_GO_PLUGINS_DIR="$TEST_GO_SCRIPTS_DIR/plugins"

create_test_go_script() {
  create_bats_test_script 'go' \
    ". '$_GO_ROOTDIR/go-core.bash' '$TEST_GO_SCRIPTS_RELATIVE_DIR'" \
    "$@"

  # Most tests should assume this directory is present. Those that don't should
  # remove it explicitly.
  if [[ ! -d "$TEST_GO_SCRIPTS_DIR" ]]; then
    mkdir "$TEST_GO_SCRIPTS_DIR"
  fi
}

create_test_command_script() {
  create_bats_test_script "$TEST_GO_SCRIPTS_RELATIVE_DIR/$1" "${@:2}"
}

create_core_module_stub() {
  local module_path="$_GO_ROOTDIR/lib/$1"
  shift

  if [[ ! -f "$module_path" ]]; then
    echo "No such core module: $module_path" >&2
    return 1
  fi

  cp "$module_path"{,.stubbed}
  echo '#! /bin/bash' > "$module_path"
  local IFS=$'\n'
  echo "$*" >> "$module_path"
  chmod 600 "$module_path"
}

restore_stubbed_core_modules() {
  local module

  for module in "$_GO_ROOTDIR/lib"/*.stubbed; do
    mv "$module" "${module%.stubbed}"
  done
}

create_parent_and_subcommands() {
  local parent="$1"
  shift
  local subcommand

  create_test_command_script "$parent"

  for subcommand in "$@"; do
    create_test_command_script "$parent.d/$subcommand"
  done
}

remove_test_go_rootdir() {
  remove_bats_test_dirs
}

# Get the stack trace of a line from a file or function as it would appear in
# @go.print_stack_trace output.
#
# Arguments:
#   haystack_file:  File containing the line
#   function_name:  Function in which the line appears, 'main', or 'source'
#   needle_line:    Line for which to produce a stack trace line
stack_trace_item() {
  # Seriously, it's faster to run a script containing a `for` or `while read`
  # loop over a file as a new process than it is to run the function in-process
  # under Bats. Haven't yet figured out why.
  "${BASH_SOURCE%/*}/stack-trace-item" "$@"
}

log_command_stack_trace_item() {
  if [[ -z "$LOG_COMMAND_STACK_TRACE_ITEM" ]]; then
    export LOG_COMMAND_STACK_TRACE_ITEM="$(stack_trace_item \
      "$_GO_CORE_DIR/lib/log" '@go.log_command' '  "${args[@]}"')"
  fi
  echo "$LOG_COMMAND_STACK_TRACE_ITEM"
}

# Call this before using "${GO_CORE_STACK_TRACE_COMPONENTS[@]}" to inject
# entries from go-core.bash into your expected stack trace output.
set_go_core_stack_trace_components() {
  local go_core_file="$_GO_CORE_DIR/go-core.bash"
  local stack_item
  local IFS=$'\n'

  if [[ "${#GO_CORE_STACK_TRACE_COMPONENTS[@]}" -eq '0' ]]; then
    create_test_go_script '@go "$@"'
    create_test_command_script 'print-stack-trace' '@go.print_stack_trace'

    for stack_item in $("$TEST_GO_SCRIPT" 'print-stack-trace'); do
      if [[ "$stack_item" =~ $go_core_file ]]; then
        GO_CORE_STACK_TRACE_COMPONENTS+=("$stack_item")
      elif [[ "${#_GO_CORE_STACK_TRACE_COMPONENTS[@]}" -ne '0' ]]; then
        return
      fi
    done
    export GO_CORE_STACK_TRACE_COMPONENTS
  fi
}
