# Test some boolean macros.
# Expect:
# <null>
# <true>
# <true>
# <null>
# <null>
# <null>
# <null>

println( null && true )
println( true || null )
println( !null )
println( null  || null  && true  )
println( !true || !true && !null )
println( true  && null  || null  )
println( !null && !true || !true )
