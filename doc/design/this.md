* DESCRIBES ASPIRATIONS NOT REALITY *

## BEHAVIOR

`this` is probably one of the more mechanically complicated things in Emily, and veers dangerously close to "magic". `this` is the way it is because the semantics are chasing an intuitive notion of "how it should work".

Here's how I expect `this` should work:

1. If you define a function as a member of an object, then you expect on invoking it that `this` in the body refers to the object.
2. If you use `this` in the body of a function defined somewhere else, you expect it to refer to whatever `this` is in the enclosing scope.

Let's call 1 "methods" and 2 "functions".

3. If an object inherits a method from another object, then you expect on invoking it that `this` refers to the inheriting object.
4. If a method was invoked on a `super` object, then you expect that inside the method body `this` refers to the super-calling object.

5. If you store a method in a variable or a dictionary-- say object.method but do not invoke it--, you expect it to have no effect on the `this` binding. You expect it to act like currying.
6. If you store a function in a dictionary, you expect this to have no effect on the `this` binding.

7. It should be possible for `parent` to be a function without fundamentally breaking anything above.

## IMPLEMENTATION

I implement this by each function secretly being in one of four states:

    | ThisBlank
    | ThisNever
    | ThisReady
    | CurrentThis of value*value
    | FrozenThis of value*value

Functions move between states at particular times:
t1. Everything starts ThisBlank.
t2. If a ThisBlank closure is assigned to an object inside a declaration, it becomes ThisReady.
t3. If a ThisReady closure is fetched from an object, it gets CurrentThis'd with this and current=obj.
t4. If a CurrentThis closure is fetched from an object, the This part gets updated with this=obj.
t5. If a ThisBlank closure is stored in a scope or object except inside an object declaration, it becomes ThisNever.
t6. If a CurrentThis closure is stored in a scope or object except inside an object declaration, it becomes FrozenThis.

Some of these are desirable:
- calling `thisTransplant method` unconditionally resets method to ThisBlank.
- calling `thisReady method` conditionally does transform t2
- calling `thisUpdate newThis method` conditionally does transforms t3,t4
- calling `thisFreeze method` conditionally does transforms t5, t6

- calling `thisState method` should return an enum explaining state, when such a thing exists.
- calling `thisGet method` should return the bound this (or an error?).
- calling `thisGetCurrent method` should return the bound current (or an error?).