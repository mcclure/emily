# Test directory and project, and that each package gets loaded only once.
# Expect:
# Loading directory.em
# Loading project.em
# project.em callback
# Loading includeValid.em
# includeValid.em callback
# includeValid.em callback
# includeValid.em callback

println "Loading directory.em"

# Test can load a function out of a package
do: directory.inner.project.testCallback

# Test can load a function out of a package, and it sees the correct "project"
do: directory.inner.project.bounce

# directory.inner.project should have already loaded this; ensure only loaded once
do: directory.includeValid.testCallback

# Check again through project instead of directory; ensure only loaded once
do: project.includeValid.testCallback
