open Unix

let run_binary () =
  let binary_path = "./bin/znnd" in
  let command = Printf.sprintf "%s" binary_path in
  match Unix.system command with
  | Unix.WEXITED 0 -> print_endline "Binary executed successfully!"
  | Unix.WEXITED code -> Printf.printf "Binary exited with code %d\n" code
  | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> print_endline "Binary terminated abnormally!"

let () = run_binary ()

