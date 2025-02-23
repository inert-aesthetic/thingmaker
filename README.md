# thingmaker

An app for making things.

Breaking changes with no changelog.

## building
Requires pasta-physic and thinglib.
```
haxelib git pasta-physic https://github.com/inert-aesthetic/pasta-physic.git
haxelib git pasta-physic https://github.com/inert-aesthetic/thinglib.git
```

You *must* use git version of haxeui-core and haxeui-heaps.

*Only* tested on Ubuntu Linux.  
*Only* tested with Haxe nightlies, git latest Hashlink, git latest Heaps, git latest haxeui-core, git latest haxeui-heaps.

To build for Linux, `inkscape` must be available from cli.  
Then, edit Heaps `hxd/fs/Convert.hx` L525 to disable this line:
```haxe
static var _ = Convert.register(new ConvertSVGToMSDF("svg", "png")); //comment out this line
```

## spirit of license
thingmaker is licensed gpl3.  

The intent is this:
 - You can use thinglib and pasta-physic in your closed-source commercial project
 - You can use output (.construct.json, macro codegen etc) from thingmaker and thinglib in your closed-source commercial project
 - You can modify thinglib and pasta-physic how you want and do not have to share or open source the changes
 - Where only output (.construct.json, codegen etc) is used in the release, even license attribution is not required
 - Data saved/output from thingmaker does *not* imply GPL license applies to projects it is used in!

 but

 - If you make changes/fork the thingmaker app itself, you must open source those changes and make them available with any binaries you make available

 in short, the thingmaker app license is viral but the backend library licenses, and the license for the app's output are not.

 if you think it doesn't work like this, we should talk and find out how to make it work like this.

## acknowledgement
Nord color scheme used under MIT license, see ./src/Nord.hx file header for details.
Visit https://github.com/nordtheme/nord to get sourcecode.
Haxe file version created for this project from CSS files found above.

Blueprint icons used under Apache2.0, see ./res/icon/LICENSE and ./res/icon/NOTICE for license and details.  
Visit https://github.com/palantir/blueprint/ to get sourcecode.