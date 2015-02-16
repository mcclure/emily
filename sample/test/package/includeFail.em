# Test what happens if you load a bad package.
# Failing tests are usually in a fail/ directory, but directory layout matters here so not this one.
# Expect failure:
# Loading includeFail.em
# Loading includeInvalid.em

println "Loading includeFail.em"

do: directory.inner.includeInvalid.testCallback