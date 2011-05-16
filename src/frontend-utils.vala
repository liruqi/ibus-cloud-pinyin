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
  class Frontend {
    private static string _selection;
    private static unowned Gtk.Clipboard clipboard;
    
    private Frontend() {
      // this class is used as namespace
    }

    public static string get_selection() {
      return _selection;
    }
    
    public static uint64 clipboard_update_time {
      get; private set;
    }

    public static void
    notify(string title, string? content = null, string? icon = null) {
      Notify.Notification notification
        = new Notify.Notification(title, content, icon, null);
      try {
        notification.show();
      } catch (Error e) {
        stdout.printf("Notification: %s %s %s\n", title, content, icon);
        // then, just ignore
        ;
      }
    }

    public static uint64 get_current_time() {
      TimeVal tv = GLib.TimeVal();
      tv.get_current_time();
      return tv.tv_usec + (uint64)tv.tv_sec * 1000000;
    }

    public static void clear_selection() {
      _selection = "";
    }

    public static void init() {
      // assume gtk and gdk are inited
      if (Notify.is_initted()) return;
      _selection = "";
      Notify.init("ibus-cloud-pinyin");
      clipboard = Gtk.Clipboard.get_for_display(
        Gdk.Display.get_default(),
        Gdk.SELECTION_PRIMARY);
      clipboard.owner_change.connect(
        () => {
          lock(_selection) {
            _selection = clipboard.wait_for_text();
            clipboard_update_time = get_current_time();
          }
        }
      );
    }

  }
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
