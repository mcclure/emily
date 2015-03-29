# Test what happens if directory.em gets included while it is already running
# NOT DIRECTLY EXECUTED BY REGRESSION TESTS

println "Loading reflectProgram.em"

testScopeBefore = "Reflect should be able to see this"

testCallback  ^ = println "Directory.em callback"

do: directory.inner.project.reflect

testScopeAfter = "Reflect should not be able to see this"