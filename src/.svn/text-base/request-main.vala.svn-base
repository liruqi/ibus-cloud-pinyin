/******************************************************************************
 *  ibus-cloud-pinyin - cloud pinyin client for ibus
 *  Copyright (C) 2010 WU Jun <quark@lihdd.net>
 *
 * 
 *  This file is part of ibus-cloud-pinyin.
 *
 *  ibus-cloud-pinyin is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  ibus-cloud-pinyin is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with ibus-cloud-pinyin.  If not, see <http://www.gnu.org/licenses/>.
 *****************************************************************************/

// a simple program to emit a response to ibus-cloud-pinyin dbus server
// should be small in size and can be quickly loaded

using Lua;
using DBus;
using Posix;

string script = null;
string pinyins;
int priority;
double timeout;
bool responsed;

int l_response(LuaVM vm) {
  if (vm.is_string(1)) {
    responsed = true;
    string content = vm.to_string(1);

    var conn = DBus.Bus.get(DBus.BusType. SESSION);
    dynamic DBus.Object test_server_object 
      = conn.get_object ("org.ibus.CloudPinyin",
          "/org/ibus/CloudPinyin",
          "org.ibus.CloudPinyin");
    bool ret = test_server_object.cloud_set_response(pinyins, 
        content, priority
        );
  }
  return 0;
}

void* timeout_thread() {
  Thread.usleep((ulong)timeout * 1000000);
  Posix.exit(1);
  return null;
}


int main(string[] args) {
  // set defaults
  priority = 1;
  timeout = 3.0;
  responsed = false;

  // collect essential options
  OptionEntry entrie_script = { "script", 'c', 
    OptionFlags.HIDDEN, OptionArg.FILENAME, 
    out script,
    "", null };
  OptionEntry entrie_request_pinyins = { "request-pinyins", 'r', 
    OptionFlags.HIDDEN, OptionArg.STRING,
    out pinyins, 
    "", null };
  OptionEntry entrie_request_priority = { "request-priority", 'p', 
    OptionFlags.HIDDEN, OptionArg.INT,
    out priority,
    "", null };
  OptionEntry entrie_request_timeout = { "request-timeout", 't', 
    OptionFlags.HIDDEN, OptionArg.DOUBLE,
    out timeout, 
    "", null };
  OptionEntry entrie_null = { null };
  OptionContext context =
    new OptionContext("- internal used by ibus-cloud-pinyin");

  context.add_main_entries({entrie_request_pinyins, entrie_request_timeout, 
      entrie_request_priority, entrie_script, entrie_null}, null
      );

  try {
    context.parse(ref args);
  } catch (OptionError e) {
    ;
  }
  // do nothing if request script is null
  if (script == null) return 4;

  // prepare lua vm and execute script
  LuaVM vm = new LuaVM();
  vm.open_libs();

  vm.check_stack(1);
  vm.push_string("%s/ibus/cloud-pinyin".printf(
        Environment.get_user_cache_dir()
        ));
  vm.set_global("user_cache_path");

  vm.check_stack(1);
  // 'ü' to 'v': already converted in parent process
  vm.push_string(pinyins);
  vm.set_global("pinyin");
  vm.register("response", l_response);
  vm.load_string("dofile([[%s]])".printf(script));

  Thread.create(timeout_thread, false);
  if (vm.pcall(0, 0, 0) != 0) {
    string error_message = vm.to_string(-1);
    GLib.stderr.printf("REQUEST FATAL: %s\n", error_message);
  }

  return (responsed ? 0 : 2);
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */

