/*  A simple, one-room, scalable real-time web chat

    Copyright (C) 2010-2011  MLstate

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import stdlib.{date}

type user = string
type users_action = {add : user} / {remove : user} / { clean } / {ping : user}

type author = { system } / { author : string }
type message = {
  author : author;
  text : string;
  date : Date.date;
  event : string;
}
type msg = {message : message} / {users : stringmap(Date.date)}

github_url = "https://github.com/Aqua-Ye/OpaChat"

db /history : intmap(message)

room = Network.cloud("room") : Network.network(msg)

manage_users(user_list : stringmap(Date.date), action : users_action) =
  clean(key, value, acc) =
    time = Duration.in_seconds(Duration.between(value, Date.now()))
    if time > 20. then
       do broadcast({system}, "leave", "{key} has left the room (timeout)")
       acc
    else
       Map.add(key, value, acc)


  match action with
   | {add = u} ->       newmap = Map.add(u, Date.now(),user_list)
                        do broadcast({system}, "join", "{u} is connected to the room")
                        do Network.broadcast({users = newmap}, room)
                        {set = newmap}

   | {remove = u} ->    newmap = Map.remove(u, user_list)
                        do broadcast({system}, "leave", "{u} has left the room (quit)")
                        do Network.broadcast({users = newmap}, room)
                        {set = newmap}

   | {clean} ->         newmap = Map.fold(clean, user_list, Map.empty)
                        do Network.broadcast({users = newmap}, room)
                        {set = newmap}

   | {ping = u} ->      temp = Map.remove(u, user_list)
                        {set = Map.add(u, Date.now(), temp)}

users = Session.cloud("users", Map.empty, manage_users)

do Scheduler.timer(10000, ( -> Session.send(users, {clean})))

launch_date = Date.now()

get_memory_usage = %%c_binding.get_memory_usage%%

update_stats(mem) =
  uptime_duration = Date.between(launch_date, Date.now())
  uptime = Date.of_duration(uptime_duration)
  uptime = Date.shift_backward(uptime, Date.to_duration(Date.milliseconds(3600000))) // 1 hour shift
  do Dom.transform([#uptime <- <>Uptime: {Date.to_string_time_only(uptime)}</>])
  do Dom.transform([#memory <- <>Memory: {mem} Mo</>])
  void

@client
user_update(mem:int)(msg: msg) =
do update_stats(mem)
match msg with
 | {message = x} ->
  line = <div class="line {x.event}">
            <span class="date">{Date.to_string_time_only(x.date)}</span>
            { match x.author with
              | {system} -> <span class="system"/>
              | {~author} -> <span class="user">{author}</span> }
            <span class="message">{x.text}</span>
         </div>
  do Dom.transform([#conversation +<- line])
  do Dom.set_scroll_top(Dom.select_window(), Dom.get_scrollable_size(#content).y_px)
  void
 | ~{users} -> list = Map.fold((elt, _, acc -> <>{acc}<li>{elt}</li></>), users, <></>)
               Dom.transform([#user_list <- <ul>{list}</ul>])

broadcast(author, event, text) =
  message = {~author ~text date=Date.now() ~event}
  do /history[?] <- message
  Network.broadcast({message = message}, room)

build_page(header, content) =
  <div id=#header><div id=#logo/>{header}</div>
  <div id=#content>{content}</div>

@client
send_message(broadcast) =
  _ = broadcast("", Dom.get_value(#entry))
  Dom.clear_value(#entry)

@client
ping(fun)=
  Scheduler.timer(15000, fun)

launch(author:string) =
  init_client() =
    do Session.send(users, {add=author})
    do ping( -> Session.send(users, {ping=author}))
    history_list = IntMap.To.val_list(/history)
    len = List.length(history_list)
    history = List.drop(len-20, history_list)
    // FIXME: optimize this...
    do List.iter( (a -> user_update(get_memory_usage()/(1024*1024))({message = a})) , history)
    Network.add_callback(user_update(get_memory_usage()/(1024*1024)), room)
   logout() =
     do Session.send(users, {remove=author})
     Client.goto("/")
   do_broadcast = broadcast({author=author}, _, _)
   build_page(
     <a class="button github" href="{github_url}" target="_blank">Fork me on GitHub !</a>
     <span class="button" onclick={_ -> logout()}>Logout</span>,
     <div id=#conversation onready={_ -> init_client()}/>
     <div id=#user_list />
     <div id=#stats><span id=#users/><span id=#uptime/><span id=#memory/></div>
     <div id=#chatbar onready={_ -> Dom.give_focus(#entry)}>
       <input id=#entry onnewline={_ -> send_message(do_broadcast)}/>
       <span class="button" onclick={_ -> send_message(do_broadcast)}>Send</span>
     </div>
   )

load() =
  author = Dom.get_value(#author)
  do Dom.transform([#main <- <>Loading...</>])
  Dom.transform([#main <- launch(author)])

start() =
   <div id=#main onready={_ -> Dom.give_focus(#author)}>{
     build_page(
       <></>,
       <span>Choose your name: </span>
       <input id=#author onnewline={_ -> load()}/>
       <span class="button" onclick={_ -> load()}>Join</span>
     )
   }</div>

server = Server.one_page_bundle("Chat",
       [@static_resource_directory("resources")],
       ["resources/style.css"], start)
