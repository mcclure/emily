# Commandline tool test: Test argument overrides env var when setting custom path
# Should change in lockstep with arg.em and env.em
# Subtle: This also tests the = argument mechanism
# Arg: --package-path=sample/test/package/customPath/argLoad/loadPackage
# Arg: --project-path=sample/test/package/customPath/argLoad/loadProject
# Env: EMILY_PACKAGE_PATH=sample/test/package/customPath/envLoad/loadPackage
# Env: EMILY_PROJECT_PATH=sample/test/package/customPath/envLoad/loadProject
# Expect:
# Loaded from package using arg
# Loaded from project using arg

println: package.load.cookie
println: project.load.cookie