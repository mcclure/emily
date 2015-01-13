This last year I've been working on a programming language. Around April, I sat down and I wrote out a [list of all the things I want out of a programming language](http://msm.runhello.com/p/928). Nothing that exists right now felt satisfying. So I decided to make my own. I've named this language Emily, and as of today I have a [finished "version 0.1" release that you can download and run](https://bitbucket.org/runhello/emily/wiki/Home). This version is **very** primitive in certain ways, but you can write a program in it and I think it demonstrates where the language is going.

In this file:

[toc]

## An example

Here's a small program in Emily:

    width = 80

    foreach ^upto ^perform = {
        counter = 0
        while ^(counter < upto) ^( perform counter; counter = counter + 1; )
    }

    inherit ^class = [ parent = class ]

    line = [                               # Object for one line of printout
        createFrom ^old = {
            foreach width ^at { # Rule 135
                final = width - 1
                here   = old at
                before = old ( at == 0 ? final : at - 1 )
                after  = old ( at == final ? 0 : at + 1 )
                this.append: ( here && before && after ) \
                         || !( here || before || after )
            }
        }
        print ^ = {
            this.each ^cell { print: cell ? "*" : " " }
            println ""                                          # Next line
        }
    ]

    repeatWith ^old = {  # Repeatedly print a line, then generate a new one
        do: old.print
        new = inherit line
        new.createFrom old
        repeatWith new
    }

    starting = inherit line        # Create a starting line full of garbage
    next = 1
    foreach width ^at (
        starting.append: at != next
        if (at == next) ^( next = next * 2 )
    )
    repeatWith starting                                             # Begin

This executes the 1d rule 135 cellular automata, or in other words, it prints strange pyramids:

    *  * *** ******* *************** ******************************* ***************
          *   *****   *************   *****************************   **************
     ****   *  ***  *  ***********  *  ***************************  *  ************
      **  *     *       *********       *************************       **********
    *       ***   *****  *******  *****  ***********************  *****  ********  *
      *****  *  *  ***    *****    ***    *********************    ***    ******
    *  ***          *  **  ***  **  *  **  *******************  **  *  **  ****  ***
        *  ********         *               *****************               **    **
     **     ******  *******   *************  ***************  *************    **
        ***  ****    *****  *  ***********    *************    ***********  **    **
     **  *    **  **  ***       *********  **  ***********  **  *********      **
           **          *  *****  *******        *********        *******  ****    **
     *****    ********     ***    *****  ******  *******  ******  *****    **  **
      ***  **  ******  ***  *  **  ***    ****    *****    ****    ***  **        **
       *        ****    *           *  **  **  **  ***  **  **  **  *      ******
    **   ******  **  **   *********                 *                 ****  ****  **
    *  *  ****          *  *******  ***************   ***************  **    **    *
           **  ********     *****    *************  *  *************      **    **
    ******      ******  ***  ***  **  ***********       ***********  ****    **    *
    *****  ****  ****    *    *        *********  *****  *********    **  **    **
     ***    **    **  **   **   ******  *******    ***    *******  **        **
      *  **    **        *    *  ****    *****  **  *  **  *****      ******    ****
            **    ******   **     **  **  ***               ***  ****  ****  **  **
    *******    **  ****  *    ***          *  *************  *    **    **
     *****  **      **     **  *  ********     ***********     **    **    ********
      ***      ****    ***         ******  ***  *********  ***    **    **  ******
    *  *  ****  **  **  *  *******  ****    *    *******    *  **    **      ****  *
           **               *****    **  **   **  *****  **       **    ****  **
    ******    *************  ***  **        *      ***      *****    **  **      ***
    *****  **  ***********    *      ******   ****  *  ****  ***  **        ****  **
    ****        *********  **   ****  ****  *  **       **    *      ******  **    *
    ***  ******  *******      *  **    **         *****    **   ****  ****      **
     *    ****    *****  ****       **    *******  ***  **    *  **    **  ****
       **  **  **  ***    **  *****    **  *****    *      **       **      **  ****

Anyway, even without knowing the syntax, you might notice a few things looking at this program:

- This language is **extremely** extensible. Near the beginning, I realized there were two things that I didn't get a chance to put in the standard library: a foreach function, and a way to instantiate an object of a class. So I just implemented them in the program. Very simple.
- Support for both ["unpure"] functional and object-oriented styles: Functions are being passed as values all over the place, functions are being created offhandedly (that's the `^`), objects with prototype inheritance are created very casually (that's `[]`), tail recursion works.
- Clean, familiar syntax: At least, assuming you've been writing a lot of Python, JS, or Lua, this looks a lot like code you've written before, other than the `^`s.

## Why's Emily special?: For language geeks

The one central New Idea in Emily is that **everything is a function**, or maybe put another way, objects and functions are interchangeable. You can think of an "object", or a structure, as being a function that maps key names to values; Emily actually treats it this way. If an object can be a function, then anything can be; `3.add` can be the function that adds 3 to another number, `3` can be the function that maps `.add` to `3.add`.

What's interesting here isn't functions specifically; it's simply that everything in Emily is the **same thing**. Everything acts like a unary (one-argument) function, and where other languages might have several "verbs" (field lookup, variable definition, function definition, function application, arithmetic) Emily has exactly one verb (function application). All you're doing is applying functions in a particular order, and writing code just means plugging those functions together like pipes. Even the "conventional" syntax elements, like `+` or the `.` lookups, are just unary function applications in disguise. Even declaring a variable is done with a function call.

So why does this matter?

## Why's Emily special?: The practical side

I like to build abstractions in my code. If I'm writing a C program, and I find I'm writing `for(int c = 0; c < upto; c++) {something}` over and over, I get annoyed; I wish I could just define a "foreach upto {something}", like I did in the pyramid program up top.

I like to mix different kinds of tools when I write software. I really like Lua, but Lua isn't very good for certain kinds of binary manipulation and threading, so I write programs that are part C++ and part Lua. But this is tricky; the languages each have their own complexities, and the complexities clash. Languages don't work well with each other.

I assert both these things get a *lot* easier if you have a language whose underlying model is very simple.

In Emily, where everything is function applications, building complex abstractions just means plugging the applications together in a particular order. The language *itself* doesn't need to be this simple-- again, if you look above, a lot of stuff is happening that doesn't look like a function application. But that complexity was built on top of the language, rather than being a fundamental part of the model. This means it can be extended further, and it also means it can be replaced.

Syntax like `+` or `=`, for example, is actually performing macro transformations-- `3 + 5 * 4` gets rewritten into `3.plus(5 .times 4)`. This makes these operators easy to extend-- if you want to design an object that "acts like" a number, you just define an object that implements the `.plus` and `.times` methods. It also makes them possible to replace-- the transformations are just little programs, and in a later version of Emily you'll be able to define your own, if there's a different syntax you'd like better.

That's not all that impressive, though-- operator overloading is a pretty standard feature in languages, and macros are not the way you'd prefer to implement abstractions. The more basic feature in Emily that everything is function applications is what opens up the really powerful possibilities. Let's try something a little more unusual. As mentioned above, Emily has prototype inheritance. But it's single inheritance-- only one parent per object. What if you'd prefer multiple inheritance? Well, you can implement it yourself, by writing a single function:

    # A function that returns a function-- it generates the fake "parent"
    dualInherit ^parent1 ^parent2 = ^key {
        thisUpdate this: \
            (parent1.has key ? parent1 : parent2) key
    }

    hasAddOne = [
        addOne ^ = this.value = this.value + 1
    ]
    hasAddTwo = [
        addTwo ^ = this.value = this.value + 2
    ]

    child = [
        parent = dualInherit hasAddOne hasAddTwo
        value  = 0
    ]

    do: child.addOne
    do: child.addTwo
    println: child.value

So what's happening here? The object that `child` inherits from is chosen by setting the `parent` key. But objects and functions in Emily are interchangeable. So `child` **inherits from a function**. `dualInherit` takes two desired parents and manufactures a function which takes a key and executes it on whichever of the two parents knows how to respond. `child` then uses `dualInherit` to inherit from both the classes `hasAddOne` (from which it inherits the method `addOne`) and `hasAddTwo` (from which it inherits the method `addTwo).

## What else?

There's a couple more interesting things that made it into the language, even as early as this version is:

- `\version 0.1`
    This feature is small, but I believes it solves a somewhat fundamental problem with programming languages. Each Emily program is encouraged to start with a line identifying the language version it was developed against. When an Emily interpreter-- current or future-- encounters the `\version` line, it makes a decision about whether that code can be run or not. If the hosting interpreter is backward-compatible with the code's version, it just runs. But if backward-incompatible changes have been made since then, it will either enter a compatibility mode or politely refuse to run. At some point, it will be possible to install these compatibility modes as pluggable modules.

    I write a lot of Python, and a huge running problem is compatibility between versions. In Python, as in most programming languages, the implementation version is the same as the language version. Python 2.4 runs Python 2.4, Python 2.7 runs Python 2.7, Python 3.1 runs Python 3.1, etc. Meanwhile Python 2.7 can run Python 2.4 code, but Python 3.1 **can't** run Python 2.7 code, which means Python is competing with itself and nobody uses Python 3 because all the code's written for 2.7. (Meanwhile even before the big 3.0 switch, **forward** compatibility created a huge problem all by itself: If you had a program that used a feature from 2.5, but what you had installed was 2.4, you wouldn't know it until you try to run it and something breaks strangely, possibly at runtime.)

    This is all silly! Language versions define interfaces, and interpreters are engines. We shouldn't be holding back on upgrading our engines because the interface changed (and if for some reason the engine **can't** handle the old interface, it should at least fail very early). It's possible at least in principle to convert between interfaces, so it should be possible to install something that does conversion for an incompatible past interface (probably even a future one!) It should be possible to mix code written against different interfaces in the same program-- maybe even the same file. There's surely a point at which this becomes untenable (library cross compatibility probably gets awkward quick), but language implementors not being able to get updates adopted because nobody wants to lose back compatibility with 15-year-old versions doesn't sound very tenable either.

    Anyway, for now: Just tag each file with its version, and all this becomes a lot easier to sort out later.

- Proper Unicode support

    This really ought to be something we just expect of a language these days, but Emily is being developed for full Unicode support and the interpreter treats source files as UTF-8. Right now this only extends as far as handling Unicode whitespace-- well, and the macro system supports unicode symbols, but since you can't make macros yet that's not so useful. As soon as possible though my goal is to implement [UAX #31](http://unicode.org/reports/tr31/) so you can use Unicode in identifiers, and I'm hoping to work with coders fluent in non-latin-script languages to make sure Emily is usable for those purposes.

    Oh, also: At some point I'm just gonna make smart quotes work as quotes. If we're gonna keep pasting them in by accident, they might as well work.

- Return continuations

    I'm... not sure I should be calling too much attention to this, but it *is* a bit unique. As I've said, everything in Emily is a function, at least in form. There are no "keywords" as syntax constructs-- any "syntax" is just shorthand for function calls. So if I'm going to implement, say, `return`, it has to be something that can be treated like a function. `return` in Emily winds up being what's called a "continuation"-- a function-like object that when called just jumps to a particular place, in this case the end of the method call.

    This has an interesting side effect that was not entirely intended:

        timeMachine ^ = (           # Function takes no arguments
            goBackward = return     # Store return in a variable. Yes, really.
            return 1                # Return.
        )

        counter = do timeMachine    # The return value of "do TimeMachine" is 1, right?
        println: counter            # Only the first time-- every time we call goBackward,
        goBackward: counter + 1     # we return "counter + 1" from timeMachine,
                                    # even though timeMachine already ended.

    ...it turns out "return" for a particular function call can be treated like any other value, and even outlive the function call it was born in. As with any other kind of continuation, this creates the opportunity for some very powerful constructs (I'm trying to work out how I can implement Java-style named breaks with it) and also the opportunity for some really bad ideas. I'm going to see if I can find a way to encourage the former while maybe putting some limits on the latter.

## What next?

What you see here is part of a [more ambitious set of ideas](http://msm.runhello.com/p/934), some of which may not be completely feasible (link goes to a planning document I wrote before even attempting any code).

- Types
- C++
- Reader macros

These are all Big Ideas though, and the language already needs  so for 0.2 I'm going to be focused on basic functionality improvements (less confusing scoping, operators on strings, short-circuiting booleans, user-defined operators, unicode, package loading, IO).

## Downloading and running Emily

As mentioned, Emily is available [from a BitBucket page](https://bitbucket.org/runhello/emily), but not yet in any other form. You will need to compile it yourself; it's written in Objective Caml, so you'll need to install that first. For instructions, see [build.md](build.md).