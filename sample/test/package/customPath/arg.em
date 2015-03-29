# Commandline tool test: Test setting custom paths by env var
# Arg: --package-path
# Arg: sample/test/package/customPath/argLoad/loadPackage
# Arg: --project-path
# Arg: sample/test/package/customPath/argLoad/loadProject
# Expect:
# Loaded from package using arg
# Loaded from project using arg

println: package.load.cookie
println: project.load.cookie