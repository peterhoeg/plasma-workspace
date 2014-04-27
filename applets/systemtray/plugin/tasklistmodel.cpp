/*
 * <one line to give the library's name and an idea of what it does.>
 * Copyright (C) 2014  David Edmundson <david@davidedmundson.co.uk>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#include "tasklistmodel.h"

#include "task.h"

#include <QDebug>

using namespace SystemTray;

TaskListModel::TaskListModel(QObject *parent):
    QAbstractListModel(parent)
{
}

QVariant TaskListModel::data(const QModelIndex& index, int role) const
{
    if (role == Qt::UserRole && index.row() >=0 && index.row() < m_tasks.count()) {
        return QVariant::fromValue(m_tasks.at(index.row()));
    }
    return QVariant();
}

int TaskListModel::rowCount(const QModelIndex& parent) const
{
    return m_tasks.size();
}

QHash< int, QByteArray > SystemTray::TaskListModel::roleNames() const
{
    QHash<int, QByteArray> roleNames;
    roleNames.insert(Qt::UserRole, "modelData");
    return roleNames;
}

QList< Task* > TaskListModel::tasks() const
{
    return m_tasks;
}

void SystemTray::TaskListModel::addTask(Task* task)
{
    //TODO insert at the right place instead
    //qLowerBound()
    //get index as int
    //insert

    if (!m_tasks.contains(task)) {
        int index = m_tasks.size();
        beginInsertRows(QModelIndex(), index, index);
        m_tasks.append(task);
        endInsertRows();
        emit rowCountChanged();
    }
}

void SystemTray::TaskListModel::removeTask(Task* task)
{
    int index = m_tasks.indexOf(task);
    if (index >= 0 ) {
        beginRemoveRows(QModelIndex(), index, index);
        m_tasks.removeOne(task);
        endRemoveRows();
        emit rowCountChanged();
    }
}


#include "tasklistmodel.moc"
