#!/usr/bin/env sh

## // imgbb.sh // ConzZah // 3/14/26 2:40 AM // ##

_help () {
printf '\n%s\n\n' "
/// imgbb.sh // ConzZah // 2026 ///

USAGE:

sh imgbb.sh [OPTION] [FILENAMES]

OPTIONS:

login    login to imgbb account

help     show help
";}
[ -z "$1" ] && _help && exit

init () {
fc="0"
mode=""
filenames=""
auth_token=""
deps="curl grep xxd sed tr"
cdback="$(cd "$(dirname "$0")" && pwd)"
ua="User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:148.0) Gecko/20100101 Firefox/148.0"

## quick depcheck
for dep in $deps; do
! command -v "$dep" >/dev/null && \
printf '\n%s\n\n' "---> ERROR: $dep MISSING" && exit 1
done

## process args
until [ "$#" = '0' ]; do
case $1 in

## login
'login'|'--login') _login;;

## help
'h'|'-h'|'help'|'--help') help; exit ;;

## anon-mode
'a'|'-a'|'anon'|'--anon') mode="anon"; shift
[ -f "/run/user/1000/.cookie" ] && rm -f "/run/user/1000/.cookie" >/dev/null
curl -sLo '/run/user/1000/.cookie' 'https://gist.github.com/ConzZah/db3037f077110779634f452d05623c3e/raw/imgbb.txt' || exit 1 ;;

## file processing
*) [ -f "$1" ] && {
suffix=""; filename=""; filename="$1"
## if the file is not in the directory that we're currently in,
## cd to that directory and obtain the 'actual' $filename
printf '%s' "$filename"| grep -q '/' && {
cd "$(printf '%s' "$filename"| rev| cut -d '/' -f 2-| rev)" || exit 1
filename="$(printf '%s' "$filename"| rev| cut -d '/' -f 1| rev)" ;}

## check if $filename doesn't exceed the max filesize (32mb)
[ "$(stat -c %s "$filename")" -gt "32000000" ] && printf '\n%s\n\n' "--> ERROR: FILE: $filename IS TOO LARGE" && exit 1

## check if file is actually an image file
suf="$(printf '%s' "$filename"| rev| cut -d '.' -f 1| rev)"
sufs="arw avif bmp cr2 cr3 cur cut dcm dds dib dng emf exr fax fig fits fpx gbr gd gif hdr heic heif icns ico iff ilbm j2k jpe jpeg jpg jpf jpm jp2 jpx miff mng mpo nef nrrd orf pbm pcx pdf pgm pic pict png pnm ppm ps psb psd qoi raf raw rw2 sgi sid sr2 svg tga tif tiff vtf webp wmf xbm xcf xpm jpeg tiff heif"
for s in $sufs; do
[ "$s" = "$suf" ] && suffix="$suf" && break
done

## if $suffix should still be empty, exit
[ -z "$suffix" ] && printf '\n%s\n\n' "--> ERROR: INVALID FILE TYPE FOR: $filename" && exit 1

## copy our file to /run/user/1000 (basically to ram)
cp -f "$filename" "/run/user/1000/$filename" >/dev/null 2>&1
cd "$cdback" || exit 1

## add to filenames & increment $fc
filenames="$filename $filenames"
fc="$((fc + 1))" ;}

## if input is not a file, show _help & exit
[ ! -f "$1" ] && _help && exit
shift ;;
esac
done

## check for imgbb cookie and run _login if none is found
[ "$mode" != "anon" ] && {
[ ! -f '.cookie' ] && _login
[ -f '.cookie' ] && { ! grep -q 'LID' '.cookie' ;} && _login
[ -f '.cookie' ] && cp -f '.cookie' '/run/user/1000/.cookie' >/dev/null 2>&1 ;}
}

main () {
## cd to /run/user/1000/
cd "/run/user/1000/" || exit 1
## run until all filenames are processed 
until [ "$fc" = "0" ]; do
for filename in $filenames; do
gen_geckoformboundary
gen_auth_token
prep_form
upload
fc="$((fc - 1))"
done
done
rm -f '.cookie'
cd "$cdback" || exit 1; exit
}

gen_geckoformboundary () { geckoformboundary="----geckoformboundary$(xxd -p -l 16 /dev/urandom| tr -d '\n')" ;}

gen_auth_token () { auth_token="$(curl -s -b '.cookie' -c '.cookie' 'https://imgbb.com/' -H "$ua" -H 'Connection: keep-alive'| grep -o 'PF.obj.config.auth_token.*'| cut -d '"' -f 2)" ;}

prep_form () {
## write skeleton
printf '%s\n' "--${geckoformboundary}
Content-Disposition: form-data; name=\"source\"; filename=\"$filename\"
Content-Type: image/$(printf '%s' "$filename"| rev| cut -d '.' -f 1| rev)
" > '.skeleton-p1'

printf '%s' "
--${geckoformboundary}
Content-Disposition: form-data; name=\"type\"

file
--${geckoformboundary}
Content-Disposition: form-data; name=\"action\"

upload
--${geckoformboundary}
Content-Disposition: form-data; name=\"timestamp\"

$(date +%s%3N)
--${geckoformboundary}
Content-Disposition: form-data; name=\"auth_token\"

$auth_token
--${geckoformboundary}--" > '.skeleton-p2'

## concatenate
cat ".skeleton-p1" "$filename" ".skeleton-p2" > '.upload'
}

upload () {
curl -b '.cookie' 'https://imgbb.com/json' \
  --compressed \
  -X POST \
  -H "$ua" \
  -H 'Accept: application/json' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H "Content-Type: multipart/form-data; boundary=${geckoformboundary}" \
  -H 'Origin: https://imgbb.com' \
  -H 'Sec-GPC: 1' \
  -H 'Connection: close' \
  -H 'Referer: https://imgbb.com/' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Priority: u=0' \
  -H 'Pragma: no-cache' \
  -H 'Cache-Control: no-cache' \
  -H 'TE: trailers' \
  --data-binary @'.upload'| sed 's#\\##g'| tr ',' '\n'

## note that we don't kill the original files, merely the ones in /run/user/1000
rm -f '.skeleton-p1' '.skeleton-p2' '.upload' "$filename" >/dev/null
}

_login () {
## basic auth to obtain '.cookie'
printf '\n%s\n' '--> LOGIN'
[ -f '.cookie' ] && rm -f '.cookie'
mail=""; pass=""
gen_auth_token

printf '\n%s' '--> MAIL: '
read -r mail

printf '\n%s' '--> PASS: '
read -r pass

curl -sb '.cookie' -c '.cookie' 'https://imgbb.com/login' \
  -X POST \
  -H "$ua" \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Origin: https://imgbb.com' \
  -H 'Sec-GPC: 1' \
  -H 'Connection: keep-alive' \
  -H 'Referer: https://imgbb.com/login' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Priority: u=0, i' \
  -H 'Pragma: no-cache' \
  -H 'Cache-Control: no-cache' \
  -H 'TE: trailers' \
  --data-urlencode "auth_token=${auth_token}" --data-urlencode "login-subject=${mail}" --data-urlencode "password=${pass}"

## check if we actually obtained 'LID' & exit 0 if we do, else exit 1
! grep -q 'LID' '.cookie' && printf '\n%s\n\n' '--> LOGIN FAILED' && exit 1 || printf '\n%s\n\n' '--> LOGIN SUCCESSFUL' && exit 0
}

init "$@"; main
