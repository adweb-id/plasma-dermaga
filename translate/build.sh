#!/bin/sh
# Updates the translation template, merges it into every .po file and compiles
# them into contents/locale. Run from anywhere: sh translate/build.sh
set -e
cd "$(dirname "$0")/.."
DOMAIN="plasma_applet_com.adweb.dermaga"

xgettext --from-code=UTF-8 -C --kde -ci18n \
    -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    --package-name=dermaga --msgid-bugs-address=https://github.com/adweb-id/plasma-dermaga/issues \
    -o translate/template.pot \
    $(find contents -name "*.qml" | sort)

for po in translate/*.po; do
    lang=$(basename "$po" .po)
    msgmerge --quiet --update --backup=none "$po" translate/template.pot
    mkdir -p "contents/locale/$lang/LC_MESSAGES"
    msgfmt --check -o "contents/locale/$lang/LC_MESSAGES/$DOMAIN.mo" "$po"
    echo "$lang: $(msgfmt --statistics -o /dev/null "$po" 2>&1)"
done
