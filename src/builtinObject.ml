(* Populates a prototype for objects *)
let objectPrototypeTable = ValueUtil.tableInheriting Value.NoSet BuiltinTrue.truePrototype
let objectPrototype = Value.ObjectValue(objectPrototypeTable)
let () = (ValueUtil.objectPrototypeKnot := objectPrototype)

let appendConstruct = ValueUtil.snippetTextMethod (Token.Internal "append")
    ["tern", ValueUtil.tern; "nullfn", BuiltinScope.nullfn]
    ["v"]
    "tern (this.has.count) nullfn ^(this.let.count 0)
     this.let (this.count) v
     this.set.count (this.count.plus 1)"

let eachConstruct = ValueUtil.snippetTextMethod (Token.Internal "each")
    ["while", BuiltinScope.whileConstruct]
    ["f"]
    "{let .idx 0
     while ^(this.has idx) ^(
         f (this idx);
         set .idx (idx.plus 1)
     )}"

(* TODO: Prototype for []s? .append can live in here. *)
let () =
    let (setAtomValue, _, _) = BuiltinNull.atomFuncs objectPrototypeTable in

    setAtomValue "append" (ValueUtil.rawRethisAssignObjectDefinition objectPrototype appendConstruct);
    setAtomValue "each"   (ValueUtil.rawRethisAssignObjectDefinition objectPrototype eachConstruct);
