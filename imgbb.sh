#!/usr/bin/env sh

## // imgbb.sh // ConzZah // 3/12/26 10:30 AM // ##

init () {
mode=""
suffix=""
filename=""
auth_token=""
content_type=""
cdback="$(pwd)"
deps="curl grep xxd sed tr"
ua="User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:148.0) Gecko/20100101 Firefox/148.0"

## quick depcheck
for dep in $deps; do
! command -v "$dep" >/dev/null && \
printf '\n%s\n\n' "---> ERROR: $dep MISSING" && exit 1
done

## enable anon mode when requested
case $1 in
'a'|'anon'|'--anon') mode="anon"; shift
[ -f "/run/user/1000/.cookie" ] && rm -f "/run/user/1000/.cookie" >/dev/null
curl -sLo '/run/user/1000/.cookie' 'https://gist.github.com/ConzZah/db3037f077110779634f452d05623c3e/raw/imgbb.txt' || exit 1 ;;
*) :;;
esac

## check for imgbb cookie and run _login if none is found
[ "$mode" != "anon" ] && {
[ ! -f '.cookie' ] || [ -f '.cookie' ] && { ! grep -q 'LID' '.cookie' >/dev/null ;} && _login
[ -f '.cookie' ] && cp -f '.cookie' '/run/user/1000/.cookie' >/dev/null 2>&1
}

## ensure that "$1" exists & is a file
[ -z "$1" ] || [ ! -f "$1" ] && printf '\n%s\n\n' '--> ERROR: PLS ENTER A VALID PATH TO A FILE.' && exit 1
[ -n "$1" ] && [ -f "$1" ] && filename="$1"

## if the file is not in the directory that we're currently in,
## cd to that directory and obtain the 'actual' $filename
printf '%s' "$filename"| grep -q '/' && {
cd "$(printf '%s' "$filename"| rev| cut -d '/' -f 2-| rev)" || exit 1
filename="$(printf '%s' "$filename"| rev| cut -d '/' -f 1| rev)"
}

## check if file doesn't exceed the max filesize (32mb)
[ "$(stat -c %s "$filename")" -gt "32000000" ] && printf '\n%s\n\n' '--> ERROR: FILE TOO LARGE' && exit 1

## copy our file to /run/user/1000 (basically to ram) and cd.
cp -f "$filename" "/run/user/1000/$filename" >/dev/null 2>&1 && \
cd "/run/user/1000/" || exit 1

## check if file is actually an image file
suf="$(printf '%s' "$filename"| rev| cut -d '.' -f 1| rev)"
sufs="arw avif bmp cr2 cr3 cur cut dcm dds dib dng emf exr fax fig fits fpx gbr gd gif hdr heic heif icns ico iff ilbm j2k jpe jpeg jpg jpf jpm jp2 jpx miff mng mpo nef nrrd orf pbm pcx pdf pgm pic pict png pnm ppm ps psb psd qoi raf raw rw2 sgi sid sr2 svg tga tif tiff vtf webp wmf xbm xcf xpm jpeg tiff heif"
for s in $sufs; do
[ "$s" = "$suf" ] && suffix="$suf" && break
done

## if $suffix should still be empty, exit
[ -z "$suffix" ] && printf '\n%s\n\n' '--> ERROR: INVALID FILE TYPE' && exit 1

## if still alive, set content type
content_type="image/${suffix}"
}

main () {
gen_geckoformboundary
gen_auth_token
prep_form
upload
}

prep_form () {
## write skeleton
printf '%s\n' "--${geckoformboundary}
Content-Disposition: form-data; name=\"source\"; filename=\"$filename\"
Content-Type: $content_type
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

gen_auth_token () { auth_token="$(curl -s -b '.cookie' -c '.cookie' 'https://imgbb.com/login' -H "$ua" -H 'Connection: keep-alive'| grep -o 'PF.obj.config.auth_token.*'| cut -d '"' -f 2)" ;}

gen_geckoformboundary () { geckoformboundary="----geckoformboundary$(xxd -p -l 16 /dev/urandom| tr -d '\n')" ;}

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
rm -f '.skeleton-p1' '.skeleton-p2' '.upload' '.cookie' "$filename" >/dev/null
cd "$cdback" || exit 1; exit
}

_login () {
## basic auth to obtain '.cookie'
printf '\n%s\n' '--> COULD NOT FIND IMGBB COOKIE, STARTING LOGIN'
[ -f '.cookie' ] && rm -f '.cookie'
mail=""; pass=""
gen_auth_token

printf '\n%s' 'MAIL --> '
read -r mail

printf '\n%s' 'PASS --> '
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

## check if we actually obtained 'LID' and go back to init, else exit
! grep -q 'LID' '.cookie' && printf '\n%s\n\n' '--> LOGIN FAILED' && exit 1 || printf '\n%s\n\n' '--> LOGIN SUCCESSFUL' && init "$args"
}

args="$*"
init "$@" && main
