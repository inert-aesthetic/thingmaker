/*
thingmaker - an app for making things with thinglib
Copyright (C) 2025 inert-aesthetic contact_i_a at tuta dot io

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
package;

import thinglib.property.core.CoreComponents.CoreComponent;

@:build(Macro.buildIconAbstract())
class Icon{
    public static function ForBaseType(type:CoreComponent, ?size:IconSize=LARGE):String{
        return switch (type??"") {
            case CoreComponent.EDGE: size==SMALL?Icon.one_to_one_16:Icon.one_to_one_20;
            case CoreComponent.NODE: size==SMALL?Icon.dot_16:Icon.dot_20;
            case CoreComponent.REGION: size==SMALL?Icon.widget_16:Icon.widget_20;
            case CoreComponent.GROUP: size==SMALL?Icon.group_objects_16:Icon.group_objects_20;
            case CoreComponent.PATH: size==SMALL?Icon.pivot_16:Icon.pivot_20;
            default: Icon.cube_16;
        }
    }
}

enum IconSize{
    SMALL;
    LARGE;
}