# Here for "directory" test to include
# NOT DIRECTLY EXECUTED BY REGRESSION TESTS

println "Loading project.em"

# To support directory.em

testCallback ^ = println "project.em callback"

bounce ^ = do: project.includeValid.testCallback

# To support reflectProgram.em

reflect ^ = (
    do: project.reflectProgram.testCallback

    println: project.directory.has .testScopeBefore
    println: project.directory.has .testScopeAfter
)