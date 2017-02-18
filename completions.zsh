
if [[ ! -o interactive  ]]; then
  return
fi

compctl -K _bart bart

_bart() {
  local station stations completions
  read -cA stations
  station="${stations[2]}"

  # if [ "${#stations}" -eq 2  ]; then
  #   completions="$(fd commands)"
  # else
  #   completions="$(fd completions "${word}")"
  # fi

  setopt hist_subst_pattern
  reply=("${(ps: :)stations:gs/[[:space:]]/ }")
}

