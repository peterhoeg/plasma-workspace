#!/bin/sh
#
#  NIXPKGS Plasma STARTUP SCRIPT ( @PROJECT_VERSION@ )
#

# we have to unset this for Darwin since it will screw up KDE's dynamic-loading
unset DYLD_FORCE_FLAT_NAMESPACE

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
@NIXPKGS_MKDIR@ -p "$XDG_CONFIG_HOME"

# The KDE icon cache is supposed to update itself
# automatically, but it uses the timestamp on the icon
# theme directory as a trigger.  Since in Nix the
# timestamp is always the same, this doesn't work.  So as
# a workaround, nuke the icon cache on login.  This isn't
# perfect, since it may require logging out after
# installing new applications to update the cache.
# See http://lists-archives.org/kde-devel/26175-what-when-will-icon-cache-refresh.html
rm -fv $HOME/.cache/icon-cache.kcache

# Qt writes a weird ‘libraryPath’ line to
# ~/.config/Trolltech.conf that causes the KDE plugin
# paths of previous KDE invocations to be searched.
# Obviously using mismatching KDE libraries is potentially
# disastrous, so here we nuke references to the Nix store
# in Trolltech.conf.  A better solution would be to stop
# Qt from doing this wackiness in the first place.
if [ -e $XDG_CONFIG_HOME/Trolltech.conf ]; then
    @NIXPKGS_SED@ -e '/nix\\store\|nix\/store/ d' -i $XDG_CONFIG_HOME/Trolltech.conf
fi

@NIXPKGS_KBUILDSYCOCA5@

# Set the default GTK 2 theme
gtkrc2="$HOME/.gtkrc-2.0"
breeze_gtkrc2="/run/current-system/sw/share/themes/Breeze/gtk-2.0/gtkrc"
if ! [ -e "$gtkrc2" ] && [ -e "$breeze_gtkrc2" ]; then
    cat >"$gtkrc2" <<EOF
# Default GTK+ 2 config for NixOS KDE 5
include "$breeze_gtkrc2"
style "user-font"
{
  font_name="Sans Serif Regular"
}
widget_class "*" style "user-font"
gtk-font-name="Sans Serif Regular 10"
gtk-theme-name="Breeze"
gtk-icon-theme-name="breeze"
gtk-fallback-icon-theme="hicolor"
gtk-cursor-theme-name="breeze_cursors"
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-menu-images=1
gtk-button-images=1
EOF
fi

# Set the default GTK 3 theme
gtk3_settings="$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
breeze_gtk3="/run/current-system/sw/share/themes/Breeze/gtk-3.0"
if ! [ -e "$gtk3_settings" ] && [ -e "$breeze_gtk" ]; then
    mkdir -p $(dirname "$gtk3_settings")
    cat >"$gtk3_settings" <<EOF
[Settings]
gtk-font-name=Sans Serif Regular 10
gtk-theme-name=Breeze
gtk-icon-theme-name=breeze
gtk-fallback-icon-theme=hicolor
gtk-cursor-theme-name=breeze_cursors
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-menu-images=1
gtk-button-images=1
EOF
fi

kcminputrc="$XDG_CONFIG_HOME/kcminputrc"
if ! [ -e "$kcminputrc" ]; then
    cat >"$kcminputrc" <<EOF
[Mouse]
cursorTheme=breeze_cursors
cursorSize=0
EOF
fi

#This is basically setting defaults so we can use them with kstartupconfig5
cat >"$XDG_CONFIG_HOME/startupconfigkeys" <<EOF
kcminputrc Mouse cursorTheme 'breeze_cursors'
kcminputrc Mouse cursorSize ''
ksplashrc KSplash Theme org.kde.breeze.desktop
ksplashrc KSplash Engine KSplashQML
kdeglobals KScreen ScreenScaleFactors ''
kcmfonts General forceFontDPI 0
kcmfonts General dontChangeAASettings true
EOF

# preload the user's locale on first start
plasmalocalerc="$XDG_CONFIG_HOME/plasma-localerc"
if ! [ -f "$plasmalocalerc" ]; then
    cat >"$plasmalocalerc" <<EOF
[Formats]
LANG=$LANG
EOF
fi

# export LC_* variables set by kcmshell5 formats into environment
# so it can be picked up by QLocale and friends.
exportformatssettings="$XDG_CONFIG_HOME/plasma-locale-settings.sh"
if [ -r "$exportformatssettings" ]; then
    . "$exportformatssettings"
fi

# Write a default kdeglobals file to set up the font
kdeglobalsfile="$XDG_CONFIG_HOME/kdeglobals"
if ! [ -f "$kdeglobalsfile" ]; then
    cat >"$kdeglobalsfile" <<EOF
[General]
fixed=Monospace,10,-1,5,50,0,0,0,0,0,Regular
font=Sans Serif,10,-1,5,50,0,0,0,0,0,Regular
menuFont=Sans Serif,10,-1,5,50,0,0,0,0,0,Regular
smallestReadableFont=Sans Serif,8,-1,5,50,0,0,0,0,0,Regular
toolBarFont=Sans Serif,8,-1,5,50,0,0,0,0,0,Regular

[WM]
activeFont=Noto Sans,12,-1,5,50,0,0,0,0,0,Bold
EOF
fi

if ! @CMAKE_INSTALL_FULL_BINDIR@/kstartupconfig5; then
    exit 1
fi
if [ -r "$XDG_CONFIG_HOME/startupconfig" ]; then
    . "$XDG_CONFIG_HOME/startupconfig"
fi

#Manually disable auto scaling because we are scaling above
#otherwise apps that manually opt in for high DPI get auto scaled by the developer AND scaled by the wl_output
export QT_AUTO_SCREEN_SCALE_FACTOR=0

XCURSOR_PATH=~/.icons
IFS=":" read -r -a xdgDirs <<< "$XDG_DATA_DIRS"
for xdgDir in "${xdgDirs[@]}"; do
    XCURSOR_PATH="$XCURSOR_PATH:$xdgDir/icons"
done
export XCURSOR_PATH

# XCursor mouse theme needs to be applied here to work even for kded or ksmserver
if [ -n "$kcminputrc_mouse_cursortheme" -o -n "$kcminputrc_mouse_cursorsize" ]; then
    kapplymousetheme "$kcminputrc_mouse_cursortheme" "$kcminputrc_mouse_cursorsize"
    if [ $? -eq 10 ]; then
        export XCURSOR_THEME=breeze_cursors
    elif [ -n "$kcminputrc_mouse_cursortheme" ]; then
        export XCURSOR_THEME="$kcminputrc_mouse_cursortheme"
    fi
    if [ -n "$kcminputrc_mouse_cursorsize" ]; then
        export XCURSOR_SIZE="$kcminputrc_mouse_cursorsize"
    fi
fi

if [ "${kcmfonts_general_forcefontdpiwayland:-0}" -ne 0 ]; then
    export QT_WAYLAND_FORCE_DPI=$kcmfonts_general_forcefontdpiwayland
else
    export QT_WAYLAND_FORCE_DPI=96
fi

echo 'startplasmacompositor: Starting up...'  1>&2

# Make sure that D-Bus is running
if ! @NIXPKGS_QDBUS@ >/dev/null 2>/dev/null; then
    echo 'startplasmacompositor: Could not start D-Bus. Can you call qdbus?'  1>&2
    test -n "$ksplash_pid" && kill "$ksplash_pid" 2>/dev/null
    exit 1
fi


# Mark that full KDE session is running (e.g. Konqueror preloading works only
# with full KDE running). The KDE_FULL_SESSION property can be detected by
# any X client connected to the same X session, even if not launched
# directly from the KDE session but e.g. using "ssh -X", kdesu. $KDE_FULL_SESSION
# however guarantees that the application is launched in the same environment
# like the KDE session and that e.g. KDE utilities/libraries are available.
# KDE_FULL_SESSION property is also only available since KDE 3.5.5.
# The matching tests are:
#   For $KDE_FULL_SESSION:
#     if test -n "$KDE_FULL_SESSION"; then ... whatever
#   For KDE_FULL_SESSION property:
#     xprop -root | grep "^KDE_FULL_SESSION" >/dev/null 2>/dev/null
#     if test $? -eq 0; then ... whatever
#
# Additionally there is (since KDE 3.5.7) $KDE_SESSION_UID with the uid
# of the user running the KDE session. It should be rarely needed (e.g.
# after sudo to prevent desktop-wide functionality in the new user's kded).
#
# Since KDE4 there is also KDE_SESSION_VERSION, containing the major version number.
# Note that this didn't exist in KDE3, which can be detected by its absense and
# the presence of KDE_FULL_SESSION.
#
KDE_FULL_SESSION=true
export KDE_FULL_SESSION

KDE_SESSION_VERSION=5
export KDE_SESSION_VERSION

KDE_SESSION_UID=$(@NIXPKGS_ID@ -ru)
export KDE_SESSION_UID

XDG_CURRENT_DESKTOP=KDE
export XDG_CURRENT_DESKTOP

#enforce wayland QPA
QT_QPA_PLATFORM=wayland
export QT_QPA_PLATFORM

# Source scripts found in <config locations>/plasma-workspace/env/*.sh
# (where <config locations> correspond to the system and user's configuration
# directories, as identified by Qt's qtpaths,  e.g.  $HOME/.config
# and /etc/xdg/ on Linux)
#
# This is where you can define environment variables that will be available to
# all KDE programs, so this is where you can run agents using e.g. eval `ssh-agent`
# or eval `gpg-agent --daemon`.
# Note: if you do that, you should also put "ssh-agent -k" as a shutdown script
#
# (see end of this file).
# For anything else (that doesn't set env vars, or that needs a window manager),
# better use the Autostart folder.

IFS=":" read -r -a scriptpath <<< $(@NIXPKGS_QTPATHS@ --paths GenericConfigLocation)
# Add /env/ to the directory to locate the scripts to be sourced
for prefix in "${scriptpath[@]}"; do
    for file in "$prefix"/plasma-workspace/env/*.sh; do
        if [ -r "$file" ]; then
            . "$file"
        fi
    done
done

# At this point all environment variables are set, let's send it to the DBus session server to update the activation environment
if ! @NIXPKGS_DBUS_UPDATE_ACTIVATION_ENVIRONMENT@ --systemd --all; then
    # Startup error
    echo 'startkde: Could not sync environment to dbus.'  1>&2
    test -n "$ksplash_pid" && kill "$ksplash_pid" 2>/dev/null
    echo 'startplasmacompositor: Could not sync environment to dbus.'  1>&2
    exit 1
fi

@KWIN_WAYLAND_BIN_PATH@ --xwayland --libinput --exit-with-session=@NIXPKGS_STARTPLASMA@

echo 'startplasmacompositor: Shutting down...'  1>&2

unset KDE_FULL_SESSION
@NIXPKGS_XPROP@ -root -remove KDE_FULL_SESSION
unset KDE_SESSION_VERSION
@NIXPKGS_XPROP@ -root -remove KDE_SESSION_VERSION
unset KDE_SESSION_UID

echo 'startplasmacompositor: Done.'  1>&2
