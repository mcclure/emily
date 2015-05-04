null = ()

do ^x = x null

nullfn ^ = null

rawTern = internal.tern

# DUPLICATES valueUtil
tern ^predicate a b = do: rawTern predicate a b

if ^predicate body = tern predicate ^(do body) nullfn

loop ^f = if f ^(loop f)

while ^predicate body = if predicate ^(do body; while predicate body) nullfn

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

private.printPlus ^f = {
    p ^x = (print x; do f; p);
    p
}

println = printPlus ^(print ln; do: internal.out.flush)

printsp = printPlus ^(print sp)

thisTransplant = internal.thisTransplant
thisInit       = internal.thisInit
thisFreeze     = internal.thisFreeze
thisUpdate     = internal.thisUpdate