**Emily programming language, version 0.1**
**Tutorial**

This is a quick overview of how to write programs in the Emily programming language. I assume you have written in some programming language before, I assume you know how to access your operating system's command line, and I assume you have [already installed the interpreter](build.md).

If you just want an explanation of what Emily is, see [intro.md](intro.md). If you want exhaustive documentation of the language, see [manual.md](manual.md).

# For starters

## A really simple program

Let's start with a really simple emily program:

    println 3

If you run this program, it will print "3.". I suggest you try running this program by saving it to a file `play.em` and then running `emily play.em` at the command line. Alternately, you can run the program from the command line directly by typing `emily -e 'println 3'`.

What is this program doing? Well, Emily is all about applying functions. `println` is a function which prints its argument followed by a newline. In most languages, if you want to apply a function, there's a special syntax for it, usually `()`. In Emily the way you apply a function to an argument is you just write the argument after the function. `println(3)` would have worked too, but the `()` are just parenthesis. They don't mean anything special.

Emily has variables, and we can assign to them with `=`. So we can say:

    a = 3
    b = println
    b a

And this will print "3", again. Notice: Functions are just values. You can store a function in a variable. You can pass a function as an argument to a function. You can return a function from another function. In fact, `println`, when you call it, returns a value, and that value is a function. What `println x` returns is another copy of `println`. So you can say:

    a = println 3
    a 4

And this will print

    3.
    4.

If you write several things on a line one after another, it will apply them one by one-- it will apply the first value to the second value, and then apply the return value of that to the third value, and the return value of **that** to the fourth value, and so on. So since `println` returns itself, you can say:

    (println 3) 4

Or:

    println 3 4

And this again will just print

    3.
    4.

## Values and math

Besides variable names, there are a couple different types of values you can write into your program. There are numbers and strings:

    3
    3.3
    "Okay"

All numbers are floating-point. You can do math on the numbers:

    println (3 + 4)
    println (4 * 5)
    println (5 * (6 + 7))
    println (3 == 3)
    println (4 + ~8 > 10 - 3)

(In this version of the language, `~8` is how you write "negative 8". You can't just say `(-8)`.)

If you run this code you get:

    7.
    20.
    65.
    <true>
    <null>

You'll notice two additional kinds of values here, when we used the equality operators: `true` and `null`. You can get these values directly in your program by saying `true` or `null`. `null` is just what Emily calls false.

You can't do anything to a string right now except `print` or `println` it.

There's three more kinds of values: Closures, objects, and atoms.

## Making functions

The `=` operator can do a lot more than assign variables. It can also make functions:

    twice ^number = number * 2

This makes a function "twice" which multiplies a number by two. Functions, again, are just values, so you're actually just assigning a function to the variable "twice"; this would have done the same thing:

    twice = ^number (number * 2)

And we could have not bothered with the variable at all:

    println ( ( ^number (number * 2) ) 4 )

That might be written a bit confusing! But this applies an "anonymous" function which doubles its arguments to the number 4, then prints the result. This code prints `8`.

`^`, whereever you see it in Emily, just means "make a function here". I call the functions that are made with ^ "closures". I'll explain why later.

## Making objects

One more thing you can make in Emily is an "object". Objects store things. You can make an empty object by saying `[ ]`. Or you can store values in it, like this:

    numbers = [
        one = 1
        two = 2
        three = 3
    ]
    println (numbers.two)

This will print `2.`

Any `=` statement inside of a `[ ]`, rather than assigning to a variable, will assign to a field inside of the new object. At the end of the `[ ]`, the new object is returned.

An object is a mapping of keys to values. You can say:

    obj = []
    obj 3 = "three"
    println (obj 3)

And this will print `three`. This is actually not any different from what we were doing a moment ago with `numbers.two`; `.` is not some magic field-access operator in this language, rather `.two` is just a kind of value, and the `numbers` object maps the value `.two` to the value `2`. `.anyIdentifierHere` is what's called an "atom", and it is a special kind of string. You can store it in a variable:

    key = .two
    println (numbers key)

This will print `2`.

Above we see `=` being used both to set the values of variables, and to set the values of keys on objects. There is a trick: `=` is doing the same thing in both cases. Every line of code has a "scope object", which holds all its variables. When you write an identifier by itself, like `numbers`, what you are doing is looking up the key `.numbers` on the scope object; `numbers.a` is the same as saying `SCOPE.numbers.a`, if you could somehow get a reference to the scope.

# Fancier stuff

## Statements and groups

You can put comments on lines with `#`.

    println (3 + 4)   # Prints 7

As you saw above, you can put a series of statements on lines one after the other, and they're executed in order. You can put multiple statements on one line with `;`:

    a = 3; println a  # Prints 3

If you want to do the opposite and break a single statement across multiple lines, you can do this with `\`:

    println 3 \    # This prints a 3, then a newline, then a 4
            4

You can also put multiple statements, (i.e. multiple lines) inside of a `()` or a `[]`. I call these parenthetical-type things "groups". If you put multiple lines in a `( )`, the group evaluates to the value of the final nonempty statement.

    println (
        x = 3;
        x + 5
    )

This prints `8`. This code is ugly though: it assigns `x` in the middle of evaluating an expression, and `x` endures after the parenthesis finishes. For these situations-- where you want to do some calculation inside of a expression-- `{ }` is a group which acts like `( )` but a new scope is created inside of it. So you can say:

    x = 3
    println {
        x = 4
        x + 1
    }
    println x

And, well, honestly this is not great code either, but the `x` assigned inside the `{ }` will be a different `x` than the one outside the `{ }`. This code prints a `5` and then a 3`.

## "Currying"

You'll notice I am putting parenthesis after "println" a lot in these code samples, even though I said parenthesis are not needed. This is because function applications greedily always apply to whatever token is on the left, and this can mix you up:

    numbers = [ one = 1 ]
    println numbers.one

This code **looks** like it prints `1`, the values of `numbers.one`. In fact no, what it does is apply `println` to `numbers`, which returns `println`, which is then applied to `.one`. So it prints:

    <object>
    one

This isn't what you wanted, so we need the `( )`. Writing `( )` gets annoying all the time, I think, so you can write `:` as a shortcut:

    println: numbers.one

`:` wraps the remainder of the statement after it in parenthesis, so this is like saying `println (numbers.one)`.

Why require the `( )` (or the `:`) in the first place, though? Well, some of this syntax might change in a later version. But the idea is that Emily expressions are meant to be "curried". Emily arguments are all single-argument. Wait, wait, you're saying, but I need functions that take multiple arguments. Well, you can build multiple-argument functions on top of single-argument ones. One is to pass the argument list as an object:

    printRecord ^record = \
        print (record.name) ": " (record.numberOfArms) " arms\n"

    printRecord [name = "Sarah"; numberOfArms = 3]

Another way is to sort of fold functions inside each other:

    description ^name ^species ^arms = \
        print name " is a " species " with " arms " arms\n"

    description "Natalie" "centaur" 2

So, you're thinking, "description" is just a function with 3 arguments, and you apply the function by writing them one after the other? And sure, you can think of it that way, but what's actually happening is that each `^` is creating a function that returns a function inside of it. Remember how `print` is basically a machine that you feed something into, and it spits out a copy of itself for you to feed the next thing into? This is why I'm able to write those long chained `print` statements like in the last example. Well, `description` is like a machine that spits out another machine that spits out **another** machine that spits out a description of your friend Natalie. Once you're thinking about it this way, you can do something neat: You can take one of these intermediate machines and make a copy.

    natalieGenerator = description "Natalie" "centaur"
    natalieGenerator 3
    natalieGenerator 4
    natalieGenerator 5

I'm not really sure what's going on with Natalie there, maybe she should see a doctor. But, this code prints three separate lines about an increasingly multi-limbed centaur named Natalie:

    Natalie is a centaur with 3. arms
    Natalie is a centaur with 4. arms
    Natalie is a centaur with 5. arms

By leaving out the final argument when we made `natalieGenerator`, we got a "partial application" function which is still just sitting there, waiting, for its last argument so it can run.

## Flow control

The "currying" trick is a little academic, but it's an example of what kinds of things we can do once we start thinking of functions as values. What this is leading up to is "higher-order functions", which are a bit more practical, since they're are how you do flow control in Emily:

    x = 3
    if (x < 4) ^(
        print x " is less than 4\n"
    )

In most languages, things like `if` or `while` are magic-- `if` in C snarfs up "something surrounded by a parenthesis" and "something surrounded by curly braces" and then decides whether to execute the curly brace code or not. There's no magic in Emily. There's just functions. `if` is a function. It takes an argument, checks if it's true (meaning: not `null`), and if it's true it executes its next argument as a function.

You might be saying now: I don't **care** about all this functional programming currying stuff! I just want to write an if statement. And that's fine, you shouldn't have to get wrapped up in the theory. Just what you need to know is that things like `if` and `while` are not magic, and any statement gets executed exactly when and where you wrote it unless there's that `^` to say "not yet". So if you're using `if` or `while`, you **do** need to put in a `^`. Oh, right, there's also a `while`:

    # Print the numbers 1 2 3 4
    x = 1
    while ^(x < 5) ^( println x ; x = x + 1 )

`while` needs `^` on both of its parentheticals-- the `(x < 5)` gets run again and again at each pass of the loop, so it needs that "not yet".

By the way, you don't **need** to use `if` or `while` at all, because there's recursion:

    countdown ^x = (
        println x
        x > 0 ? countdown (x - 1) : println "blastoff"
    )

    # Print: 5 4 3 2 1 blastoff
    countdown 5

Emily uses a trick from functional programming that isn't worth explaining here called "tail recursion", which keeps the stack from overflowing if you end a function with a recursive call.

# Prototypes

One more concept I want to throw at you, and then I'll try to explain why this stuff works the way it does.

So Emily has "objects". Can it do object-oriented programming? The answer is yes-- if you assign a function to a field inside of an object declaration, it becomes a "method" and gains access to special `this` and `super` variables:

    apple = [
        color = "red"
        describe ^ = println "It is " (this.color)
    ]

    do: apple.describe

This prints "`It is red`". You'll notice I did something new here-- I defined `description` as a function with no arguments. If you do this, it actually becomes a one-argument function that throws its argument away. You can then execute the function later by passing it any value you like, or passing it to `do` (a builtin which invokes a function with the argument `null`).

Emily objects have inheritance, although they do not have classes. Instead, they use "prototypes", which is just a fancy way of saying that objects can inherit from other objects.

    fruit = [
        describe ^ = println "It is " (this.color)
    ]

    lime = [
        parent = fruit
        color = "green"
    ]

    do: lime.describe

This prints "`It is green`". What happens here is that `lime` does not have a `description` field, but it does have a `parent`, and the field named `parent` is special. When you check `lime.description`, if it does not find `.description`, it checks the parent, and returns it from there. Because `description` is not just a normal function but a method, when you call `banana.description` the interpreter knows to set `this` to be equal to `banana`, not `fruit`. (The `fruit` base prototype doesn't even have a color, so if you say `do: fruit.description`, you'll just get an error.) `fruit` here is just another object, but it's **acting like** a class.

If an object needs to send a message to its parent, it should use the special `super` variable to do that:

    banana = [
        parent = fruit
        color = yellow
        describe ^ = (
            do: super.describe
            println "It has seeds"
        )
    ]

    plantain = [
        parent = banana
        color = beige
        describe ^ = (
            do: super.describe
            println "It's crispy, like it's been fried"
        )
    ]

    do: plantain.describe

This prints

    It is beige
    It has seeds
    It's crispy, like it's been fried

Each call to `super` calls the function in the parent. Wait, couldn't you have also just said `do: this.parent.describe`, instead of using `super`? Well, that's legal, but then the special-ness that makes `this` work would break; if you'd said `this.parent.describe`, you'd have gotten a function that was a method of `banana`, not a method of `plantain`, and the description would have said "It is yellow". `super` makes sure the special method rewiring still works.

### Array builtins

One last thing, real quick: If you don't set a `parent` on an object, it still has a parent. There's a universal default parent for objects. At the moment, all this universal parent contains is `append` and `each`. These are methods that let you treat objects like arrays:

    array = []
    array.append "one"
    array.append "two"
    array.append "three"
    println (array.count) (array 0)
    array.each print

This prints:

    3
    one
    onetwothree

Calling `append` on an object sets the key `count` to `append`'s argument, and then increments `count`; `each` takes a function as argument, and invokes it on all numeric keys from `0` up to `count`.

# Why any of this?

TODO
