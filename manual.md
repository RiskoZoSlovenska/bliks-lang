# Blicks

TODO: Update this

## Welcome
Welcome to the Bliks manual, the completely guide to the Bliks programming language. Bliks is a tiny language created to be used within a game, written in Lua. As such, it compiles to Lua values (tables, etc) and is then run by a Lua script. It's based off of YewScript, a somewhat similar (but unfortunately not very good) programming language for a very similar game.


## Syntax
A Bliks program is composed of multiple lines, where each like is either empty (composed of only whitespace), contains only a comment or contains precisely one `instruction`. Whitespace is insignificant, meaning that indenting various parts of code is allowed (and recommended). A Bliks program is executed line-by-line sequentially from top to bottom, barring jumps of course.

An `instruction` has the syntax of `keyword args`, where `keyword` is a function name and `args` is a white-space separated list of `value`s.

A `value` is either an `identifier`, a `literal`, a `retrieval` or a `back retrieval`.


## Types
In Bliks, every piece of data is either an identifier, a string, a number or nil.

### Identifiers
An `identifier`, more commonly called a "name", is a sequence of characters identifying a macro or a label, depending on context. It must be composed of the characters `A`-`Z`, `a`-`z`, `0`-`9` or `_`, and may not start with a digit. Additionally, it may not be the word `nil` (the only reserved name in Bliks).

Passing an identifier to a function which doesn't explicitly expect an identifier will assume the identifier is a macro and attempt to expand it. Undefined macros do not expand to nil and throw an error.

### Strings
A string is a sequence of arbitrary characters. String literals are denoted of matching pairs of the double-quote character (`"`); the literal contains the characters between the two quotes. To use the `"` symbol inside a string, see [Escapes](#escapes). Examples of valid string literals are `"Hello World!"`, `"&q"`, while examples of invalid string literals are `"Hello`, `World"` or `"\""`.

### NUmbers
Number literals follow the usual convention. They are composed of a sequence of digits, optionally prefixed with a sign (`+` or `-`) and contain up to one decimal point (`.`) between digits. Additionally, they may contain an exponent suffix consisting of either `e` or `E`, followed by an optional a sign and then a sequence of digits. Examples of valid number literals are `32`, `-32.432`, `+32.00`, `1e3`, `1.2e-3` while invalid example are `.421`, `-.231`, `2e1.2`, `3.e2`, `3ee2` or `+32.00.2`.

Numbers always coerce into strings, but never the other way around.

### Nil
A value indicating the presence of a more meaningful value. The literal is the word `nil`.


## Type notation
Below follows a set of names for specific interpretations of values. These are used to notate the input and output types of functions.

`any` - either a `string`, `number` or a `nil`
`string` - either a `string` or a `number`
`nil` - the `nil` value
`identifier` - an identifier
`number` - a `number`
`pointer` - an integer `number` greater than 0
`table` - a `string` representing a list of other `strings`, separated by the `;` character



## Retrievals
Bliks does not have variables which can be created at will to store data. Instead, data is stored in registers, which numbered from 1 to *n*. To access the value stored in a register, one uses a `retrieval` (or a `back retrieval` - see below). To change the value in a register, some form of function must be used.

The syntax of a retrieval is the `@` symbol followed directly by a number `literal`, a macro `identifier` or another `retrieval` (in any case, the value must resolve to a `pointer` value) indicating the number of the register to get the value from. For example, `@3` retrieves the value found in register `3`, and `@@2` first retrieves value *x* from register `2` and then retrieves the value in register *x*.


## Back Retrievals
Most functions in Bliks produce some sort of output. They return it to the main program by setting the value of a register, and thus their first argument is almost always which register to put the result into. However, in many cases, one may want to use the same register as both the output and the input, which results in a fair amount of extra writing.

To solve this, one can use a `back retrieval`, which is represented by the symbol `<`. The director behaves similarly to a `retrieval`, except that it uses the the first value in the values list it belongs to as the number of the register to get the value from. In other words, `funcname x <` is identical to `funcname x @x`. Because of this, it cannot appear as the first value in a list of values.


## Labels
To facilitate writing loops, conditionals and other fun things, Bliks has `label`s and many different ways to jump from one place to a `label`. Once a line has been labelled (see [Label Function](#label-function]), it can be jumped to using [Flow Functions](#flow-functions).


# Comments
Comments in Bliks start with the `#` character (unless it is inside a string literal) and run to the end of the line.


# Conditionals
While conditions are handled by functions, the convention is that `nil` and the number `0` are falsy and any other value is truthy.


