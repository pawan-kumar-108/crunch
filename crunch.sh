#!/usr/bin/env bash
# crunch — terminal number truth engine
# usage: crunch <data|sip|loan|inf|cagr|help> [args]
set -euo pipefail

R='\033[0;31m';Y='\033[0;33m';G='\033[0;32m';C='\033[0;36m'
B='\033[1m';D='\033[2m';M='\033[0;35m';W='\033[1;37m';X='\033[0m'

calc(){ local e="$1" s="${2:-6}"; echo "scale=$s;$e"|bc -l 2>/dev/null||echo "0"; }
trim(){ echo "$1"|sed 's/\.0*$//;s/\(\.[0-9]*[1-9]\)0*$/\1/'; }
fmt(){ printf "%.2f" "${1:-0}" 2>/dev/null|sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'||echo "0.00"; }
hdr(){ echo -e "\n${B}${W}▸ $1${X}"; echo -e "${D}$(printf '─%.0s' {1..50})${X}"; }
banner(){
  echo -e "${B}${C}  ██████╗██████╗ ██╗   ██╗███╗  ██╗ ██████╗██╗  ██╗"
  echo -e "  ██╔════╝██╔══██╗██║   ██║████╗ ██║██╔════╝██║  ██║"
  echo -e "  ██║     ██████╔╝██║   ██║██╔██╗██║██║     ███████║"
  echo -e "  ╚██████╗██║  ██║╚██████╔╝██║ ╚███║╚██████╗██║  ██║"
  echo -e "   ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚══╝ ╚═════╝╚═╝  ╚═╝${X}"
  echo -e "${D}  terminal number truth engine${X}\n"; }

spark(){
  local -a v=("$@"); local b=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')
  local mn=${v[0]} mx=${v[0]} rng idx out=""
  for x in "${v[@]}"; do
    (( $(echo "$x<$mn"|bc -l 2>/dev/null||echo 0) ))&&mn=$x
    (( $(echo "$x>$mx"|bc -l 2>/dev/null||echo 0) ))&&mx=$x; done
  rng=$(calc "$mx-$mn"); [[ $(echo "$rng==0"|bc -l 2>/dev/null) == "1" ]]&&rng=1
  for x in "${v[@]}"; do
    idx=$(calc "int(($x-$mn)/$rng*7)" 0)
    [[ $idx -lt 0 ]]&&idx=0; [[ $idx -gt 7 ]]&&idx=7; out+="${b[$idx]}"; done
  echo "$out"; }

bbar(){
  local v="$1" mx="$2" w="${3:-28}" col="${4:-$G}" f e
  f=$(calc "int($v/$mx*$w)" 0); [[ $f -lt 0 ]]&&f=0; [[ $f -gt $w ]]&&f=$w; e=$(( w-f ))
  printf "${col}%s${D}%s${X}" "$(printf '█%.0s' $(seq 1 $f 2>/dev/null||echo ""))" \
    "$(printf '░%.0s' $(seq 1 $e 2>/dev/null||echo ""))"; }

# ── DATA MODE ─────────────────────────────────────────────────────────────────
mode_data(){
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    [[ -t 0 ]]&&{ echo -e "${R}error:${X} provide a CSV or pipe data in\n  ${D}crunch data file.csv${X}">&2;exit 1; }
    file=$(mktemp /tmp/crunch_XXXX.csv); cat>"$file"; trap "rm -f '$file'" EXIT
  fi
  [[ ! -f "$file" ]]&&{ echo -e "${R}error:${X} file not found: $file">&2;exit 1; }
  [[ ! -s "$file" ]]&&{ echo -e "${R}error:${X} file is empty">&2;exit 1; }
  banner; echo -e "${D}  source: $file${X}\n"
  local dlm=","; local fl; fl=$(head -1 "$file" 2>/dev/null||echo "")
  echo "$fl"|grep -q $'\t'&&dlm=$'\t'; echo "$fl"|grep -q ';'&&dlm=';'
  local -a hdrs; IFS="$dlm" read -ra hdrs<<<"$fl"
  local nc=${#hdrs[@]} nr; nr=$(( $(wc -l<"$file")-1 ))
  [[ $nr -lt 1 ]]&&{ echo -e "${R}error:${X} no data rows">&2;exit 1; }
  hdr "FILE OVERVIEW"
  printf "  ${D}%-16s${X} %s\n" "rows" "$nr"; printf "  ${D}%-16s${X} %s\n" "columns" "$nc"
  printf "  ${D}%-16s${X} %s\n" "size" "$(du -h "$file" 2>/dev/null|cut -f1||echo '?')"
  hdr "COLUMN PROFILES"
  local ci
  for (( ci=1; ci<=nc; ci++ )); do
    local cn="${hdrs[$((ci-1))]}"; cn=$(echo "$cn"|tr -d '"'|xargs 2>/dev/null||echo "col_$ci")
    local -a rv; mapfile -t rv < <(tail -n+2 "$file" 2>/dev/null|\
      awk -F"$dlm" -v c="$ci" '{v=$c;gsub(/^[ \t"]+|[ \t"]+$/,"",v);if(v!="")print v}' 2>/dev/null||true)
    local tot=${#rv[@]} nulls=$(( nr-${#rv[@]} )) npct
    npct=$(calc "$nulls*100/$nr" 1)
    local -a nv=()
    for v in "${rv[@]}"; do [[ "$v" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]&&nv+=("$v"); done
    local nc2=${#nv[@]}
    echo -e "\n  ${B}${C}$cn${X} ${D}(col $ci)${X}"
    if [[ $nc2 -gt 1 ]]; then
      local st; st=$(printf '%s\n' "${nv[@]}"|sort -n|awk '
        BEGIN{sum=0;sum2=0;n=0;mn="";mx=""}
        {v=$1+0;n++;sum+=v;sum2+=v*v
         if(mn==""||v<mn)mn=v;if(mx==""||v>mx)mx=v;vals[n]=v}
        END{if(n==0){print "0 0 0 0 0 0 0 0 0";exit}
          me=sum/n;va=(sum2/n)-(me*me);sd=(va>0)?sqrt(va):0
          md=(n%2==1)?vals[int(n/2)+1]:(vals[n/2]+vals[n/2+1])/2
          sk=0;ku=0
          for(i=1;i<=n;i++){if(sd>0){sk+=((vals[i]-me)/sd)^3;ku+=((vals[i]-me)/sd)^4}}
          printf "%.4f %.4f %.4f %.4f %.4f %.4f %.4f",me,sd,md,mn,mx,(sd>0)?sk/n:0,(sd>0)?ku/n-3:0}')
      read -r me sd md mn mx sk ku<<<"$st"
      printf "    ${D}%-14s${X} ${W}%s${X}  ${D}nulls: %s%%${X}\n" "count/nulls" "$nc2" "$npct"
      printf "    ${D}%-14s${X} ${W}%s${X}\n"   "mean"    "$(trim $me)"
      printf "    ${D}%-14s${X} %s\n"           "median"  "$(trim $md)"
      printf "    ${D}%-14s${X} %s\n"           "std dev" "$(trim $sd)"
      printf "    ${D}%-14s${X} ${R}%s${X} → ${G}%s${X}\n" "range" "$(trim $mn)" "$(trim $mx)"
      local sl="symmetric"
      (( $(echo "$sk>0.5"|bc -l 2>/dev/null||echo 0) ))&&sl="right-skewed ▶"
      (( $(echo "$sk<-0.5"|bc -l 2>/dev/null||echo 0) ))&&sl="left-skewed ◀"
      printf "    ${D}%-14s${X} %s ${D}(%s)${X}\n" "skew" "$(trim $sk)" "$sl"
      local kl="normal tails"
      (( $(echo "$ku>1"|bc -l 2>/dev/null||echo 0) ))&&kl="heavy tails ⚠"
      (( $(echo "$ku<-1"|bc -l 2>/dev/null||echo 0) ))&&kl="light tails"
      printf "    ${D}%-14s${X} %s ${D}(%s)${X}\n" "kurtosis" "$(trim $ku)" "$kl"
      local oc=0
      for v in "${nv[@]}"; do
        (( $(echo "$sd>0"|bc -l 2>/dev/null||echo 0) ))||break
        local z; z=$(calc "($v-$me)/$sd"); local az; az=$(calc "if($z<0)-1*$z else $z")
        (( $(echo "$az>3"|bc -l 2>/dev/null||echo 0) ))&&(( oc++ ))||true; done
      local ocol=$G; [[ $oc -gt 0 ]]&&ocol=$R
      printf "    ${D}%-14s${X} ${ocol}%s${X} ${D}(|Z|>3)${X}\n" "outliers" "$oc"
      local -a sv=(); local step=$(( nc2/40+1 )) si=0
      for v in "${nv[@]}"; do (( si++%step==0 ))&&sv+=("$v")||true; done
      [[ ${#sv[@]} -gt 1 ]]&&printf "    ${D}%-14s${X} ${M}%s${X}\n" "sparkline" "$(spark "${sv[@]}")"
    else
      local uq; uq=$(printf '%s\n' "${rv[@]}"|sort -u|wc -l)
      printf "    ${D}%-14s${X} categorical\n    ${D}%-14s${X} ${W}%s${X}  unique: %s  nulls: ${Y}%s%%${X}\n" \
        "type" "count" "$tot" "$uq" "$npct"
      printf '%s\n' "${rv[@]}"|sort|uniq -c|sort -rn|head -3|\
        awk '{$1=$1;printf "      %-5s× %s\n",$1,substr($0,index($0,$2))}' 2>/dev/null||true
    fi; done
  echo -e "\n${D}$(printf '─%.0s' {1..50})${X}"; echo -e "${G}  ✓ crunch complete${X}\n"; }

# ── SIP MODE ──────────────────────────────────────────────────────────────────
mode_sip(){
  local amt="${1:-}" rt="${2:-}" yr="${3:-}"
  [[ -z "$amt|$rt|$yr" || ! "$amt" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$rt" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$yr" =~ ^[0-9]+$ ]] && \
    { echo -e "${R}error:${X} crunch sip <monthly_amount> <annual_rate%> <years>">&2;exit 1; }
  (( yr<1||yr>50 ))&&{ echo -e "${R}error:${X} years must be 1–50">&2;exit 1; }
  banner; hdr "SIP PROJECTION"
  printf "  ${D}%-20s${X} ₹%s/mo  %s%%  %s yrs\n" "inputs" "$(fmt $amt)" "$rt" "$yr"
  local mr; mr=$(calc "$rt/100/12"); local mo=$(( yr*12 ))
  local inv; inv=$(calc "$amt*$mo")
  local fv; fv=$(calc "$amt*(((1+$mr)^$mo-1)/$mr)*(1+$mr)")
  local gain; gain=$(calc "$fv-$inv"); local gpct; gpct=$(calc "$gain*100/$inv" 1)
  local rfv; rfv=$(calc "$fv/(1+0.06)^$yr")
  hdr "RESULTS"
  printf "\n  ${D}%-20s${X} ${W}₹%s${X}\n  ${D}%-20s${X} ${G}₹%s${X}\n  ${D}%-20s${X} ${G}+₹%s${X} ${D}(+%s%%)${X}\n  ${D}%-20s${X} ${Y}₹%s${X} ${D}(6%% inflation adj)${X}\n" \
    "total invested" "$(fmt $inv)" "estimated value" "$(fmt $fv)" "wealth gain" "$(fmt $gain)" "$(trim $gpct)" "real value today" "$(fmt $rfv)"
  hdr "YEAR-BY-YEAR"
  printf "\n  ${D}%-5s %-15s %-15s %s${X}\n" "yr" "invested" "value" "growth"
  local -a yv=(); local y
  for (( y=1; y<=yr; y++ )); do
    local v; v=$(calc "$amt*(((1+$mr)^$(( y*12 ))-1)/$mr)*(1+$mr)"); yv+=("$v"); done
  for (( y=1; y<=yr; y++ )); do
    local yi; yi=$(calc "$amt*$(( y*12 ))")
    printf "  %-5s ${W}₹%-13s${X} ₹%-13s $(bbar "${yv[$((y-1))]}" "$fv" 18 "$G") ${G}+₹%s${X}\n" \
      "$y" "$(fmt $yi)" "$(fmt ${yv[$((y-1))]})" "$(fmt $(calc "${yv[$((y-1))]}-$yi"))"; done
  echo -e "\n  ${D}curve:${X} ${M}$(spark "${yv[@]}")${X}"
  echo -e "\n${D}$(printf '─%.0s' {1..50})${X}"; echo -e "${G}  ✓ crunch complete${X}\n"; }

# ── LOAN MODE ─────────────────────────────────────────────────────────────────
mode_loan(){
  local P="${1:-}" rt="${2:-}" yr="${3:-}"
  [[ -z "$P" || ! "$P" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$rt" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$yr" =~ ^[0-9]+$ ]] && \
    { echo -e "${R}error:${X} crunch loan <principal> <annual_rate%> <years>">&2;exit 1; }
  (( yr<1||yr>30 ))&&{ echo -e "${R}error:${X} years: 1–30">&2;exit 1; }
  (( $(echo "$rt>50"|bc -l 2>/dev/null||echo 0) ))&&{ echo -e "${R}error:${X} rate >50% not supported">&2;exit 1; }
  banner; hdr "LOAN DETAILS"
  printf "  ${D}%-18s${X} ₹%s at %s%% for %s yrs\n" "inputs" "$(fmt $P)" "$rt" "$yr"
  local r; r=$(calc "$rt/100/12"); local n=$(( yr*12 ))
  local emi; emi=$(calc "$P*$r*(1+$r)^$n/((1+$r)^$n-1)")
  local tot; tot=$(calc "$emi*$n"); local tint; tint=$(calc "$tot-$P")
  local ipct; ipct=$(calc "$tint*100/$P" 1)
  hdr "EMI BREAKDOWN"
  printf "\n  ${B}${W}  EMI = ₹%s / month${X}\n\n" "$(fmt $emi)"
  printf "  ${D}%-20s${X} ${W}₹%s${X}\n  ${D}%-20s${X} ₹%s\n  ${D}%-20s${X} ${R}₹%s${X} ${D}(+%s%%)${X}\n" \
    "total payment" "$(fmt $tot)" "principal" "$(fmt $P)" "total interest" "$(fmt $tint)" "$(trim $ipct)"
  local pw; pw=$(calc "int($P/$tot*36)" 0); local iw=$(( 36-pw ))
  printf "\n  ${D}principal${X} \033[0;34m%s${R}%s${X} ${D}interest${X}\n" \
    "$(printf '█%.0s' $(seq 1 $pw 2>/dev/null||echo ""))" "$(printf '█%.0s' $(seq 1 $iw 2>/dev/null||echo ""))"
  hdr "YEARLY AMORTIZATION"
  printf "\n  ${D}%-5s %-14s %-14s %-13s${X}\n" "yr" "principal pd" "interest pd" "balance"
  local bal=$P; local -a ba=(); local y
  for (( y=1; y<=yr; y++ )); do
    local yp=0 yi=0 mo
    for (( mo=1; mo<=12; mo++ )); do
      local ip; ip=$(calc "$bal*$r"); local pp; pp=$(calc "$emi-$ip")
      yi=$(calc "$yi+$ip"); yp=$(calc "$yp+$pp"); bal=$(calc "$bal-$pp")
      (( $(echo "$bal<0"|bc -l 2>/dev/null||echo 0) ))&&bal=0; done
    ba+=("$bal")
    printf "  %-5s ${G}₹%-12s${X} ${R}₹%-12s${X} ${D}₹%-11s${X} $(bbar "$bal" "$P" 12 "\033[0;34m")\n" \
      "$y" "$(fmt $yp)" "$(fmt $yi)" "$(fmt $bal)"; done
  echo -e "\n  ${D}balance decay:${X} ${M}$(spark "${ba[@]}")${X} → 0"
  echo -e "\n${D}$(printf '─%.0s' {1..50})${X}"; echo -e "${G}  ✓ crunch complete${X}\n"; }

# ── INFLATION MODE ─────────────────────────────────────────────────────────────
mode_inf(){
  local amt="${1:-}" rt="${2:-}" yr="${3:-}"
  [[ -z "$amt" || ! "$amt" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$rt" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$yr" =~ ^[0-9]+$ ]] && \
    { echo -e "${R}error:${X} crunch inf <amount> <inflation_rate%> <years>">&2;exit 1; }
  (( yr<1||yr>100 ))&&{ echo -e "${R}error:${X} years: 1–100">&2;exit 1; }
  banner; hdr "INFLATION EROSION"
  printf "  ₹%s at %s%% inflation for %s years\n" "$(fmt $amt)" "$rt" "$yr"
  local fin; fin=$(calc "$amt/(1+$rt/100)^$yr")
  local lost; lost=$(calc "$amt-$fin"); local lpct; lpct=$(calc "$lost*100/$amt" 1)
  hdr "PURCHASING POWER"
  printf "\n  ${D}₹%s today${X} → real buying power of ${R}₹%s${X}\n" "$(fmt $amt)" "$(fmt $fin)"
  printf "  ${D}value lost:${X} ${R}₹%s${X} ${D}(-%s%%)${X}\n\n" "$(fmt $lost)" "$(trim $lpct)"
  local -a yv=(); local y lim=$yr; (( yr>20 ))&&lim=20
  for (( y=1; y<=yr; y++ )); do
    local v; v=$(calc "$amt/(1+$rt/100)^$y"); yv+=("$v")
    if (( y<=lim )); then
      printf "  yr %-4s $(bbar "$v" "$amt" 24 "$Y") ${Y}₹%s${X}\n" "$y" "$(fmt $v)"; fi
    (( y==lim && yr>lim ))&&printf "  \033[2m  ... (%s years total)\033[0m\n" "$yr"; done
  echo -e "\n  ${D}erosion:${X} ${M}$(spark "${yv[@]}")${X}"
  echo -e "\n${D}$(printf '─%.0s' {1..50})${X}"; echo -e "${G}  ✓ crunch complete${X}\n"; }

# ── CAGR MODE ─────────────────────────────────────────────────────────────────
mode_cagr(){
  local s="${1:-}" e="${2:-}" yr="${3:-}"
  [[ -z "$s" || ! "$s" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$e" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$yr" =~ ^[0-9]+$ ]] && \
    { echo -e "${R}error:${X} crunch cagr <start> <end> <years>">&2;exit 1; }
  (( $(echo "$s==0"|bc -l 2>/dev/null||echo 1) ))&&{ echo -e "${R}error:${X} start cannot be zero">&2;exit 1; }
  (( yr<1 ))&&{ echo -e "${R}error:${X} years must be ≥1">&2;exit 1; }
  banner; hdr "CAGR CALCULATOR"
  local cagr; cagr=$(calc "(($e/$s)^(1/$yr)-1)*100" 2)
  local tr; tr=$(calc "($e-$s)*100/$s" 1)
  local col=$G dir="grew"; (( $(echo "$e<$s"|bc -l 2>/dev/null||echo 0) ))&&col=$R&&dir="fell"
  printf "\n  ₹%s → ₹%s over %s years\n\n" "$(fmt $s)" "$(fmt $e)" "$yr"
  printf "  ${D}%-18s${X} ${col}${B}%s%%${X} per year\n  ${D}%-18s${X} ${col}%s%%${X} total\n" \
    "CAGR" "$(trim $cagr)" "total return" "$(trim $tr)"
  printf "  ${D}%-18s${X} investment %s at %s%% p.a.\n" "verdict" "$dir" "$(trim $cagr)"
  hdr "GROWTH PATH"
  local -a pv=(); local y
  for (( y=0; y<=yr; y++ )); do
    local v; if (( y==0 )); then v="$s"; elif (( y==yr )); then v="$e"; else v=$(echo "scale=6;e(l($e/$s)*($y/$yr))*$s"|bc -l 2>/dev/null||echo "$s"); fi; pv+=("$v")
    local bw; bw=$(echo "$v $e" | awk '{r=int($1/$2*28); print (r<1)?1:r}')
    printf "  yr %-4s ${col}%s${X} ₹%s\n" "$y" "$(printf '█%.0s' $(seq 1 $bw 2>/dev/null||echo ""))" "$(fmt $v)"; done
  echo -e "\n  ${D}trajectory:${X} ${M}$(spark "${pv[@]}")${X}"
  echo -e "\n${D}$(printf '─%.0s' {1..50})${X}"; echo -e "${G}  ✓ crunch complete${X}\n"; }

# ── HELP ──────────────────────────────────────────────────────────────────────
show_help(){
  banner
  echo -e "  ${B}usage:${X}  crunch <mode> [args]\n"
  printf "  ${C}%-6s${X} ${D}%-32s${X} %s\n" "data" "<file.csv> or stdin pipe"     "full CSV statistical profile"
  printf "  ${C}%-6s${X} ${D}%-32s${X} %s\n" "sip"  "<amount> <rate%> <years>"     "SIP projection + real returns"
  printf "  ${C}%-6s${X} ${D}%-32s${X} %s\n" "loan" "<principal> <rate%> <years>"  "EMI + amortization table"
  printf "  ${C}%-6s${X} ${D}%-32s${X} %s\n" "inf"  "<amount> <rate%> <years>"     "inflation purchasing power decay"
  printf "  ${C}%-6s${X} ${D}%-32s${X} %s\n" "cagr" "<start> <end> <years>"        "compound annual growth rate"
  echo -e "\n  ${D}examples:${X}"
  echo "    crunch data   sales.csv"; echo "    crunch sip    10000 12 20"
  echo "    crunch loan   5000000 8.5 20"; echo "    crunch inf    1000000 6 30"
  echo "    crunch cagr   100000 450000 10"; echo "    cat data.csv | crunch data"; echo ""; }

main(){ local m="${1:-help}"; shift 2>/dev/null||true
  case "$m" in data) mode_data "$@";; sip) mode_sip "$@";; loan) mode_loan "$@";;
    inf) mode_inf "$@";; cagr) mode_cagr "$@";; help|--help|-h) show_help;;
    *) echo -e "${R}error:${X} unknown mode '$m' — run: crunch help">&2;exit 1;; esac; }
main "$@"