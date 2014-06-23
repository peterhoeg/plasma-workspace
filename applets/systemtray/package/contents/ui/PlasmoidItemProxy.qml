/***************************************************************************
 *   Copyright 2013 Sebastian Kügler <sebas@kde.org>                       *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Library General Public License as       *
 *   published by the Free Software Foundation; either version 2 of the    *
 *   License, or (at your option) any later version.                       *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU Library General Public License for more details.                  *
 *                                                                         *
 *   You should have received a copy of the GNU Library General Public     *
 *   License along with this program; if not, write to the                 *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick 2.0
import org.kde.private.systemtray 2.0 as SystemTray

/**
 * Only one instance of the plasmoid's representation can be created
 * We want to show the plasmoid both in the main taskbar as well as
 * in the left hand list of the system tray's expanded view.
 *
 * Instead we render everything once then proxy the final texture
 * This means we render the plasmoid as a single texture which is arguably better anyway,
 * but limits us to being the same size
 */

Item {
    id: plasmoidItem

    ShaderEffectSource {
        id: plasmoidProxy
        sourceItem: modelData.taskItem
    }

    Component.onCompleted: {
        console.log("DAVE" + modelData.taskItem.width, width, effect.width)
    }

    //future optimisation, we don't /need/ a shadereffect. ShaderEffectSource acts as a tetxureProvider, so we just need a simple class to display that texture
    //this can then share the same program
    ShaderEffect {
        id: effect
        width: modelData.taskItem.width
        height: modelData.taskItem.height
        property variant plasmoidTexture: plasmoidProxy

        //copy pixel for pixel with nothing fancy
        vertexShader: "
                uniform highp mat4 qt_Matrix;
                attribute highp vec4 qt_Vertex;
                attribute highp vec2 qt_MultiTexCoord0;
                varying highp vec2 coord;
                void main() {
                    coord = qt_MultiTexCoord0;
                    gl_Position = qt_Matrix * qt_Vertex;
                }"
        fragmentShader: "
            varying highp vec2 coord;
            uniform sampler2D plasmoidTexture;
            uniform lowp float qt_Opacity;
            void main() {
                lowp vec4 tex = texture2D(plasmoidTexture, coord);
                gl_FragColor = tex * qt_Opacity;
            }"
    }


    MouseArea {
        anchors {
            fill: parent
        }
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (mouse.button == Qt.LeftButton) {
                if (modelData.expanded) {
                    if (plasmoidItem.parent.parent.parent.objectName == "taskListDelegate") {
                        modelData.expanded = false;
                    } else {
                        plasmoid.expanded = false;
                    }
                } else {
                    modelData.expanded = true;
                }

            } else if (mouse.button == Qt.RightButton) {
                modelData.showMenu(mouse.x, mouse.y);
            }
        }
    }
}
