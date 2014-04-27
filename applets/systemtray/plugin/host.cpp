/***************************************************************************
 *                                                                         *
 *   Copyright 2013 Sebastian Kügler <sebas@kde.org>                       *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/


#include "host.h"
#include "task.h"
#include "debug.h"
#include "protocol.h"

#include <klocalizedstring.h>

#include <Plasma/Package>
#include <Plasma/PluginLoader>

#include <QLoggingCategory>
#include <QQuickItem>
#include <QTimer>
#include <QVariant>

#include "protocols/plasmoid/plasmoidprotocol.h"
#include "protocols/dbussystemtray/dbussystemtrayprotocol.h"
#include "tasklistmodel.h"

#define TIMEOUT 100

namespace SystemTray
{

static QHash<Task::Category, int> s_taskWeights;

bool taskLessThan(const Task *lhs, const Task *rhs)
{
    /* Sorting of systemtray icons
     *
     * We sort (and thus group) in the following order, from high to low priority
     * - Notifications always comes first
     * - Category
     * - Name
     */

    const QLatin1String _not = QLatin1String("org.kde.plasma.notifications");
    if (lhs->taskId() == _not) {
        return true;
    }
    if (rhs->taskId() == _not) {
        return false;
    }

    if (lhs->category() != rhs->category()) {

        if (s_taskWeights.isEmpty()) {
            s_taskWeights.insert(Task::Communications, 0);
            s_taskWeights.insert(Task::SystemServices, 1);
            s_taskWeights.insert(Task::Hardware, 2);
            s_taskWeights.insert(Task::ApplicationStatus, 3);
            s_taskWeights.insert(Task::UnknownCategory, 4);
        }
        return s_taskWeights.value(lhs->category()) < s_taskWeights.value(rhs->category());
    }

    return lhs->name() < rhs->name();
}

class HostPrivate {
public:
    HostPrivate(Host *host)
        : q(host),
          rootItem(0),
          shownTasksModel(new TaskListModel(host)),
          hiddenTasksModel(new TaskListModel(host))
    {
    }
    void setupProtocol(Protocol *protocol);
    bool showTask(Task *task) const;

    Host *q;

    QList<Task *> tasks;
    QQuickItem* rootItem;

    // Keep references to the list to avoid full refreshes
    //QList<SystemTray::Task*> tasks;
//     QList<SystemTray::Task*> shownTasks;
//     QList<SystemTray::Task*> hiddenTasks;
    //all tasks that are in hidden categories
//     QList<SystemTray::Task*> discardedTasks;

    QSet<Task::Category> shownCategories;

    TaskListModel *shownTasksModel;
    TaskListModel *hiddenTasksModel;

    QStringList categories;
};

Host::Host(QObject* parent) :
    QObject(parent),
    d(new HostPrivate(this))
{
    QTimer::singleShot(0, this, SLOT(init()));
}

Host::~Host()
{
    delete d;
}

void Host::init()
{
    d->setupProtocol(new SystemTray::DBusSystemTrayProtocol(this));
    d->setupProtocol(new SystemTray::PlasmoidProtocol(this));

    initTasks();

    emit categoriesChanged();
}

void Host::initTasks()
{
    QList<SystemTray::Task*> allTasks = tasks();
    foreach (SystemTray::Task *task, allTasks) {
        if (d->showTask(task)) {
            d->shownTasksModel->addTask(task);
        } else {
            d->hiddenTasksModel->addTask(task);
        }
    }
}

QQuickItem* Host::rootItem()
{
    return d->rootItem;
}

void Host::setRootItem(QQuickItem* item)
{
    if (d->rootItem == item) {
        return;
    }

    d->rootItem = item;
    emit rootItemChanged();
}

bool Host::isCategoryShown(int cat) const
{
    return d->shownCategories.contains((Task::Category)cat);
}

void Host::setCategoryShown(int cat, bool shown)
{
    if (shown) {
        if (!d->shownCategories.contains((Task::Category)cat)) {
            d->shownCategories.insert((Task::Category)cat);
            foreach (Task *task, d->tasks) {
                if (d->shownCategories.contains(task->category())) {
                    addTask(task);
                }
            }
        }
    } else {
        if (d->shownCategories.contains((Task::Category)cat)) {
            d->shownCategories.remove((Task::Category)cat);
            foreach (Task *task, d->tasks) {
                if (!d->shownCategories.contains(task->category())) {
                    removeTask(task);
                }
            }
        }
    }
}

QList<Task*> Host::tasks() const
{
    return d->tasks;
}

void Host::addTask(Task *task)
{
    qDebug() << "DAVE *********** ADDING ITEM ";

    connect(task, SIGNAL(destroyed(SystemTray::Task*)), this, SLOT(removeTask(SystemTray::Task*)));
    connect(task, SIGNAL(changedStatus()), this, SLOT(slotTaskStatusChanged()));

    qCDebug(SYSTEMTRAY) << "ST2" << task->name() << "(" << task->taskId() << ")";

    d->tasks.append(task);
    if (d->showTask(task)) {
        d->shownTasksModel->addTask(task);
    } else {
        d->hiddenTasksModel->addTask(task);
    }
}

void Host::removeTask(Task *task)
{
    d->tasks.removeAll(task);
    disconnect(task, 0, this, 0);
    d->shownTasksModel->removeTask(task);
    d->hiddenTasksModel->removeTask(task);
}

void Host::slotTaskStatusChanged()
{
    Task* task = qobject_cast<Task*>(sender());

    if (task) {
        qCDebug(SYSTEMTRAY) << "ST2 emit taskStatusChanged(task);";
        taskStatusChanged(task);
    } else {
        qCDebug(SYSTEMTRAY) << "ST2 changed, but invalid cast";
    }
}

QAbstractItemModel* Host::hiddenTasks()
{
    return d->hiddenTasksModel;
}

QAbstractItemModel* Host::shownTasks()
{
    return d->shownTasksModel;

}

bool HostPrivate::showTask(Task *task) const {
    return task->shown() && task->status() != SystemTray::Task::Passive;
}

void HostPrivate::setupProtocol(Protocol *protocol)
{
    QObject::connect(protocol, SIGNAL(taskCreated(SystemTray::Task*)), q, SLOT(addTask(SystemTray::Task*)));
    protocol->init();
}

void Host::taskStatusChanged(SystemTray::Task *task)
{
    if (task) {
        if (!d->showTask(task)) {
            d->shownTasksModel->removeTask(task);
        } else {
            d->hiddenTasksModel->addTask(task);
        }
    }
}

QStringList Host::categories() const
{
    QList<SystemTray::Task*> allTasks = tasks();
    QStringList cats;
    QList<SystemTray::Task::Category> cnt;
    foreach (SystemTray::Task *task, allTasks) {
        const SystemTray::Task::Category c = task->category();
        if (cnt.contains(c)) {
            continue;
        }
        cnt.append(c);

        if (c == SystemTray::Task::UnknownCategory) {
            cats.append(i18n("Unknown Category"));
        } else if (c == SystemTray::Task::ApplicationStatus) {
            cats.append(i18n("Application Status"));
        } else if (c == SystemTray::Task::Communications) {
            cats.append(i18n("Communications"));
        } else if (c == SystemTray::Task::SystemServices) {
            cats.append(i18n("System Services"));
        } else if (c == SystemTray::Task::Hardware) {
            cats.append(i18n("Hardware"));
        }
    }
    qCDebug(SYSTEMTRAY) << "ST2 " << cats;
    return cats;
}


} // namespace

#include "host.moc"
