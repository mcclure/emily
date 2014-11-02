open Printf

let () =
for i = 0 to Array.length Sys.argv - 1 do
  printf "[%i] %s\n" i Sys.argv.(i)
done;;