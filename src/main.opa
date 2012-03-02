/*  A simple, one-room, scalable real-time web chat, with file sharing

    Copyright © 2010-2012 MLstate

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
 * @author David Rajchenbach-Teller
 * @author Henri Binsztok
 * @author Frederic Ye
 */

import stdlib.system
import stdlib.themes.bootstrap.core
import mindwave

/** Constants **/

GITHUB_USER = "Aqua-Ye"
GITHUB_REPO = "OpaChat"
NB_LAST_MSGS = 10
MW_TIMER = 1000

/** Types **/

type mindstate = (int, int)
type user = { int id, string name, option(mindstate) mindwave }
type source = { system } or { user user }
type message = {
  source source,
  string text,
  Date.date date,
}
type media = {
  source source,
  string name,
  string src,
  string mimetype,
  Date.date date,
}
type client_channel = channel(void)
type network_msg =
   {message message}
or {media media}
or {(user, client_channel) connection}
or {user disconnection}
or {stats}
or {user mindstate}

/** Database **/

database intmap(message) /history

exposed Network.network(network_msg) room = Network.cloud("room")
private reference(intmap(user)) users = ServerReference.create(IntMap.empty)
private launch_date = Date.now()

/** Page **/

watch_button =
  <iframe src="http://markdotto.github.com/github-buttons/github-btn.html?user={GITHUB_USER}&repo={GITHUB_REPO}&type=watch&count=true&size=large"
          allowtransparency="true" frameborder="0" scrolling="0" width="146px" height="30px"></iframe>

fork_button =
  <iframe src="http://markdotto.github.com/github-buttons/github-btn.html?user={GITHUB_USER}&repo={GITHUB_REPO}&type=fork&count=true&size=large"
          allowtransparency="true" frameborder="0" scrolling="0" width="146px" height="30px"></iframe>

function build_page(content) {
  <div id=#header>
    <h2 class="pull-left">OpaChat</h2>
    <div class="buttons pull-left">
      {watch_button}
      {fork_button}
    </div>
  </div>
  <div id=#main>{content}</div>
}

/** Connection **/

server function server_observe(message) {
  match (message) {
  case {connection:(user, client_channel)} :
    ServerReference.update(users, IntMap.add(user.id, user, _))
    Network.broadcast({stats}, room)
    Session.on_remove(client_channel, function() {
      server_observe({disconnection:user})
    })
  case {disconnection:user} :
    ServerReference.update(users, IntMap.remove(user.id, _))
    Network.broadcast({stats}, room)
  default: void
  }
}

_ = Network.observe(server_observe, room)

/** Stats **/

server function mem() {
  System.get_memory_usage()/(1024*1024)
}

server function compute_stats() {
  uptime_duration = Date.between(launch_date, Date.now())
  uptime = Date.of_duration(uptime_duration)
  uptime = Date.shift_backward(uptime, Date.to_duration(Date.milliseconds(3600000))) // 1 hour shift
  (uptime, mem())
}

client @async function update_stats((uptime, mem)) {
  #uptime = <>Uptime: {Date.to_string_time_only(uptime)}</>
  #memory = <>Memory: {mem} Mo</>
}

/** Users **/

client @async function update_users(nb_users, users) {
  #users = <>Users: {nb_users}</>
  #user_list = <ul class="unstyled">{users}</ul>
}

/** MindWave **/

client function level_to_prefix(level) {
  if (level <= 33) "med"
  else if (level <= 66) "att"
  else "blnk"
}

client function mindwave_to_html(mindwave) {
  match (mindwave) {
  case {none}: <span class="ns-icon32 misc"/>
  case {some:(t, r)}:
    preT = "{level_to_prefix(t)}Face"
    preR = "{level_to_prefix(r)}Glow"   
    <span class="ns-icon32 {preR}"><span class="ns-icon32 {preT}"/></span>
  }
}

client @async function update_mindwaves(user_minds) {
  List.iter(function((id, state)) {
    #{"{id}-state"} = mindwave_to_html(state)
  }, user_minds)
}

client reference(option(mindstate)) mindstate =
  ClientReference.create(none)

client function mind_changed(new_state) {
  match (ClientReference.get(mindstate)) {
  case {none}: Option.is_some(new_state)
  case {some:(t, r)}:
    match (new_state) {
    case {none}: true
    case {some:(thinking, relaxation)}:
      thinking <= 33 && t > 33 ||
      thinking <= 66 && (t > 66 || t <= 33) ||
      thinking > 66 && t <= 66 ||
      relaxation <= 33 && r > 33 ||
      relaxation <= 66 && (r > 66 || r <= 33) ||
      relaxation > 66 && r <= 66
    }
  }
}

client function check_mindstate(user) {
  new_mindstate =
    if (MindWave.is_present()) {
      thinking = MindWave.get_thinking_level()
      relaxation = MindWave.get_relaxation_level()
      Log.info("MindWave", "thinking:{thinking} - relaxation:{relaxation}")
      some((thinking, relaxation))
    } else none
  if (mind_changed(new_mindstate)) {
    user = { user with mindwave:new_mindstate }
    Network.broadcast({mindstate:user}, room)
  }
  ClientReference.set(mindstate, new_mindstate)
}

/** Conversation **/

function source_to_html(source) {
  match (source) {
  case {system} : <span class="system"/>
  case {~user} : <span class="user">{user.name}</span>
  }
}

client @async function message_update(stats, list(message) messages) {
  update_stats(stats)
  List.iter(function(message) {
    date = Date.to_formatted_string(Date.default_printer, message.date)
    time = Date.to_string_time_only(message.date)
    line = <div class="line">
              <span class="date" title="{date}">{time}</span>
              { source_to_html(message.source) }
              <span class="message">{message.text}</span>
           </div>
    #conversation =+ line
  }, messages)
  Dom.scroll_to_bottom(#conversation)
}

client @async function media_update(stats, list(media) medias) {
  update_stats(stats)
  List.iter(function(media) {
    date = Date.to_formatted_string(Date.default_printer, media.date)
    time = Date.to_string_time_only(media.date)
    media_parser = parser {
      case "image/" .*: {image}
      case "audio/" .*: {audio}
      case "video/" .*: {video}
    }
    line = <div class="line">
              <span class="date" title="{date}">{time}</span>
              { source_to_html(media.source) }
              { match (Parser.try_parse(media_parser, media.mimetype)) {
                case {some:{image}}:
                  <img src="{media.src}" alt="{media.name}"/>
                case {some:{audio}}:
                  <audio src="{media.src}"
                         controls="controls"
                         type="{media.mimetype}"
                         preload="auto">
                    Your browser does not support the audio tag!
                  </audio>
                case {some:{video}}:
                  <video src="{media.src}"
                         controls="controls"
                         preload="auto"
                         type="{media.name}">
                    Your browser does not support the video tag!
                  </video>
                default:
                  <span class="media {media.mimetype}"> is sharing a file :
                    <a target="_blank" href="{media.src}"
                       draggable="true"
                       data-downloadurl="{media.mimetype}:{media.name}:{media.src}">{media.name}</a>
                  </span>
                } }
           </div>
    #conversation =+ line
  }, medias)
  Dom.scroll_to_bottom(#conversation)
}

exposed @async function broadcast(user, text) {
  message = {source:user, ~text, date:Date.now()}
  /history[?] <- message
  Network.broadcast({~message}, room)
}

client @async function send_message(user, _) {
  broadcast(user, Dom.get_value(#entry))
  Dom.clear_value(#entry)
}

server function file_uploaded(user)(name, mimetype, key) {
  media = {
    source: {~user},
    ~name,
    src: "/file/{key}",
    ~mimetype,
    date: Date.now(),
  }
  Network.broadcast({~media}, room)
}

server function client_observe(msg) {
  match (msg) {
  case {~message} :
    message_update(compute_stats(), [message])
  case {~media} :
    media_update(compute_stats(), [media])
  case {connection:(user, _)} :
    message = {
      source: {system},
      text : "{user.name} joined the room",
      date : Date.now(),
    }
    message_update(compute_stats(), [message])
  case {disconnection:user} :
    message = {
      source: {system},
      text : "{user.name} left the room",
      date : Date.now(),
    }
    message_update(compute_stats(), [message])
  case {stats} :
    update_stats(compute_stats())
    users = ServerReference.get(users)
            |> IntMap.To.val_list(_)
            |> List.sort_by(function(u){u.name}, _)
    users_html_list =
      List.fold(function(user, acc) {
        mw = mindwave_to_html(user.mindwave)
        <li><span id="{user.id}-state" class="mindwave">{mw}</span> {user.name}</li>
        <+> acc
      }, users, <></>)
    update_users(List.length(users), users_html_list)
  case {mindstate:user} :
    ServerReference.update(users, IntMap.add(user.id, user, _))
    users = ServerReference.get(users) |> IntMap.To.val_list(_)
    waves_list =
      List.fold(function(user, acc) {
        (user.id, user.mindwave) +> acc
      }, users, [])
    update_mindwaves(waves_list)
  default : void
  }
}

/** Init **/

// Init various scheduling tasks
client function init_scheduling(user, _) {
  Scheduler.timer(MW_TIMER, function(){
    check_mindstate(user)
  })
}

// Init the client from the server
server function init_client(user, client_channel, _) {
  // Observe client
  obs = Network.observe(client_observe, room)
  Network.broadcast({connection:(user, client_channel)}, room)
  // Observe disconnection
  Dom.bind_beforeunload_confirmation(function(_) {
    Network.broadcast({disconnection:user}, room)
    Network.unobserve(obs)
    none
  })
  // Send NB_LAST_MSGS messages
  history_list = IntMap.To.val_list(/history)
  len = List.length(history_list)
  history = List.drop(len-NB_LAST_MSGS, history_list)
  message_update(compute_stats(), history)
  // Initialize OpaShare
  OpaShare.init(file_uploaded(user))
}

server mindwave_flash = <></>
  // <div id="flashContent">
  //   <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" width="550" height="400" id="FlashToJs" align="middle">
  //     <param name="movie" value="/resources/neurosky/FlashToJs/FlashToJs.swf" />
  //     <param name="quality" value="high" />
  //     <param name="bgcolor" value="#ffffff" />
  //     <param name="play" value="true" />
  //     <param name="loop" value="true" />
  //     <param name="wmode" value="window" />
  //     <param name="scale" value="showall" />
  //     <param name="menu" value="true" />
  //     <param name="devicefont" value="false" />
  //     <param name="salign" value="" />
  //     <param name="allowScriptAccess" value="sameDomain" />
  //     {Xhtml.of_string_unsafe("<!--[if !IE]>-->")}
  //     <object type="application/x-shockwave-flash" data="/resources/neurosky/FlashToJs/FlashToJs.swf" width="550" height="400">
  //       <param name="movie" value="/resources/neurosky/FlashToJs/FlashToJs.swf" />
  //       <param name="quality" value="high" />
  //       <param name="bgcolor" value="#ffffff" />
  //       <param name="play" value="true" />
  //       <param name="loop" value="true" />
  //       <param name="wmode" value="window" />
  //       <param name="scale" value="showall" />
  //       <param name="menu" value="true" />
  //       <param name="devicefont" value="false" />
  //       <param name="salign" value="" />
  //       <param name="allowScriptAccess" value="sameDomain" />
  //       {Xhtml.of_string_unsafe("<!--<![endif]-->")}
  //       <a href="http://www.adobe.com/go/getflash">
  //               <img src="http://www.adobe.com/images/shared/download_buttons/get_flash_player.gif" alt="Get Adobe Flash player" />
  //       </a>
  //       {Xhtml.of_string_unsafe("<!--[if !IE]>-->")}
  //     </object>
  //     {Xhtml.of_string_unsafe("<!--<![endif]-->")}
  //   </object>
  // </div>

server @async function enter_chat(user_name, has_mindwave, client_channel) {
  user = {
    id: Random.int(max_int),
    name: user_name,
    mindwave: if (has_mindwave) some((0, 0)) else none,
  }
  // #Body is the default body id in Opa
  #main =
    <div id=#sidebar>
      <h3>Users online</h3>
      <div id=#user_list/>
      {OpaShare.html()}
    </div>
    <div id=#content
         onready={function(e){
                    init_scheduling(user, e)
                    init_client(user, client_channel, e)
                  }}>
      <div id=#stats><div id=#users/><div id=#uptime/><div id=#memory/></div>
      <div id=#conversation/>
      <div id=#chatbar>
        <input id=#entry
               autofocus="autofocus"
               onready={function(_){Dom.give_focus(#entry)}}
               onnewline={send_message({~user}, _)}
               x-webkit-speech="x-webkit-speech"/>
      </div>
    </div> <+>
    mindwave_flash
}

client @async function join(_) {
  name = Dom.get_value(#name)
  client_channel = Session.make_callback(ignore)
  has_mindwave = MindWave.is_present()
  enter_chat(name, has_mindwave, client_channel)
}

// Page headers
headers =
  Xhtml.of_string_unsafe("
<!--[if lt IE 9]>
<script src=\"//html5shiv.googlecode.com/svn/trunk/html5.js\"></script>
<![endif]-->") <+>
  <meta charset="utf-8"></meta>
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"></meta>
  <meta name="viewport" content="width=device-width,initial-scale=1"></meta>

// Start page
server function start() {
  page = build_page(
    <h3>A real-time web chat built in Opa.</h3>
    <div id=#login class="form-inline">
      <input id=#name
             placeholder="Name"
             autofocus="autofocus"
             onready={function(_){Dom.give_focus(#name)}}
             onnewline={join}/>
       <button class="btn primary"
               onclick={join}>Join</button>
    </div>
  )
  Resource.full_page_with_doctype(
    "OpaChat - a real-time web chat built in Opa",
    {html5},
    page, headers, {success},
    []
  )
}

// Parse URL
url_parser = parser {
  // case "/file/" key=Rule.integer:
  //   match (OpaShare.get(key)) {
  //   case {some:file}:
  //     Resource.binary(file.content, file.mimetype)
  //     |> Resource.add_header(_, {content_disposition:{attachment:file.name}})
  //   default: start()
  //   }
  case (.*): start()
}

Resource.register_external_js("/resources/neurosky/FlashToJs/api.js")

// Start the server
Server.start(Server.http, [
  { resources : @static_resource_directory("resources") }, // include resources directory
  { register : [
      "/resources/css/bootstrap.min.css",
      "/resources/css/bootstrap-responsive.min.css",
      "/resources/css/style.css",
      "/resources/neurosky/icons.css",
    ] }, // include CSS in headers
  { custom : url_parser } // URL parser
])
