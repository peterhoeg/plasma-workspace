#!/bin/sh

if [  ${XDG_CONFIG_HOME} ]
then
  configDir=$XDG_CONFIG_HOME;
else
  configDir=${HOME}/.config; #this is the default, http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html
fi

if [ ! -a $configDir/QtProject/qtlogging.ini ]
then
    echo '*.debug=false' > $configDir/QtProject/qtlogging.ini
fi