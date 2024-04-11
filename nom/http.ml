(* http.ml *)

(* Open necessary modules *)
open Lwt
open Lwt_unix

let main () =
  (* Create a TCP socket *)
  let server_sock = socket PF_INET SOCK_STREAM 0 in
  
  bind server_sock (ADDR_INET (Unix.inet_addr_any, 8080));
  
  listen server_sock 10;
  
  let rec handle_connection () =
    (* Accept a connection *)
    let%lwt (client_sock, _) = accept server_sock in
    
    let rec handle_communication () =

      let%lwt data = Lwt_io.read_line (Lwt_io.of_fd Lwt_io.Input client_sock) in
      
      let%lwt () = Lwt_io.write_line (Lwt_io.of_fd Lwt_io.Output client_sock) data in
      
      handle_communication ()
    in
    
    (* handle communication with the client *)
    Lwt.async (fun () -> handle_communication ());
    
    (* recursively *)
    handle_connection ()
  in
  
  (* incoming connections *)
  handle_connection ()

let () =
  Lwt_main.run (main ())
