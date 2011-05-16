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

namespace icp {
  MainLoop main_loop;

  public class Main {
    public static int main (string[] args) {
      Gdk.threads_init();
      DBus.thread_init();

      // parse args
      Config.init(ref args);
      
      // show version and done
      if (Config.CommandlineOptions.show_version) {
        stdout.printf(
            "ibus-cloud-pinyin %s [built with ibus %d.%d.%d]\n"
            + "Copyright (c) 2010 WU Jun <quark@lihdd.net>\n",
            Config.version,
            IBus.MAJOR_VERSION, IBus.MINOR_VERSION, IBus.MICRO_VERSION
            );
        return 0;
      }

      // show component xml and done
      if (Config.CommandlineOptions.show_xml) {
        IBusBinding.init();
        stdout.printf("%s", IBusBinding.get_component_xml());
        return 0;
      }

      // init Gtk (require by clipboard reader)
      // will fail without X environment
      Gdk.init(ref args);
      Gtk.init(ref args);
      
      // replace running process
      if (Config.CommandlineOptions.replace_running_process) {
        // IMPROVE: use a better way to kill running ibus-engine-cloud-pinyin
        Posix.system(
          "for i in `ps -C ibus-engine-cloud-pinyin -o pid=`; do "
          +"[ \"$i\" = %d ] || kill $i; done".printf(Posix.getpid())
          );
      }

      Pinyin.init();
      Frontend.init();
      Database.init();
      DBusBinding.init();
      IBusBinding.init();
      LuaBinding.init();

      if (!Config.CommandlineOptions.do_not_connect_ibus) {
        // give lua thread some time (~0.2 s) to set up
        // currently no lock to protect complex settings
        Thread.usleep(100000);
        IBusBinding.register();
      }

      main_loop = new MainLoop (null, false);
      main_loop.run();

      return 0;
    }
  }
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
