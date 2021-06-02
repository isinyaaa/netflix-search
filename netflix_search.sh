#! /bin/bash

catalog="netflix_titles.csv"

# TODO usar tr e iconv para formatar a database antes de pesquisar (de alguma forma que preserve os dados originais)

# funcao de help
help_script()
{
  #head -n 1 $catalog | sed -e 's/,/\n/g' | nl
  echo "Uso: $0 [OPCOES] [TEXTO]"
  echo "Pesquisa de TEXTO no catalogo $(echo $catalog | cut -d '_' -f 1)."
  echo "Exemplo: $0 Interstellar"
  echo "OPCOES pode conter diversas opcoes de filtragem"
  echo
  echo "-c TEXTO			para pesquisar por país"
  echo "-d NUMBER[m[in],s[eason]]	para pesquisar titulos com uma duracao inferior a informada"
  echo "-D NUMBER[m[in],s[eason]]	para pesquisar titulos com uma duracao inferior a informada"
  echo "-o NUMBER					para exigir as n primeiras entradas"
  echo "-l TEXTO			para pesquisar por categoria"
  echo "-t				para incluir o tipo do show desejado"
  echo "-v				para dar mais informacoes na saida"
  echo "-y NUMBER			para pesquisar por ano de lancamento"
  exit 0
}

# caso nao haja argumentos
if (( $# == 0 ))
then
  help_script
fi

# abreviacoes para cada coluna util
id_col=1 #*
type_col=2
title_col=3 #*
dir_col=4 #*
cast_col=5 #*
coun_col=6
year_col=8
dur_col=10
cat_col=11
desc_col=12

processed=$(mktemp)

# como utilizam-se ', ' para separar subcategorias internamente, podemos resolver quase todos os problemas trocando por @
sed -e 's/, /@/g' $catalog > $processed

# retirada de titulos problematicos (i.e. que tem ',' sobrando)
remove=$(mktemp)

# vamos numera-los \ # em seguida pegamos a duracao que so poode ter Season ou min \ # e cortamos tudo que nao sejam os numeros iniciais
cat $processed | nl | cut -d , -f 1,10 | grep -v "Season\|min" | cut -d "	" -f 1 > $remove

# essa linha precisa de intervencao manual
echo "  6110" >> $remove

tmp=$(mktemp)
cat $processed | nl > $tmp

while read line
do
  sed -i "/^ *$line/d" $tmp
done < $remove

sed -i 's/.*	//' $processed


# variaveis booleanas das buscas possiveis

## se for verbose
is_verb=false

## se a proxima entrada for um argumento
argument=false

## idem para pais
country=false

## idem para tempo
lessthan=false
morethan=false

## idem para linhas
lines=false

## idem para ano
year=false

## idem para categoria
category=false


# arquivo que guardara o resultado
result=$(mktemp)
# quantidade de linhas mostradas por padrao
line_count=5

# vamos verificar todos os argumentos passados
for arg in "$@"
do
  # essa variavel sera ocupada somente se nao houver - precedendo o argumento
  is_opt=$(echo $arg | grep -v '^-.*' )
  # portanto esse teste indica nos indica se trata-se de uma opcao
  if [ -z "$is_opt" ]
  then
    # vamos retirar o - das opcoes passadas
    arg=$(echo "$arg" | sed -e 's/-//')
    # aqui guardamos o comprimento do argumento atual
    len=$(expr length $arg)
    # forma suja de loopar uma string :p
    for i in $(seq $len)
    do
      # letra atual
      cur_char=${arg:(($i-1)):1}
      # para debug
      #printf '%s\n' "$cur_char"

      # parser para opcoes
      case $cur_char in
        c)
          argument=true
          country=true;;
        d)
          argument=true
          lessthan=true;;
        D)
          argument=true
          morethan=true;;
        h)
          help_script ;;
        l)
          argument=true
          category=true ;;
        o)
          argument=true
          lines=true ;;
        t)
          show_type=true ;;
        v)
          is_verb=true ;;
        y)
          argument=true
          year=true;;
        *)
          echo "por favor digite $0 -h para ver a utilizacao desse script" ;;
      esac
    done
  else
    # agora processamos as opcoes
    if $argument
    then
      aux=$(mktemp)
      if $country
      then
        # aqui vamos olhar para a coluna de paises e entao damos grep para retornar a lista de titulos (usando identificadores do catalogo)
        cut -d, -f1,6 $processed | grep -i "$arg" | cut -d, -f1 > $aux
      elif $category
      then
        # idem para categorias
        cut -d, -f1,11 $processed | sed -e 's/@/, /g' | grep -i "$arg" | cut -d, -f1 > $aux
      elif $year
      then
        # idem para ano de lancamento
        cut -d, -f1,8 $processed | grep -i ".*,.*$arg.*" | cut -d, -f1 > $aux
      elif $lessthan
      then
        # para duracao primeiro isolamos o valor e a unidade
        vals=$(mktemp)
        unit=$(sed -e 's/[[:digit:]]*\(.*\)/\1/' <<< $arg)
        num=$(sed -e 's/\([[:digit:]]*\).*/\1/' <<< $arg)
        cut -d , -f1,10 $processed | grep -i "$unit" > $vals
        aux1=$(mktemp)
        # para entao compara-los
        while read line
        do
          val=$(sed -e 's/.*,\([[:digit:]]*\).*/\1/' <<< $line)
          if (( $val < $num ))
          then
            echo $line >> $aux1
          fi
        done < $vals
        cut -d, -f1 $aux1 > $aux
      elif $morethan
      then
        vals=$(mktemp)
        unit=$(sed -e 's/[[:digit:]]*\(.*\)/\1/' <<< $arg)
        num=$(sed -e 's/\([[:digit:]]*\).*/\1/' <<< $arg)
        cut -d , -f1,10 $processed | grep -i "$unit" > $vals
        aux1=$(mktemp)
        while read line
        do
          val=$(sed -e 's/.*,\([[:digit:]]*\).*/\1/' <<< $line)
          if (( $val > $num ))
          then
            echo $line >> $aux1
          fi
        done < $vals
        cut -d, -f1 $aux1 > $aux
      elif $lines
      then
        line_count=$arg
      fi

      # zeramos o bool de argumentos
      argument=false

      # agora vamos interseccionar o filtro dos argumentos com as respostas ja buscadas
      if [ -s $result ]
      then
        aux2=$(mktemp)
        while read line
        do 
          grep -e "^$line," < $result >> $aux2
        done < $aux
        cat $aux2 > $result
      else
        while read line
        do 
          grep -e "^$line," < $processed >> $result
        done < $aux
      fi
      
      # aqui vamos buscar as respostas (by Gabriel)
    else
      #Novas Variaveis
      PRE_SEL=$(mktemp)
      SEL=$(mktemp)
      
      wanted_cols="$id_col,$title_col,$dir_col,$cast_col"
      
      #Colunas 
      cut -d, -f$wanted_cols $processed > $PRE_SEL

      #Procurando nessas colunas
      sed -e 's/@/, /g' $PRE_SEL | grep -i "$arg" | cut -d, -f1 > $SEL
      
      while read line
      do 
        grep -e "^$line," < $processed >> $result
      done < $SEL
    fi
  fi
done


# finalmente vamos printar tudo
if [ -s $result ]
then
  echo $(cat $result | wc -l) resultados
  # caso o usuario nao tenha declarado verbose podemos perguntar por confirmacao
  if ! $is_verb
  then
    echo "gostaria de exibir mais infos? (y/N)"
    read ans
    grep -i "y\|yes" <<< $ans && is_verb=true
  fi

  # caso seja verbose
  if $is_verb
  then
    # 1. cortamos os campos desejados
    # 2. selecionamos as linhas desejadas
    # 3. formatamos a saida
    # 4. trocamos @ por , para retornar a formatacao original
    # 5. e 6. servem para retirarmos as " da saida 
    cut -d, -f2,3,4,5,6,10,11,12 $result | head -n $line_count | sed -e 's/\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\)/\n\ntitulo: \2\ncategoria: \1\nduracao: \6\n\nPRODUCAO\n\ndirecao: \3\nelenco: \4\n\npais: \5\nSINOPSE:\n\8\n\7/' | sed -e 's/@/, /g' | sed -e 's/"//' | sed -e 's/."//'
  else
    # aqui temos versoes resumidas do verbose
    if $show_type
    then
      cut -d, -f2,3,10,11 $result | head -n $line_count | sed -e 's/\(.*\),\(.*\),\(.*\),\(.*\)/\n\ntitulo: \2\ncategoria: \1\nduracao: \3\n\4/' | sed -e 's/@/, /g' | sed -e 's/"//' | sed -e 's/."//'
    else
      cut -d, -f3,10,11 $result | head -n $line_count | sed -e 's/\(.*\),\(.*\),\(.*\)/\n\ntitulo: \1\nduracao: \2\n\3/' | sed -e 's/@/, /g' | sed -e 's/"//' | sed -e 's/."//'
    fi
  fi
  exit 0
else
  echo "Nao encontramos o que voce queria"
fi
