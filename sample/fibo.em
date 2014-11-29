# Test that a "real" program can run. Prints the finonachi numbers.
# NOT PART OF REGRESSION TESTS -- NOT YET WORKING

let .a 0
let .b 1

loop ^{
    println b

    let .c (a .plus b)
    set .a b
    set .b c

    true
}
