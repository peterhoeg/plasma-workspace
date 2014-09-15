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

#include "simpleshellcorona.h"
#include "simpleshellview.h"
#include <QDebug>
#include <QAction>

#include <KActionCollection>
#include <Plasma/Package>
#include <Plasma/PluginLoader>

SimpleShellCorona::SimpleShellCorona(QObject *parent)
    : Plasma::Corona(parent),
      m_view(0)
{
    Plasma::Package package = Plasma::PluginLoader::self()->loadPackage("Plasma/Shell");
    package.setPath("org.kde.plasma.mediacenter");
    setPackage(package);
    load();
}

QRect SimpleShellCorona::screenGeometry(int id) const
{
    Q_UNUSED(id);
    if(m_view) {
        return m_view->geometry();
    } else {
        return QRect();
    }
}

void SimpleShellCorona::load()
{
    loadLayout("plasma-org.kde.plasma.mediacenter-appletsrc");

    bool found = false;
    for (auto c : containments()) {
        if (c->containmentType() == Plasma::Types::DesktopContainment) {
            found = true;
            break;
        }
    }

    if (!found) {
        qDebug() << "Loading default layout";
        loadDefaultLayout();
        saveLayout("plasma-org.kde.plasma.mediacenter-appletsrc");
    }

    for (auto c : containments()) {
        qDebug() << "here we are!";
        if (c->containmentType() == Plasma::Types::DesktopContainment) {
            m_view = new SimpleShellView(this);
            QAction *removeAction = c->actions()->action("remove");
            if(removeAction) {
                removeAction->deleteLater();
            }
            setView(m_view);
            m_view->setContainment(c);
            m_view->show();
            break;
        }
    }
}

void SimpleShellCorona::setView(PlasmaQuick::View *view)
{
    m_view = view;
}


void SimpleShellCorona::loadDefaultLayout()
{
    createContainment("org.kde.desktopcontainment"); 
}

#include "simpleshellcorona.moc"
