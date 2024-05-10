open Mirage

let main = 
  let libraries = [ 
    package "mirage-protocols";
    package "mirage-unix";
  ] in
  let packages = [
    package "mirage-protocols";
    package "mirage-unix";
  ] in
  job "unikernel" @@ fun _ ->
    Mirage_unix.mkdir_p "/tmp"; 
    Unix.execvp "./bin/znnd" [||]

