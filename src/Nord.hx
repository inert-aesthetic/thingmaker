/*
MIT License (MIT)

Copyright (c) 2016-present Sven Greb <development@svengreb.de> (https://www.svengreb.de)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
package;

class Nord{
    /**
     * 00 Black - Base component color of "Polar ".
     * Used for texts, backgrounds, carets and structuring characters like curly- and square brackets.
     */
    public static inline var dark1:Int = 0x2e3440;

    /***
     * 
     * 01 Dark grey - Lighter shade color of the base component color.
     * Used as a lighter background color for UI elements like status bars.
     */
    public static inline var dark2:Int = 0x3b4252;

    /**
     * 02 Lighter grey - Lighter shade color of the base component color.
     * Used as line highlighting in the editor.
     * In the UI scope it may be used as selection- and highlight color.
     */
    public static inline var dark3:Int = 0x434c5e;

    /**
     * 03 Light grey - Lighter shade color of the base component color.
     * Used for comments, invisibles, indent- and wrap guide marker.
     * In the UI scope used as pseudoclass color for disabled elements.
     */
    public static inline var dark4:Int = 0x4c566a;

    /**
     * 04 Dim White - Base component color of "Snow Storm".
     * Main color for text, variables, constants and attributes.
     * In the UI scope used as semi-light background depending on the theme shading design.
     */
    public static inline var light1:Int = 0xd8dee9;

    /**
     * 05 Light white - Lighter shade color of the base component color.
     * Used as a lighter background color for UI elements like status bars.
     * Used as semi-light background depending on the theme shading design.
     */
    public static inline var light2:Int = 0xe5e9f0;

    /**
     * 06 Bright white - Lighter shade color of the base component color.
     * Used for punctuations, carets and structuring characters like curly- and square brackets.
     * In the UI scope used as background, selection- and highlight color depending on the theme shading design.
     */
    public static inline var light3:Int = 0xeceff4;

    /**
     * 07 Greeny blue - Bluish core color.
     * Used for classes, types and documentation tags.
     */
    public static inline var blue1:Int = 0x8fbcbb;

    /**
     * 08 Aqua-ish blue - Bluish core accent color.
     * Represents the accent color of the color palette.
     * Main color for primary UI elements and methods/functions.
     * Can be used for
     * - Markup quotes
     * - Markup link URLs
     */
    public static inline var blue2:Int = 0x88c0d0;

    /**
     * 09 Faded blue - Bluish core color.
     * Used for language-specific syntactic/reserved support characters and keywords, operators, tags, units and
     * punctuations like (semi)colons,commas and braces.
     */
    public static inline var blue3:Int = 0x81a1c1;

    /**
     * 10 Stronger faded blue - Bluish core color.
     * Used for markup doctypes, import/include/require statements, pre-processor statements and at-rules (`@`).
     */
    public static inline var blue4:Int = 0x5e81ac;

    /**
     * 11 Red - Colorful component color.
     * Used for errors, git/diff deletion and linter marker.
     * Markup:
     */
    public static inline var red:Int = 0xbf616a;

    /**
     * 12 Orange - Colorful component color.
     * Used for annotations.
     */
    public static inline var orange:Int = 0xd08770;

    /**
     * 13 Yellow - Colorful component color.
     * Used for escape characters, regular expressions and markup entities.
     * In the UI scope used for warnings and git/diff renamings.
     */
    public static inline var yellow:Int = 0xebcb8b;

    /**
     * 14 Green - Colorful component color.
     * Main color for strings and attribute values.
     * In the UI scope used for git/diff additions and success visualizations.
     */
    public static inline var green:Int = 0xa3be8c;

    /**
     * 15 Pink - Colorful component color.
     * Used for numbers.
     */
    public static inline var pink:Int = 0xb48ead;
}