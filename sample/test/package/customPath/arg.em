# Commandline tool test: Test setting custom paths by env var
# Arg: --package-path=sample/test/package/customPath/argLoad/loadPackage
# Arg: --project-path=sample/test/package/customPath/argLoad/loadProject
# Expect:
# Loaded from package using env
# Loaded from project using env

println: project.load.cookie
println: package.load.cookie