export WORK=$(realpath -- $(dirname -- "${BASH_SOURCE[0]}"))

alias bazel=bazelisk

check_style() {
  $WORK/util/check_style
}
