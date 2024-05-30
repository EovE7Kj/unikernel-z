# unikernel-z
A unikernel for the Network of Momentum

### Basics
<p align="center">
  <img src="./img/unikernel.png">
  <br>
  <a href="https://dl.acm.org/doi/10.1145/2557963.2566628">Unikernel Explained</a> | <a href="https://ocaml.org/">Ocaml</a> | <a href="https://mirage.io/docs/overview-of-mirage">MirageOS</a>

### OCaml

The unikernel will be written in OCaml, a functional programming language known for its expressiveness, safety, and efficiency. OCaml's strong type system and static analysis tools help minimize programming errors, making it well-suited for building reliable and secure systems like unikernels. Additionally, OCaml's lightweight runtime and efficient garbage collector contribute to the overall performance and resource efficiency of the unikernel. By leveraging OCaml's features -- along with the Mirage library -- we aim to deliver a robust and high-performance unikernel system that meets the unique requirements of the Network of Momentum.

```OCaml
let register ?(argv = default_argv) ?(reporter = default_reporter ()) ?src name
    jobs =
  if List.exists Functoria.Impl.app_has_no_arguments jobs then
    invalid_arg
      "Your configuration includes a job without arguments. Please add a \
       dependency in your config.ml: use `let main = Mirage.main \
       \"Unikernel.hello\" (job @-> job) register \"hello\" [ main $ noop ]` \
       instead of `.. job .. [ main ]`.";
  let first =
    [ runtime_args argv; backtrace; randomize_hashtables; gc_control ]
  in
  let reporter = if reporter == no_reporter then None else Some reporter in
  let init = Some first ++ Some delay_startup ++ reporter in
  register ?init ?src name jobs
```
### Mirage
MirageOS uses the OCaml language, with libraries that provide networking, storage and concurrency support that work under Unix during development, but become operating system drivers when being compiled for production deployment.

## Proposal
This proposal focuses on delivering a lightweight, efficient, and secure unikernel solution tailored specifically for the Network of Momentum.

