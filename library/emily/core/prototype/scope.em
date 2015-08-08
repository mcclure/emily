null = ()

do ^x = x null

nullfn ^ = null

rawTern = internal.tern

# DUPLICATES valueUtil
tern ^predicate a b = do: rawTern predicate a b

not ^x = rawTern x null true

if ^predicate body = tern predicate ^(do body) nullfn

loop ^f = if (do f) ^(loop f)

while ^predicate body = if (do predicate) ^(do body; while predicate body)

and ^a b = tern (do a) b nullfn

or ^a b = { aValue = do a; tern aValue ^(aValue) b }

xor ^ a b = {
    aValue = do a
    bValue = do b
    rawTern aValue (
        rawTern bValue null aValue
    ) bValue
}

sp = " "

ln = "\n"

true = internal.true

print = internal.out.print

println ^s = ( print s ln; do: internal.out.flush ; println )

# FIXME: Any whitespace not just ln
printsp ^s = {
    printsp2 ^s = s == ln ? (
        print s; printsp
    ) : (
        print sp s; printsp2
    )
    print s; printsp2
}

thisTransplant = internal.thisTransplant
thisInit       = internal.thisInit
thisFreeze     = internal.thisFreeze
thisUpdate     = internal.thisUpdate

floor = internal.double.floor

atom   = internal.type.isAtom
string = internal.type.isString
number = internal.type.isNumber
int ^x = number x && x == floor x # Sort of a virtual type, I suppose...?

internal.setPropertyKey current .scope ^x(x)
