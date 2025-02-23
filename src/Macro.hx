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

import haxe.macro.Expr.Access;
import haxe.macro.Context;
import sys.FileSystem;
using StringTools;
#if (macro||display)
class Macro{
    public static function buildIconAbstract(){
        var icons16 = FileSystem.readDirectory('res/icon/16px');
        var icons20 = FileSystem.readDirectory('res/icon/20px');
        var fields = Context.getBuildFields();
        for(i in icons16){
            var name = i.split(".")[0].replace('-', '_')+"_16";
            var path = 'icon/16px/${i}';
            fields.push({                       
                pos: Context.currentPos(),
                doc: null,
                name: name,
                kind: FVar(macro: String, macro $v{path}),
                access: [Access.APublic, Access.AStatic, Access.AInline]
            }); 
        }
        for(i in icons20){
            var name = i.split(".")[0].replace('-', '_')+"_20";
            var path = 'icon/20px/${i}';
            fields.push({                       
                pos: Context.currentPos(),
                doc: null,
                name: name,
                kind: FVar(macro: String, macro $v{path}),
                access: [Access.APublic, Access.AStatic, Access.AInline]
            }); 
        }
        return fields;
    }
}
#end