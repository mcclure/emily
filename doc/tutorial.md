**Emily programming language, version 0.1**
**Tutorial**

This is a quick overview of how to write programs in the Emily programming language. I assume you have written in some programming language before, I assume you know how to access your operating system's command line, and I assume you have [already installed the interpreter](build.md).

If you just want an explanation of what Emily is, see [intro.md](intro.md). If you want exhaustive documentation of the language, see [manual.md](manual.md).

# For starters

## A really simple program

Let's start with a really simple emily program:

    println 3

If you run this program, it will print "3". I suggest you try running this program by saving it to a file `play.em` and then running `emily play.em` at the command line. Alternately, you can run the program from the command line directly by typing `emily -e 'println 3'`.

What is this program doing? Well, Emily is all about applying functions. `println` is a function which prints its argument followed by a newline. In most languages, if you want to apply a function, there's a special syntax for it, usually `()`. In Emily the way you apply a function to an argument is you just write the argument after the function. `println(3)` would have worked too, but the `()` are just parenthesis. They don't mean anything special.

Emily has variables, and we can assign to them with `=`. So we can say:

    a = 3
    b = println
    b a

And this will print "3", again. Notice: Functions are just values. You can store a function in a variable. You can pass a function as an argument to a function. You can return a function from another function. In fact, `println`, when you call it, returns a value, and that value is a function. What `println x` returns is another copy of `println`. So you can say:

    a = println 3
    a 4

And this will print

    3
    4

If you write several things on a line one after another, it will apply them one by one-- it will apply the first value to the second value, and then apply the return value of that to the third value, and the return value of **that** to the fourth value, and so on. So since `println` returns itself, you can say:

    (println 3) 4

Or:

    println 3 4

And this again will just print

    3
    4
