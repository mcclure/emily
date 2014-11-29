# Test loop construct plus argument blocks. Expected output: numbers 10 through 18, up by twos.

let .countup ^arg{
    let .count (arg.from)
    loop ^(
        println count
        set .count ( count .plus (arg.step) )
        count.lt (arg.to)
    )
}

countup[ let .from 10; let .to 20; let .step 2 ]