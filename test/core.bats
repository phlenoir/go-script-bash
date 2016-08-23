#! /usr/bin/env bats

@test "check exported global constants" {
  [[ $_GO_ROOTDIR = $PWD ]]
  [[ $_GO_SCRIPT == "$_GO_ROOTDIR/go" ]]
  [[ -n $COLUMNS ]]
}

@test "produce help message with error return when no args" {
  run test/go
  [[ $status -eq 1 ]]
  [[ ${lines[0]} = 'Usage: test/go <command> [arguments...]' ]]
}

@test "produce error for an unknown flag" {
  run test/go -foobar
  [[ $status -eq 1 ]]
  [[ ${lines[0]} = 'Unknown flag: -foobar' ]]
  [[ ${lines[1]} = 'Usage: test/go <command> [arguments...]' ]]
}

@test "invoke editor on edit command" {
  run env EDITOR=echo test/go edit 'editor invoked'
  [[ $status -eq 0 ]]
  [[ $output = 'editor invoked' ]]
}

@test "invoke run command" {
  run test/go run echo run command invoked
  [[ $status -eq 0 ]]
  [[ $output = 'run command invoked' ]]
}

@test "produce error on cd, pushd, and unenv" {
  local err_suffix='is only available after using "test/go env" to set up '
  err_suffix+='your shell environment.'

  run test/go cd
  [[ $status -eq 1 ]]
  [[ $output = "cd $err_suffix" ]]

  run test/go pushd
  [[ $status -eq 1 ]]
  [[ $output = "pushd $err_suffix" ]]

  run test/go unenv
  [[ $status -eq 1 ]]
  [[ $output = "unenv $err_suffix" ]]
}

@test "run shell alias command" {
  run test/go grep "$BATS_TEST_DESCRIPTION" "$BATS_TEST_FILENAME" >&2

  if command -v 'grep'; then
    echo "OUTPUT '$output'" >&2
    [[ status -eq 0 ]]
    [[ $output = "@test \"$BATS_TEST_DESCRIPTION\" {" ]]
  else
    [[ status -ne 0 ]]
  fi
}

@test "produce an error and list available commands if command not found" {
  run test/go foobar
  [[ status -eq 1 ]]
  [[ ${lines[0]} = 'Unknown command: foobar' ]]
  [[ ${lines[1]} = 'Available commands are:' ]]
  [[ ${lines[2]} = '  aliases' ]]
  [[ ${lines[$((${#lines[@]} - 1))]} = '  unenv' ]]
}
