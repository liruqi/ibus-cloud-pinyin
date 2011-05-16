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

using Gee;

namespace icp {
  class Config {
    // project constants
    public static const string version = "0.8.0.20101124";
    public static const string prefix_path = "@PREFIX@";

    public static string global_data_path { get; private set; }
    public static string user_database { get; private set; }
    public static string global_database { get; private set; }
    public static string program_scel_import { get; private set; }
    public static string program_main_icon { get; private set; }

    public static string user_config_path { get; private set; }
    public static string user_data_path { get; private set; }
    public static string user_cache_path { get; private set; }

    public static string program_main_file { get; private set; }
    public static string program_path { get; private set; }
    public static string program_request { get; private set; }

    // PKGDATADIR should look like: "/usr/share/ibus-cloud-pinyin"
    // since Vala has a very poor preprocessor, i need to 
    // replace all "@PKGDATADIR@" in C code using scripts

    // command line options
    [Compact]
      public class CommandlineOptions {
        public CommandlineOptions() { assert_not_reached(); }

        // script is also for request
        public static string startup_script = null;
        
        public static bool show_version;
        public static bool launched_by_ibus;
        public static bool do_not_connect_ibus;
        public static bool show_xml;
        public static bool user_db_in_memory; 

        public static bool replace_running_process;
      }

    // timeouts, unit: 1 second
    [Compact]
      public class Timeouts {
        public Timeouts() { assert_not_reached(); }

        public static double request = 15.0;
        public static double prerequest = 3.0;
        public static double selection = 2.0;
      }

    // colors
    public class Colors {
      public class Color {
        private int? foreground;
        private int? background;
        private bool underlined;
        public Color(int? foreground = null, int? background = null, 
            bool underlined = false) {
          this.foreground = foreground;
          this.background = background;
          this.underlined = underlined;
        }
        public void apply(IBus.Text text, uint start = 0, int end = -1) {
          if (end == -1) end = (int)text.get_length();
          if ((int)start >= end) return;
          if (underlined) text.append_attribute(IBus.AttrType.UNDERLINE,
              IBus.AttrUnderline.SINGLE, start, end
              );
          if (foreground != null) text.append_attribute(
              IBus.AttrType.FOREGROUND, foreground, start, end
              );
          if (background != null) text.append_attribute(
              IBus.AttrType.BACKGROUND, background, start, end
              );
        }
      }

      private Colors() { assert_not_reached(); }

      public static Color buffer_raw;
      public static Color buffer_pinyin;

      public static Color candidate_local;
      public static Color candidate_remote;

      public static Color preedit_correcting;

      public static Color preedit_local;
      public static Color preedit_remote;
      public static Color preedit_fixed;

      public static void init() {
        buffer_raw = new Color(0x00B75D);
        buffer_pinyin = new Color(null, null, true);

        candidate_local = new Color();
        candidate_remote = new Color(0x0050FF);

        preedit_correcting = new Color(null, 0xFFB442);
        preedit_local = new Color(0x8C8C8C);
        preedit_remote = new Color(0x0D88FF);
        preedit_fixed = new Color(0x242322);
      }
    }

    // limits
    [Compact]
      public class Limits {
        public Limits() { assert_not_reached(); }

        public static int db_query_limit = 128;
        public static int prerequest_retry_limit = 3;
        public static int request_retry_limit = 3;
        public static int cloud_candidates_limit = 4;
      }

    // switches
    [Compact]
      public class Switches {
        public Switches() { assert_not_reached(); }

        public static bool double_pinyin = false;
        public static bool background_request = true;
        public static bool always_show_candidates = true;
        public static bool show_pinyin_auxiliary = true;
        public static bool show_raw_in_auxiliary = true;

        public static bool default_offline_mode = false;
        public static bool default_chinese_mode = true;
        public static bool default_traditional_mode = false;
      }

    // punctuations
    public class Punctuations {
      private Punctuations() { }

      public class FullPunctuation {
        private ArrayList<string> full_chars;
        public bool only_after_chinese { get; private set; }
        private int index;

        public FullPunctuation(string full_chars, 
            bool only_after_chinese = false) {
          this.full_chars = new ArrayList<string>();
          foreach (string s in full_chars.split(" "))
            this.full_chars.add(s);
          this.only_after_chinese = only_after_chinese;
          index = 0;
        }

        public string get_full_char() {
          string r = full_chars[index];
          if (++index == full_chars.size) index = 0;
          return r;
        }
      }

      private static HashMap<int, FullPunctuation> punctuations;

      public static void init() {
        punctuations = new HashMap<int, FullPunctuation>();
        set('.', "。" /*, true */);
        set(',', "，" /*, true */);
        set('^', "……");
        set('@', "·");
        set('!', "！");
        set('~', "～");
        set('?', "？");
        set('#', "＃");
        set('$', "￥");
        set('&', "＆");
        set('(', "（");
        set(')', "）");
        set('{', "｛");
        set('}', "｝");
        set('[', "［");
        set(']', "］");
        set(';', "；");
        set(':', "：");
        set('<', "《");
        set('>', "》");
        set('\\', "、");
        set('\'', "‘ ’");
        set('\"', "“ ”");
      }

      public static void set(int half_char, string full_chars, 
          bool only_after_chinese = false) {
        if (full_chars.length == 0) punctuations.unset(half_char);
        else punctuations[half_char] = new FullPunctuation(full_chars, 
            only_after_chinese
            );
      }

      public static string get(int key, bool after_chinese = true) {
        if (!punctuations.has_key(key) 
            || (punctuations[key].only_after_chinese 
              && !after_chinese)
           ) return "%c".printf(key);
        return punctuations[key].get_full_char();
      }

      public static bool exists(int key) {
        return punctuations.has_key(key);
      }
    }

    // key
    public class Key {
      public uint key { get; private set; }
      public uint state { get; private set; }
      public string label { get; private set; }
      public Key(uint key, uint state = 0, string? label = null) {
        this.key = key;
        this.state = state;
        if (label == null) this.label = "%c".printf((int)key);
        else this.label = label;
      }
      public static uint hash_func(Key a) {
        return a.key | a.state;
      }
      public static bool equal_func(Key a, Key b) {
        return a.key == b.key && a.state == b.state;
      }
    }

    // key actions
    public class KeyActions {
      private KeyActions() { }

      private static HashMap<Key, string> key_actions;

      public static void init() {
        key_actions = new HashMap<Key, string>
          ((HashFunc) Key.hash_func, (EqualFunc) Key.equal_func);      
        set(new Key(IBus.Tab), "correct");
        set(new Key(IBus.BackSpace), "back");
        set(new Key(IBus.space), "commit");
        set(new Key(IBus.Escape), "clear commit");
        set(new Key(IBus.Page_Down), "pgdn");
        set(new Key((uint)'h'), "pgdn");
        set(new Key((uint)']'), "pgdn");
        set(new Key((uint)'='), "pgdn");
        set(new Key(IBus.Page_Up), "pgup");
        set(new Key((uint)'g'), "pgup");
        set(new Key((uint)'['), "pgup");
        set(new Key((uint)'-'), "pgup");
        set(new Key((uint)'\''), "sep");
        set(new Key((uint)'L',
              IBus.ModifierType.RELEASE_MASK | IBus.ModifierType.CONTROL_MASK 
              | IBus.ModifierType.SHIFT_MASK), "trad simp");
        set(new Key(IBus.Shift_L, 
              IBus.ModifierType.RELEASE_MASK | IBus.ModifierType.SHIFT_MASK),
            "eng chs"
           );
        set(new Key(IBus.Shift_R, 
              IBus.ModifierType.RELEASE_MASK | IBus.ModifierType.SHIFT_MASK),
            "online offline"
           );
        set(new Key(IBus.Return), "raw");

        string labels = "jkl;asdf";
        for (int i = 0; i < labels.length; i++) {
          set(new Key(labels[i]), "cand:%d".printf(i));
          set(new Key(i + '1'), "cand:%d".printf(i));
        }
      }

      public static void set(Key key, string action) {
        if (action.length == 0) key_actions.unset(key);
        else key_actions[key] = action;
      }

      public static string get(Key key) {
        if (!key_actions.has_key(key)) return "";
        return key_actions[key];
      }
    }

    // lookup table labels
    public class CandidateLabels {
      private CandidateLabels() { }

      private static ArrayList<ArrayList<string> > labels;

      public static void clear() {
        labels[0].clear();
        labels[1].clear();
      }

      public static void add(string label, string? label_alternative = null) {
        labels[0].add(label);
        labels[1].add(label_alternative ?? label);
      }

      public static void set(int index, string? label = null,
          string? label_alternative = null) {
        if (index < 0 || index >= size) return;        
        if (label != null)
          labels[0].set(index, label);
        if (label_alternative != null) 
          labels[1].set(index, label_alternative);
      }

      public static string get(int index, bool use_alternative = false) {
        if (index < 0 || index >= size) return "";
        return labels[use_alternative ? 1 : 0].get(index);
      }

      public static int size {
        get {
          assert(labels[0].size == labels[1].size);
          return labels[0].size;
        }
      }

      public static void init() {
        labels = new ArrayList<ArrayList<string> >();
        labels.add(new ArrayList<string>());
        labels.add(new ArrayList<string>());

        string labels = "jkl;asdf";
        for (int i = 0; i < labels.length; i++) {
          add(labels[i:i+1], "%d".printf(i + 1));
        }
      }
    }

    // init
    public static void init(ref unowned string[] args) {
      global_data_path = prefix_path + "/share/ibus-cloud-pinyin";

      Colors.init();
      KeyActions.init();
      CandidateLabels.init();
      Punctuations.init();

      // command line options
      // workaround for vala 0.8.0 and 0.9.0 not allowing nested
      // struct assignments
      OptionEntry entrie_replace = { "replace", 'r', 0, OptionArg.NONE, 
        out CommandlineOptions.replace_running_process,
        "Replace running cloud pinyin engine", null};
      OptionEntry entrie_script = { "script", 'c', 0, OptionArg.FILENAME, 
        out CommandlineOptions.startup_script, "Specify a (startup) script",
        "filename" };
      OptionEntry entrie_version = { "version", 'i', 0, OptionArg.NONE,
        out CommandlineOptions.show_version, "Show version information", 
        null };
      OptionEntry entrie_user_db_in_mem = { "userdb-in-memory", 'm', 0, 
        OptionArg.NONE, out CommandlineOptions.user_db_in_memory,
        "Store user database in memory", null };
      OptionEntry entrie_ibus = { "ibus", 'b', 0, OptionArg.NONE,
        out CommandlineOptions.launched_by_ibus, 
        "Take ownship of registered ibus component",
        null };
      OptionEntry entrie_no_ibus = { "no-ibus", 'n', 0, OptionArg.NONE,
        out CommandlineOptions.do_not_connect_ibus,
        "Do not connect to ibus-daemon",
        null };
      OptionEntry entrie_xml = { "dump-xml", 'x', 0, OptionArg.NONE,
        out CommandlineOptions.show_xml, "Dump ibus component xml", 
        null };
      OptionEntry entrie_null = { null };

      OptionContext context =
        new OptionContext("- cloud pinyin client for ibus");
      
      context.add_main_entries({entrie_version, entrie_script, entrie_ibus,
          entrie_no_ibus, entrie_xml, entrie_user_db_in_mem, entrie_replace,
          entrie_null},
          null
          );

      try {
        context.parse(ref args);
      } catch (OptionError e) {
        stderr.printf("option parsing failed: %s\n", e.message);
      }

      if (CommandlineOptions.startup_script == null)
        CommandlineOptions.startup_script = global_data_path 
          + "/lua/config.lua";

      user_cache_path = "%s/ibus/cloud-pinyin".printf(
        Environment.get_user_cache_dir()
        );
      user_data_path = "%s/ibus/cloud-pinyin".printf(
        Environment.get_user_data_dir()
        );
      user_config_path = "%s/ibus/cloud-pinyin".printf(
        Environment.get_user_config_dir()
        );

      user_database = CommandlineOptions.user_db_in_memory ? ":memory:" 
        : "%s/userdb.db".printf(user_cache_path);

      global_database = "%s/db/main.db".printf(global_data_path);

      program_path = Environment.get_current_dir();
      program_main_file = "%s/%s".printf(program_path, args[0]);
      program_main_icon = global_data_path + "/icons/ibus-cloud-pinyin.png";
      program_scel_import =
        "%s/lib/ibus-cloud-pinyin/scel-import-selector.py"
        .printf(prefix_path);
      program_request =
        "%s/lib/ibus-cloud-pinyin/ibus-cloud-pinyin-request"
        .printf(prefix_path);
    }

    // this class is used as namespace
    private Config() { }
  }
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
