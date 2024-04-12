module Consensus = struct
  type producer_event = (* Define ProducerEvent type here *)
  
  module EventManager = struct
    type event_listener = { new_producer_event : producer_event -> unit }

    type t = {
      mutable listeners : event_listener list;
      changes : Mutex.t;
    }

    let new_event_manager () =
      { listeners = []; changes = Mutex.create () }

    let broadcast_new_producer_event em event =
      Mutex.lock em.changes;
      List.iter (fun listener -> listener.new_producer_event event) em.listeners;
      Mutex.unlock em.changes

    let register em listener =
      Mutex.lock em.changes;
      em.listeners <- listener :: em.listeners;
      Mutex.unlock em.changes

    let unregister em listener =
      Mutex.lock em.changes;
      em.listeners <- List.filter (fun l -> l <> listener) em.listeners;
      Mutex.unlock em.changes
  end
end
