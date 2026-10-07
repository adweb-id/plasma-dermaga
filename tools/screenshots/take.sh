#!/bin/sh
# Takes the README / KDE Store screenshots with demo data (see fake-docker).
# Installs a throw-away copy of the widget under its own ID, shows one scenario
# at a time with plasmawindowed, places the window on top with a KWin script
# (without giving it keyboard focus, so typing elsewhere is not disturbed),
# captures the screen with Spectacle and crops the window out with Python/PIL.
# Assumes a screen scale of 1. Output: docs/screenshots/*.png
#
#   sh tools/screenshots/take.sh            # all scenarios
#   sh tools/screenshots/take.sh menu       # just one
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$ROOT/docs/screenshots"
ID="com.adweb.dermaga.screenshots"
X=120   # where the window is placed while it is captured
Y=120
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT" "$WORK/bin"
ln -s "$HERE/fake-docker" "$WORK/bin/docker"

# name|fake docker mode|window caption|width|height|language
SCENARIOS='running|normal|Dermaga|440|600|en
stopped|normal|Dermaga|440|600|en
menu|normal|Dermaga|440|600|en
search|normal|Dermaga|440|420|en
confirm|normal|Dermaga|440|600|en
empty|empty|Dermaga|440|520|en
service-stopped|down|Dermaga|440|520|en
no-permission|noperm|Dermaga|440|520|en
about|normal|Dermaga|440|600|en
settings|normal|Dermaga Settings|760|680|en
running-id|normal|Dermaga|440|600|id'

shoot() {
    name=$1 mode=$2 caption=$3 w=$4 h=$5 lang=$6
    scenario=${name%-id}

    # Throw-away package: own ID, the driver added to main.qml
    rm -rf "$WORK/pkg" && cp -r "$ROOT" "$WORK/pkg" && rm -rf "$WORK/pkg/.git" "$WORK/pkg/docs" "$WORK/pkg/tools"
    sed -i "s/\"com.adweb.dermaga\"/\"$ID\"/" "$WORK/pkg/metadata.json"
    for mo in "$WORK"/pkg/contents/locale/*/LC_MESSAGES/*.mo; do
        [ -f "$mo" ] && mv "$mo" "$(dirname "$mo")/plasma_applet_$ID.mo"
    done
    sed "s/@SCENARIO@/$scenario/" "$HERE/ScreenshotDriver.qml" > "$WORK/pkg/contents/ui/ScreenshotDriver.qml"
    sed -i '$ d' "$WORK/pkg/contents/ui/main.qml"
    printf '\n    ScreenshotDriver { widget: root }\n}\n' >> "$WORK/pkg/contents/ui/main.qml"
    kpackagetool6 -t Plasma/Applet -r "$ID" >/dev/null 2>&1 || true
    kpackagetool6 -t Plasma/Applet -i "$WORK/pkg" >/dev/null 2>&1

    LANGUAGE=$lang FAKE_DOCKER_MODE=$mode PATH="$WORK/bin:$PATH" plasmawindowed "$ID" >/dev/null 2>&1 &
    pid=$!
    sleep 6

    # Borderless, on top, at a known place; never activated
    cat > "$WORK/place.js" <<JS
for (const w of workspace.windowList()) {
    if (w.caption === "$caption" && w.resourceClass.indexOf("plasmawindowed") !== -1) {
        w.noBorder = true;
        w.keepAbove = true;
        w.frameGeometry = { x: $X, y: $Y, width: $w, height: $h };
    }
}
JS
    sid=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$WORK/place.js" dermaga-shot)
    qdbus6 org.kde.KWin "/Scripting/Script$sid" org.kde.kwin.Script.run >/dev/null
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript dermaga-shot >/dev/null
    sleep 1.5
    spectacle -b -n -f -o "$WORK/screen.png" >/dev/null 2>&1
    python3 -c "from PIL import Image; Image.open('$WORK/screen.png').crop(($X, $Y, $X + $w, $Y + $h)).save('$OUT/$name.png')"
    rm -f "$WORK/screen.png"
    sleep 1
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    echo "$name.png"
}

printf '%s\n' "$SCENARIOS" | while IFS='|' read -r name mode caption w h lang; do
    if [ -z "$1" ] || [ "$1" = "$name" ]; then
        shoot "$name" "$mode" "$caption" "$w" "$h" "$lang"
    fi
done
kpackagetool6 -t Plasma/Applet -r "$ID" >/dev/null 2>&1 || true
