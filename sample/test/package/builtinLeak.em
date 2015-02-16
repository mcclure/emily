# Test "has" on packages and also that packages aren't republishing the scope prototype.
# Expect:
# <true>
# <null>
# <null>

println: directory.includeValid.has.testCallback

println: directory.includeValid.has.thisSymbolDoesntExist

println: directory.includeValid.has.print