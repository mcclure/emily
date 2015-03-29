# Commandline tool test: Test setting custom paths by env var
# Env: EMILY_PACKAGE_PATH=sample/test/package/customPath/envLoad/loadPackage
# Env: EMILY_PROJECT_PATH=sample/test/package/customPath/envLoad/loadProject
# Expect:
# Loaded from package using env
# Loaded from project using env

println: package.load.cookie
println: project.load.cookie