# Intentionally invalid program, here to be run by includeFail.em, and also to verify "directory" test does not execute it
# NOT DIRECTLY EXECUTED BY REGRESSION TESTS

println "Loading includeInvalid.em"

testCallback ^ = println "includeValid.em callback"

# Fail

3 4

println "This line is unreachable"