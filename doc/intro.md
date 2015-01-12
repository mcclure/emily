This last year I've been working on a programming language. Around April, I sat down and I wrote out a [list of all the things I want out of a programming language](http://msm.runhello.com/p/928). Nothing that exists right now felt satisfying. So I'm making my own. I've named this language Emily, and as of today I have a [finished "version 0.1" release that you can download and run](https://bitbucket.org/runhello/emily/wiki/Home). This version is **very** primitive in certain ways, but you can write a program in it and I think it demonstrates where the language is going.

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

## Downloading and running Emily

TODO