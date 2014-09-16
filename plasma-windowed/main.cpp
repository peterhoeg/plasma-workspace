/*
 * Copyright 2014  Bhushan Shah <bhush94@gmail.com>
 * Copyright 2014 Marco Martin <notmart@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License or (at your option) version 3 or any later version
 * accepted by the membership of KDE e.V. (or its successor approved
 * by the membership of KDE e.V.), which shall act as a proxy
 * defined in Section 14 of version 3 of the license.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

#include <QApplication>
#include <qcommandlineparser.h>
#include <qcommandlineoption.h>
#include <QDebug>

#include <KDBusService>
#include <KLocalizedString>

#include "plasmawindowedview.h"
#include "plasmawindowedcorona.h"
#include "simpleshellcorona.h"

static const char version[] = "1.0";

int main(int argc, char **argv)
{
    QQuickWindow::setDefaultAlphaBuffer(true);

    QApplication app(argc, argv);
    app.setApplicationVersion(version);
    app.setOrganizationDomain(QStringLiteral("kde.org"));

    

    QCommandLineParser parser;
    parser.setApplicationDescription(i18n("Plasma Windowed"));
    parser.addVersionOption();
    parser.addHelpOption();
    parser.addPositionalArgument("applet", i18n("The applet to open."));

    QCommandLineOption shellPluginOption(QStringList() << QStringLiteral("p") << QStringLiteral("shell-plugin"),
                                         i18n("Force loading the given shell plugin"),
                                         QStringLiteral("plugin"));
    parser.addOption(shellPluginOption);
    parser.process(app);

    const QString shellCorona = parser.value(shellPluginOption);

    if (parser.positionalArguments().isEmpty() && shellCorona.isEmpty()) {
        parser.showHelp(1);
    }

    Plasma::Theme theme;
    theme.setUseGlobalSettings(false);


    //Single applet mode
    if (shellCorona.isEmpty()) {
        app.setApplicationName("plasmawindowed");
        KDBusService service(KDBusService::Unique);
        PlasmaWindowedCorona *corona = new PlasmaWindowedCorona();
        QObject::connect(&service, &KDBusService::activateRequested, corona, &PlasmaWindowedCorona::activateRequested);

        QVariantList args;
        QStringList::const_iterator constIterator;
        constIterator = parser.positionalArguments().constBegin();
        ++constIterator;
        for (; constIterator != parser.positionalArguments().constEnd();
            ++constIterator) {
            args << (*constIterator);
        }
        corona->loadApplet(parser.positionalArguments().first(), args);

        const int ret = app.exec();
        delete corona;
        return ret;

    //Shell package mode
    } else {
        app.setApplicationName("plasmawindowed_" + shellCorona);
        KDBusService service(KDBusService::Unique);

        SimpleShellCorona *corona = new SimpleShellCorona(shellCorona);
        const int ret = app.exec();
        delete corona;
        return ret;
    }
}
