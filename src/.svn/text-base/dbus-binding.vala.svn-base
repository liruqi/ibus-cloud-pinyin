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
  errordomain IOError {
    NO_MORE_CONTENT
  }

  class DBusBinding {
    private static DBus.Connection conn;
    private static dynamic DBus.Object bus;
    private static CloudPinyin server;
    private static int last_cloud_length;

    private class Response {
      public string content { get; private set; }
      public int priority { get; private set; }

      public Response(string content, int priority) {
        this.content = content;
        this.priority = priority;
      }
    }

    private static HashMap<string, Response> responses;

    // for server use, internal
    public static string query(string pinyins) {
      string pinyins_u = pinyins.replace("v", "ü");
      if (responses.has_key(pinyins_u)) return responses[pinyins_u].content;
      else return "";
    }

    public static bool set_response(string pinyins,
        string content, int priority = 1) {
      string pinyins_u = pinyins.dup().replace("v", "ü");
      if ((!responses.has_key(pinyins_u) || responses[pinyins_u].priority
          <= priority) && new Pinyin.Sequence(pinyins_u).size == content.length ) {
        responses[pinyins_u] = new Response(content, priority);
        return true;
      } return false;
    }

    // this convert mix cloud results and local database
    public static string convert(Pinyin.Sequence pinyins,
        bool offline_mode = false,
        out int cloud_length = &(DBusBinding.last_cloud_length)) {
      if (!offline_mode)
        for(int i = pinyins.size; i > 0; i--) {
          string result = query(pinyins.to_string(0, i));
          if (result.size() > 0) {
            cloud_length = (int)result.length;
            return result + Database.greedy_convert(
                new Pinyin.Sequence.copy(pinyins, i)
                );
          }
        }
      cloud_length = 0;
      return Database.greedy_convert(pinyins);
    }

    // scel tool, import a scel file to user database
    public class ScelTool {
      private ScelTool() { }

      static ArrayList<Pinyin.Sequence> pinyin_list;
      static ArrayList<string> phrase_list;
      static ArrayList<double?> freq_list;

      static IdleSource idle;
      static int process_index;

      static void set_idle_source() {
        if (idle != null) return;
        process_index = 0;
        idle = new IdleSource();
        idle.set_callback(() => {
            var sequences = new ArrayList<Pinyin.Sequence>();
            var phrases = new ArrayList<string>();
            var freqs = new ArrayList<double?>();

            // import at most 2048 items one time
            for (int import_count = 0; import_count < 2048
              && process_index < pinyin_list.size;
              process_index++) {
            double freq = freq_list[process_index];

            // do not import gabbage here, hardlimit 10
            if (freq > 10) {
            sequences.add(pinyin_list[process_index]);
            phrases.add(phrase_list[process_index]);
            freqs.add(freq);
            import_count ++;
            }
            } // for

            Database.batch_insert(phrases, sequences, freqs);

            if (process_index >= pinyin_list.size) {
              // import done
              Frontend.notify("导入 scel 词库", 
                  "导入已完成",
                  Config.program_main_icon
                  );
              pinyin_list.clear();
              phrase_list.clear();
              freq_list.clear();
              process_index = 0;
              idle = null;
              return false;
            }
            return true;
        });
        idle.attach(icp.main_loop.get_context());
      }

      public static void init() {
        pinyin_list = new ArrayList<Pinyin.Sequence>();
        phrase_list = new ArrayList<string>();
        freq_list = new ArrayList<double?>();
        idle = null;
      }

      public static void import(string filename) {
        // import a scel file
        File file;
        FileInputStream fs;

        try {
          file = File.new_for_path(filename);
          fs = file.read(null);

          if (!check_segment_md5(fs, 0, 9,"053950cf925005c1f875bd5a3ab70399")
              || !check_segment_md5(fs, 0x1540, 4, 
                "b81f3dd20a5a9956cbcd838e2658cc69")) {
            Frontend.notify("无法导入 scel 文件", "文件格式不兼容", "error");
            return ;
          }
        } catch (Error e) {
          Frontend.notify("无法导入 scel 文件", "无法访问文件 %s\n%s"
              .printf(filename, e.message), "error"
              );
          return;
        }

        // header 
        string title = read_utf16_segment(fs, 0x130, 0x338 - 0x130);
        string type = read_utf16_segment(fs, 0x338, 0x540 - 0x338);
        string description = read_utf16_segment(fs, 0x540, 0xd40 - 0x540);
        string examples = read_utf16_segment(fs, 0xd40, 0x1540 - 0xd40);

        // pinyin map
        var pinyin_map = new HashMap<int, Pinyin.Id>();
        fs.seek(0x1540 + 4, SeekType.SET, null);
        while (true) {
          uint16[] pinyin_header = new uint16[2];
          fs.read((uint8[])pinyin_header, 4, null);

          if (pinyin_header[1] == 0) break;
          if (pinyin_map.has_key((int)pinyin_header[0])) break;

          string pinyin_content = read_utf16_segment(fs, -1,
              (size_t)pinyin_header[1]
              );

          switch (pinyin_content) {
            case "lue": pinyin_content = "lve"; break;
            case "nue": pinyin_content = "nve"; break;
          }
          pinyin_map[(int)pinyin_header[0]] = new Pinyin.Id(pinyin_content);
        }

        // phrase freq stats
        double max_freq = 0;
        double all_freq = 0;
        int phrase_count = 0;

        try {
          // phrases
          fs.seek(0x2628, SeekType.SET, null);
          while (true) {
            int offset = read_uint16(fs) - 1;
            int pinyin_count = read_uint16(fs) / 2;

            // pinyins
            var pinyins = new ArrayList<Pinyin.Id>();
            for (int i = 0; i < pinyin_count; i++) {
              uint16 pinyin_id = read_uint16(fs);
              pinyins.add(pinyin_map[pinyin_id]);
            }

            // phrase content
            int phrase_len = read_uint16(fs);
            string phrase = read_utf16_segment(fs, -1, (size_t)phrase_len);

            // freq
            size_t freq_len = 12 + offset * (12 + pinyin_count * 2 + 2);

            uint8[] freq_data = new uint8[freq_len];
            fs.read((uint8[]) freq_data, freq_len, null);

            double freq = 0;
            double freq_base = 1;

            for (int i = 2; i <= 3; i++) {
              freq += freq_base * freq_data[i];
              freq_base *= 256;
            }
            freq_list.add(freq);
            pinyin_list.add(new Pinyin.Sequence.ids(pinyins));
            phrase_list.add(phrase);

            phrase_count ++;
            if (freq > max_freq) max_freq = freq;
            all_freq += freq;
          }
        } catch (IOError.NO_MORE_CONTENT e) {
          // rewrite freqs
          double factor = 10000.0 / (max_freq + all_freq / phrase_count);
          int freq_list_index = freq_list.size;
          for (int i = 0; i < phrase_count; i++) {
            if (--freq_list_index < 0) break;
            double freq = freq_list[freq_list_index];
            freq_list[freq_list_index] = freq * factor;
          }

          Frontend.notify("正在后台导入 scel 词库: %s".printf(title),
              "词条数: %d\n类别: %s\n描述: %s".printf(phrase_count, 
                type, description
                ), 
              Config.program_main_icon
              );
          // start to insert phrases into user database
          set_idle_source();

        } catch (Error e) {
          Frontend.notify("无法导入 scel 文件", "无法访问文件 %s\n%s"
              .printf(filename, e.message), "error"
              );
        }
      }

      static bool check_segment_md5(FileInputStream fs, 
          int64 offset, size_t size, string md5) {
        var sum = new Checksum(ChecksumType.MD5);
        try {
          if (!fs.seek(offset, SeekType.SET, null)) return false;
          char[] bytes = new char[size];
          if (fs.read(bytes, size, null) != size) return false;
          sum.update((uchar[])bytes, size);

          return (sum.get_string() == md5);
        } catch (Error e) {
          return false;
        }
      }

      static uint16 read_uint16(FileInputStream fs) throws IOError {
        uint16[] data = new uint16[1];
        if (fs.read((uint8[])data, 2, null) == 0)
          throw new IOError.NO_MORE_CONTENT("read nothing");
        return data[0];
      }

      static string read_utf16_segment(FileInputStream fs, int64 offset = -1, 
          size_t size = 2) throws IOError {
        string result = "";
        try {
          if (offset > 0) {
            if (!fs.seek(offset, SeekType.SET, null)) return result;
          }
          char[] bytes = new char[size + 1];
          if (fs.read(bytes, size, null) != size) {
            throw new IOError.NO_MORE_CONTENT("read nothing");
          }
          bytes[size] = 0;
          // convert UTF-16 to UTF-8
          // since (string)bytes is a raw, plain cast. no problem here
          result = GLib.convert((string)bytes, (ssize_t)size,
              "UTF-8", "UTF-16LE"
              );
        } catch (ConvertError e) {
          warning("Encoding convert error in scel file");
          result = "";
        } catch (Error e) {
          result = "";
        } 
        return result;
      }
    } // class ScelTool


    // server dbus object
    // keep this server only running by main process
    // must not fork() in thread excuting glib main loop in main process 
    [DBus (name = "org.ibus.CloudPinyin")]
      public class CloudPinyin : Object {

        // key interface for child processes to call
        public bool cloud_set_response(string pinyins, string content, 
            int priority) {
          return set_response(pinyins, content, priority);
        }

        // other programs use ...
        public string cloud_try_query(string pinyins) {
          return DBusBinding.query(pinyins);
        }

        public string convert(string pinyins) {
          return DBusBinding.convert(new Pinyin.Sequence(pinyins));
        }

        public void local_remember_phrase(string phrase) {
          Pinyin.Sequence sequence;
          Database.reverse_convert(phrase, out sequence);
          Database.insert(phrase, sequence);
        }

        public string local_reverse_convert(string content) {
          Pinyin.Sequence ps;
          Database.reverse_convert(content, out ps);
          return ps.to_string();
        }

        public void import_scel(string filename) {
          ScelTool.import(filename);
        }
      }

    // for server init
    public static void init() {
      responses = new HashMap<string, Response>();

      try {
        conn = DBus.Bus.get(DBus.BusType.SESSION);
        bus = conn.get_object("org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus");

        uint request_name_result
          = bus.request_name("org.ibus.CloudPinyin", (uint) 0);

        if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER) {
          server = new CloudPinyin ();
          conn.register_object ("/org/ibus/CloudPinyin", server);
        } else {
          stderr.printf("FATAL: register DBus fail!\n"
              + "Please do not run this program multi times manually.\n");
          assert_not_reached();
        }
      } catch (GLib.Error e) {
        stderr.printf("Error: %s\n", e.message);
      }

      ScelTool.init();
    } // init
  }
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
