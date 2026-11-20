#!/bin/zsh
# Falha se AGENTS.md, DESIGN.md ou docs/ citarem entre crases um caminho ou símbolo que não existe mais.
# Caminho: algo com "/" ou terminado em .swift/.md/.sh. Símbolo: Palavra começando com maiúscula (ou Tipo.membro).
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
for doc in AGENTS.md DESIGN.md docs/*.md; do
  for token in $(grep -oE '`[^` ]+`' "$doc" | tr -d '`' | sort -u); do
    case "$token" in
      ~*|/*|build/*|.build/*|*'<'*|*'…'*|http*|*'*'*|--*) continue ;;  # caminhos do sistema/usuário, gerados, exemplos e flags
    esac
    if [[ "$token" == */* || "$token" == *.swift || "$token" == *.md || "$token" == *.sh ]]; then
      [[ "$token" == */ ]] && token="${token%/}"
      if [[ "$token" != */* ]]; then   # nome solto: basta existir em algum lugar do projeto
        [[ -n "$(find Sources Tests scripts brand docs . -maxdepth 4 -name "$token" -not -path './.build/*' 2>/dev/null | head -1)" ]] \
          || { echo "$doc: arquivo não existe: $token"; fail=1; }
      else
        [[ -e "$token" ]] || { echo "$doc: caminho não existe: $token"; fail=1; }
      fi
    elif [[ -e "$token" ]]; then
      continue   # arquivo na raiz sem extensão (ex.: LICENSE, NOTICE)
    elif [[ "$token" =~ '^[A-Z][A-Za-z]+(\.[a-z][A-Za-z]+)?$' ]]; then
      name="${token##*.}"
      grep -rqw -- "$name" Sources Tests scripts || { echo "$doc: símbolo não existe: $token"; fail=1; }
    fi
  done
done
(( fail == 0 )) && echo "Docs ok"
exit $fail
