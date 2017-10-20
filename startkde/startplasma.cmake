#!/bin/sh
#
#  NIXPKGS Plasma STARTUP SCRIPT ( @PROJECT_VERSION@ )
#

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
if [ -r "$XDG_CONFIG_HOME/startupconfig" ]; then
    . "$XDG_CONFIG_HOME/startupconfig"
fi

if [ "$kcmfonts_general_forcefontdpi" -ne 0 ]; then
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

#In wayland we want Plasma to use Qt's scaling
export PLASMA_USE_QT_SCALING=1

# Set a left cursor instead of the standard X11 "X" cursor, since I've heard
# from some users that they're confused and don't know what to do. This is
# especially necessary on slow machines, where starting KDE takes one or two
# minutes until anything appears on the screen.
#
# If the user has overwritten fonts, the cursor font may be different now
# so don't move this up.
#
@NIXPKGS_XSETROOT@ -cursor_name left_ptr

echo 'startplasma: Starting up...'  1>&2

# export our session variables to the Xwayland server
@NIXPKGS_XPROP@ -root -f KDE_FULL_SESSION 8t -set KDE_FULL_SESSION true
@NIXPKGS_XPROP@ -root -f KDE_SESSION_VERSION 32c -set KDE_SESSION_VERSION 5

# We set LD_BIND_NOW to increase the efficiency of kdeinit.
# kdeinit unsets this variable before loading applications.
LD_BIND_NOW=true @NIXPKGS_START_KDEINIT_WRAPPER@ --kded +kcminit_startup
if test $? -ne 0; then
  # Startup error
  echo 'startplasma: Could not start kdeinit5. Check your installation.'  1>&2
  test -n "$ksplash_pid" && kill "$ksplash_pid" 2>/dev/null
  exit 1
fi

@NIXPKGS_QDBUS@ org.kde.KSplash /KSplash org.kde.KSplash.setStage kinit

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
# If the session should be locked from the start (locked autologin),
# lock now and do the rest of the KDE startup underneath the locker.
KSMSERVEROPTIONS=" --no-lockscreen"
@NIXPKGS_KWRAPPER5@ @CMAKE_INSTALL_FULL_BINDIR@/ksmserver $KDEWM $KSMSERVEROPTIONS
if test $? -eq 255; then
  # Startup error
  echo 'startplasma: Could not start ksmserver. Check your installation.'  1>&2
  test -n "$ksplash_pid" && kill "$ksplash_pid" 2>/dev/null
fi

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
            done
            break
        fi
    done
fi

echo 'startplasma: Shutting down...'  1>&2
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

echo 'startplasma: Done.'  1>&2
