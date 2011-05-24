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

/**
 * A simple, one-room, scalable real-time web chat.
 *
 * @author David Rajchenbach-Teller, David@opalang.org
 */

import stdlib.{date}

/**
 * {1 Network infrastructure}
 */

/**
 * The type of messages sent by a client to the chatroom
 */
type message = {author: string /**The name of the author (arbitrary string)*/
               ; text: string  /**Content entered by the user*/
               ; date: Date.date
               }

db /history : list(message)

/**
 * The chatroom.
 */
room = Network.cloud("room"): Network.network(message)

/**
 * {1 User interface}
 */

/**
 * Update the user interface in reaction to reception of a message.
 *
 * This function is meant to be registered with [room] as a callback.
 * Its sole role is to display the new message in [#conversation].
 *
 * @param x The message received from the chatroom
 */
user_update(x: message) =
  line = <div class="line">
            <span class="date">{Date.to_string_time_only(x.date)}</span>
            <span class="user">{x.author}:</span>
            <span class="message">{x.text}</span>
         </div>
  do Dom.transform([#conversation +<- line ])
  Dom.scroll_to_bottom(#conversation)

/**
 * Broadcast text to the [room].
 *
 * Read the contents of [#entry], clear these contents and send the message to [room].
 *
 * @param author The name of the author. Will be included in the message broadcasted.
 */
broadcast(author) =
   message = {~author text=Dom.get_value(#entry) date=Date.now()}
   do Network.broadcast(message, room)
   do /history <- [message | /history]
   Dom.clear_value(#entry)

/**
 * Build the user interface for a client.
 *
 * Pick a random author name which will be used throughout the chat.
 *
 * @return The user interface, ready to be sent by the server to the client on connection.
 */
launch(author) =
   init_client() =
     // iter = Iter.of_list(/history)
     history = List.take(20, /history)
     do List.iter(user_update, history)
     Network.add_callback(user_update, room)
   <div id=#header><div id=#logo></div></div>
   <div id=#conversation onready={_ -> init_client()}></div>
   <input id=#entry  onnewline={_ -> broadcast(author)}/>
   <div class="button" onclick={_ -> broadcast(author)}>Send</div>

start() =
   go(ev) = Dom.transform([#main <- launch(Dom.get_value(#author))])
   <div id=#main>
   <div id=#header><div id=#logo></div>Choose your name:</div>
   <input id=#author onnewline={go}/>
   <div class="button" onclick={go}>Launch</div>
   </div>

/**
 * {1 Application}
 */

/**
 * Main entry point.
 *
 * Construct an application called "Chat" (users will see the name in the title bar),
 * embedding statically the contents of directory "resources", using the global stylesheet
 * "resources/css.css" and the user interface defined in [start].
 */
server = Server.one_page_bundle("Chat",
       [@static_resource_directory("resources")],
       ["resources/css.css"], start)
