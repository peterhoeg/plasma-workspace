#!/bin/sh
#
#  NIXPKGS KDE STARTUP SCRIPT ( @PROJECT_VERSION@ )
#

if test "x$1" = x--failsafe; then
    KDE_FAILSAFE=1 # General failsafe flag
    KWIN_COMPOSE=N # Disable KWin's compositing
    QT_XCB_FORCE_SOFTWARE_OPENGL=1
    export KWIN_COMPOSE KDE_FAILSAFE QT_XCB_FORCE_SOFTWARE_OPENGL
fi

# When the X server dies we get a HUP signal from xinit. We must ignore it
# because we still need to do some cleanup.
trap 'echo GOT SIGHUP' HUP

# we have to unset this for Darwin since it will screw up KDE's dynamic-loading
unset DYLD_FORCE_FLAT_NAMESPACE

# Check if a KDE session already is running and whether it's possible to connect to X
@CMAKE_INSTALL_FULL_BINDIR@/kcheckrunning
kcheckrunning_result=$?
if [ $kcheckrunning_result -eq 0 ]; then
    echo "KDE seems to be already running on this display."
    exit 1
elif [ $kcheckrunning_result -eq 2 ]; then
    echo "\$DISPLAY is not set or cannot connect to the X server."
    exit 1
fi

# Boot sequence:
#
# kdeinit is used to fork off processes which improves memory usage
# and startup time.
#
# * kdeinit starts klauncher first.
# * Then kded is started. kded is responsible for keeping the sycoca
#   database up to date. When an up to date database is present it goes
#   into the background and the startup continues.
# * Then kdeinit starts kcminit. kcminit performs initialisation of
#   certain devices according to the user's settings
#
# * Then ksmserver is started which takes control of the rest of the startup sequence

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

# xdg-desktop-settings generates this empty file but
# it makes kbuildsyscoca5 fail silently. To fix this
# remove that menu if it exists.
rm -fv $HOME/.config/menus/applications-merged/xdg-desktop-menu-dummy.menu

# Remove the kbuildsyscoca5 cache. It will be regenerated immediately after.
# This is necessary for kbuildsyscoca5 to recognize that software that has been removed.
rm -fv $HOME/.cache/ksycoca*

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
sysConfigDirs=${XDG_CONFIG_DIRS:-/etc/xdg}

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
kdeglobals KScreen ScaleFactor ''
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
    echo "kstartupconfig5 does not exist or fails. The error code is $returncode. Check your installation." 1>&2
    exit 1
fi
if [ -r "$XDG_CONFIG_HOME/startupconfig" ]; then
    . "$XDG_CONFIG_HOME/startupconfig"
fi

#Do not sync any of this section with the wayland versions as there scale factors are
#sent properly over wl_output

if [ "$kdeglobals_kscreen_screenscalefactors" ]; then
    export QT_SCREEN_SCALE_FACTORS="$kdeglobals_kscreen_screenscalefactors"
    if [ "$kdeglobals_kscreen_scalefactor" -eq "2" ] || [ "$kdeglobals_kscreen_scalefactor" -eq "3" ]; then
        export GDK_SCALE=$kdeglobals_kscreen_scalefactor
        export GDK_DPI_SCALE=`awk "BEGIN {print 1/$kdeglobals_kscreen_scalefactor}"`
    fi
fi
#Manually disable auto scaling because we are scaling above
#otherwise apps that manually opt in for high DPI get auto scaled by the developer AND manually scaled by us
export QT_AUTO_SCREEN_SCALE_FACTOR=0

#Set the QtQuickControls style to our own: for QtQuickControls1
#it will fall back to Desktop, while it will use our own org.kde.desktop
#for QtQuickControlsStyle and Kirigami
export QT_QUICK_CONTROLS_STYLE=org.kde.desktop

XCURSOR_PATH=~/.icons
IFS=":" read -r -a xdgDirs <<< "$XDG_DATA_DIRS"
for xdgDir in "${xdgDirs[@]}"; do
    XCURSOR_PATH="$XCURSOR_PATH:$xdgDir/icons"
done
export XCURSOR_PATH

# XCursor mouse theme needs to be applied here to work even for kded or ksmserver
if test -n "$kcminputrc_mouse_cursortheme" -o -n "$kcminputrc_mouse_cursorsize" ; then
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

if [ "${kcmfonts_general_forcefontdpi:-0}" -ne 0 ]; then
    @NIXPKGS_XRDB@ -quiet -merge -nocpp <<EOF
Xft.dpi: $kcmfonts_general_forcefontdpi
EOF
fi

dl=$DESKTOP_LOCKED
unset DESKTOP_LOCKED # Don't want it in the environment

ksplash_pid=
if [ -z "$dl" ]; then
  # the splashscreen and progress indicator
  case "$ksplashrc_ksplash_engine" in
    KSplashQML)
      ksplash_pid=$(@CMAKE_INSTALL_FULL_BINDIR@/ksplashqml "${ksplashrc_ksplash_theme}" --pid)
      ;;
    None)
      ;;
    *)
      ;;
  esac
fi

# Set a left cursor instead of the standard X11 "X" cursor, since I've heard
# from some users that they're confused and don't know what to do. This is
# especially necessary on slow machines, where starting KDE takes one or two
# minutes until anything appears on the screen.
#
# If the user has overwritten fonts, the cursor font may be different now
# so don't move this up.
#
xsetroot -cursor_name left_ptr

# Get Ghostscript to look into user's KDE fonts dir for additional Fontmap
usr_fdir=$HOME/.fonts
if test -n "$GS_LIB" ; then
    GS_LIB=$usr_fdir:$GS_LIB
    export GS_LIB
else
    GS_LIB=$usr_fdir
    export GS_LIB
fi

echo 'startkde: Starting up...'  1>&2

# Make sure that the KDE prefix is first in XDG_DATA_DIRS and that it's set at all.
# The spec allows XDG_DATA_DIRS to be not set, but X session startup scripts tend
# to set it to a list of paths *not* including the KDE prefix if it's not /usr or
# /usr/local.
if test -z "$XDG_DATA_DIRS"; then
    XDG_DATA_DIRS="@KDE_INSTALL_FULL_DATAROOTDIR@:/usr/share:/usr/local/share"
fi
export XDG_DATA_DIRS

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
@NIXPKGS_XPROP@ -root -f KDE_FULL_SESSION 8t -set KDE_FULL_SESSION true

KDE_SESSION_VERSION=5
export KDE_SESSION_VERSION
@NIXPKGS_XPROP@ -root -f KDE_SESSION_VERSION 32c -set KDE_SESSION_VERSION 5

KDE_SESSION_UID=$(@NIXPKGS_ID@ -ru)
export KDE_SESSION_UID

XDG_CURRENT_DESKTOP=KDE
export XDG_CURRENT_DESKTOP

# Enforce xcb QPA. Helps switching between Wayland and X sessions.
export QT_QPA_PLATFORM=xcb

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
  exit 1
fi

# We set LD_BIND_NOW to increase the efficiency of kdeinit.
# kdeinit unsets this variable before loading applications.
LD_BIND_NOW=true @NIXPKGS_START_KDEINIT_WRAPPER@ --kded +kcminit_startup
if test $? -ne 0; then
  # Startup error
  echo 'startkde: Could not start kdeinit5. Check your installation.'  1>&2
  test -n "$ksplash_pid" && kill "$ksplash_pid" 2>/dev/null
  exit 1
fi

@NIXPKGS_QDBUS@ org.kde.KSplash /KSplash org.kde.KSplash.setStage kinit &

# finally, give the session control to the session manager
# see kdebase/ksmserver for the description of the rest of the startup sequence
# if the KDEWM environment variable has been set, then it will be used as KDE's
# window manager instead of kwin.
# if KDEWM is not set, ksmserver will ensure kwin is started.
# kwrapper5 is used to reduce startup time and memory usage
# kwrapper5 does not return useful error codes such as the exit code of ksmserver.
# We only check for 255 which means that the ksmserver process could not be
# started, any problems thereafter, e.g. ksmserver failing to initialize,
# will remain undetected.
if [ -n "$KDEWM" ]; then
    KDEWM="--windowmanager $KDEWM"
fi
# If the session should be locked from the start (locked autologin),
# lock now and do the rest of the KDE startup underneath the locker.
KSMSERVEROPTIONS=""
if [ -n "$dl" ]; then
    KSMSERVEROPTIONS=" --lockscreen"
fi
@NIXPKGS_KWRAPPER5@ @CMAKE_INSTALL_FULL_BINDIR@/ksmserver $KDEWM $KSMSERVEROPTIONS
if test $? -eq 255; then
  # Startup error
  echo 'startkde: Could not start ksmserver. Check your installation.'  1>&2
  test -n "$ksplash_pid" && kill "$ksplash_pid" 2>/dev/null
  xmessage -geometry 500x100 "Could not start ksmserver. Check your installation."
fi

#Anything after here is logout
#It is not called after shutdown/restart

wait_drkonqi=$(@NIXPKGS_KREADCONFIG5@ --file startkderc --group WaitForDrKonqi --key Enabled --default true)

if [ x"$wait_drkonqi"x = x"true"x ]; then
    # wait for remaining drkonqi instances with timeout (in seconds)
    wait_drkonqi_timeout=$(@NIXPKGS_KREADCONFIG5@ --file startkderc --group WaitForDrKonqi --key Timeout --default 900)
    wait_drkonqi_counter=0
    while @NIXPKGS_QDBUS@ | @NIXPKGS_GREP@ -q "^[^w]*org.kde.drkonqi" ; do
        sleep 5
        wait_drkonqi_counter=$((wait_drkonqi_counter+5))
        if [ "$wait_drkonqi_counter" -ge "$wait_drkonqi_timeout" ]; then
            # ask remaining drkonqis to die in a graceful way
            @NIXPKGS_QDBUS@ | @NIXPKGS_GREP@ 'org.kde.drkonqi-' | while read address ; do
                @NIXPKGS_QDBUS@ "$address" "/MainApplication" "quit"
        fi
    done
fi

echo 'startkde: Shutting down...'  1>&2
# just in case
if [ -n "$ksplash_pid" ]; then
    kill "$ksplash_pid" 2>/dev/null
fi

# Clean up
@NIXPKGS_KDEINIT5_SHUTDOWN@

unset KDE_FULL_SESSION
@NIXPKGS_XPROP@ -root -remove KDE_FULL_SESSION
unset KDE_SESSION_VERSION
@NIXPKGS_XPROP@ -root -remove KDE_SESSION_VERSION
unset KDE_SESSION_UID

echo 'startkde: Done.'  1>&2
