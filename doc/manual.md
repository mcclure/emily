This is a reference for the Emily programming language. It lists all features but does not attempt to explain usage or concepts. If you want something that explains concepts, read [intro.md](intro.md).

Non-language-lawyers will likely want to skip to the "Syntax: Operator Precedence" section and read from there

[TOC]

# Execution model

## Premise

Emily is based on what I'm calling "c-expressions", for "curried expression"; this is a minimal way of writing code, modeled after the way prefix functions are executed in an ML language.

All values in Emily are modeled as unary functions-- in other words, a function which takes one argument and returns one argument. Because some of these values don't "behave" like functions once they've received that argument, this might be a little misleading; a better way to look at it may be that everything in Emily can be "applied", which means taking one value in and passing one value out. The way you apply two values together in code is to simply write them one after the other. If you write:

    a b

You are "applying" a to b. This expression evaluates to a value, which is the result giving b as an argument to a.

All expressions evaluate to values, which means expressions can be chained. If you write:

	3 .plus 4

You will apply "3" to its argument ".plus". This will return a function that takes a number as argument and returns that integer plus 3. This function then is applied to its argument 4, returning the number 7.

Some functions cannot accept some categories of arguments. For example, a number like 3 can only take atoms (field names) such as `.plus` or `.minus` as arguments. If you write the expression `3 4` in code, at evaluation time 3 will attempt to take 4 as an argument, the evaluation will fail and the program will halt.

The special paired characters `( )`, `{ }` and `[ ]` in an expression create a "group" containing all tokens in between. In

    1 .plus (2 .plus 3)

The value `1 .plus` is being applied to the value `(2 .plus 3)`.

In code samples or examples below, you may see things that look like "operators" as you know them from other languages, things like `=` or `+`. These are technically fake. Before a c-expression is interpreted, a set of "macros" are applied which remove all symbols. Each macro rewrites a valid c-expression containing a symbol to a valid c-expression without that symbol. Macros exist so that things like order of operations, or syntax "binding" to nearby tokens, can happen while still preserving the idea that at core everything is application of arguments on unary functions. The user generally should not have to think about this fine distinction, but should be aware that (1) any expression in Emily **could** be written as nothing but values and grouping parenthesis, and (2) any operator (such as `+`) that works with a builtin **could** also work with a user-defined object that responds to the corresponding atom (for `+` this is `.plus`).

The c-expressions are homoiconic for the AST in the current Emily interpreter, if that means anything to you.

## Values

Right now, the following kinds of runtime values exist in Emily:

- `null`
- `true`
- Numbers
- Strings
- Atoms
- User closures
- User objects

In addition, there are builtin closures, "scope objects", and continuations (`return`); however, these are within the interpreter and a user cannot create these (except implicitly).

"Atoms" require explanation. These are strings, but are unequal to their string counterparts: `"add" != .add`. They are used for field names in objects; if an object responds to the string value `"add"`, it would be undesirable for this to possibly get confused with `.add` as invoked by the `+` operator.

"Numbers" are double-precision floats.

Remember: these different kinds of values only differ in terms of which arguments they will accept (without failing) when applied as functions.

## Token types

An Emily program is a series of statements ("lines of code" separated by ; or newline). A statement in an Emily program is a series of "token"s. In a written program on disk, the following kinds of tokens exist:

- Words: An identifier-- any ASCII letter a-z A-Z, followed by any sequence of ASCII letters a-z A-Z and numbers 0-9. Underscore is not allowed.)
- Numbers: Any numbers 0-9, optionally followed by one period and more numbers 0-9.
- Strings: Open and close quotes " " and everything between them. Within the quotes, the escape characters `\n`, `\\`, and `\"` will be recognized.
- Unscoped groups: `(` ... `)`
- Scoped groups: `{` ... `}`
- Object-literal groups: `[` ... `]`
- Symbols: (Any unicode character other than whitespace, or one of the characters #()[]{}\;" )

Strings and groups may contain newlines within them.

After macro processing, all Symbols will be eliminated and two new types of tokens (created by macros) will appear in the processed statement which is executed. These are Atom tokens and Closure tokens. If there are any Symbols left by the time the macro processor is done, this is a failure and the program will terminate without running.

## Scopes

Each statement is executed in context of a "scope". This is an invisible, inaccessible object that the interpreter knows about. Any word token, at evaluation time, will be converted to a atom token and the scope object will be applied to it. In other words, the expression

	a

By itself, is a field lookup on the scope object.

Inside of a group or a closure, the scope may be different from that of the surrounding code. The scope will not change over the course of an executed statement (although the contents of the scope may change).

## Sequencing

All Emily values are functions; this means they map one value to one value, and evaluating the map may optionally have a side effect. The order evaluations (and thus, potentially, side effects) occur in is precise.

Consider a program as a list of statements. Statements are separated by semicolons or newlines. The statements are executed one after the other.

Consider a statement as a list of tokens. Execution works like this:
1. The token at the start of the list is popped off, evaluated, and becomes Value 1.
2. If there are no more tokens, Value 1 is the value of the statement.
3. If there are more tokens, the token at the start of the list is popped off, evaluated, and becomes Value 2.
4. Value 1 is applied to Value 2 as a function; the result becomes the new Value 1.
5. Return to step 2 and repeat.

An "empty" statement (i.e., two semicolons or two newlines with only whitespace between them) is ignored by the interpreter.

"Evaluating" a token means:
1. For a word token: Lookup on current scope object (see section on scopes above).
2. For a group token: All statements in the group are immediately executed in order. The value the group token evaluates to depends on the type of group (see below).
3. For a closure token: A new closure value is created, bound to the current scope object (see section on closures below). The evaluation will not have side-effects.
4. For any other kind of token: The token becomes a value in "the obvious way" (The token 3 becomes the number 3, etc). The evaluation will not have side-effects.

# Syntax

## Order of evaluation

This is only important to know if you are writing macros (not possible in Emily 0.1). If you are writing code, you probably actually want the "operator precedence" table in the section below.

In the table below, operators higher in the table are "evaluated" first. If a symbol is LTR, symbols of that phase to the left are evaluated before symbols of that phase to the right.

Phase   | Order | Symbol
--------|-------|----------
Reader  | LTR   | \
	    |       | \version
	    |       | #
	    |       | ;
	    |       | ( )
	    |       | [ ]
	    |       | { }
	    |       | " "
110     | LTR   | .
105     | LTR   | =
100     | LTR   | ^
        |       | ^!
90      | LTR   | ?
        |       | :
75      | RTL   | ||
70      | RTL   | &&
65      | RTL   | !=
        |       | ==
60      | RTL   | >=
        |       | >
        |       | <=
        |       | <
50      | RTL   | +
	    |       | -
40      | RTL   | *
        |       | /
30      | RTL   | ~
        | RTL   | !
20      | RTL   | `

(This table can be different from conventional "precedence" because all the macros do different things when they execute-- for example the `.` macro adheres directly to the item to its right, whereas the `+` macro creates groups out of its entire left and right sides and adheres directly to neither.)

## Operator precedence

If you just ignore all this "macro" stuff and consider the symbols in Emily as normal operators, here's what another language would call "precedence" and "associativity" for those operators.

In the table below, higher items are "higher precedence" (bind tighter). Left-associative operators "bind to the left" (prefer to group left in the absence of clarifying parenthesis).

Precedence | Associativity | Operator
-----------|---------------|----------
1          | Right         | \version
2          | Right         | .
3          | Right         | ^
           |               | ^!
4          | Left          | ~
           |               | !
5          | Left          | *
           |               | /
6          | Left          | +
           |               | -
7          | Left          | >=
           |               | >
           |               | <=
           |               | <
8          | Left          | !=
           |               | ==
9          | Left          | &&
10         | Left          | ||
11         | Right         | ?:
12         | Right         | =
13         | Left          | `

