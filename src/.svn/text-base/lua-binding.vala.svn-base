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

using Lua;
using Gee;

namespace icp {
  class LuaBinding {
    private static LuaVM vm;
    private static ThreadPool thread_pool;
    private static Gee.LinkedList<string> script_pool;

    private static HashMap<string, CloudEngine> engines;

    public static int get_engine_count() {
      return engines.size;
    }

    public static int get_engine_speed_rank(int low = 0, int high = 4) {
      double rank_best = 1;
      foreach (CloudEngine engine in engines.values) {
        double rank = engine.response_time_rank;
        if (rank < rank_best) rank_best = rank;
      }
      int r = low + (int)Math.floor((high - low + 1) * (1 - rank_best));
      if (r > high) r = high;
      if (r < low) r = low;
      return r;
    }

    public static void show_engine_speed_rank() {
      if (engines.size == 0) return;
      string content = "平均响应时间(仅成功请求):";
      foreach (var i in engines) {
        content += "\n    %s: ".printf(i.key);
        if (i.value.response_count == 0) content += "N/A";
        else 
        content += "%.3f s".printf(i.value.response_time 
          / i.value.response_count
          );
      }
      content += "\n采用次数:";
      foreach (var i in engines) {
        content += "\n    %s: %d".printf(i.key, i.value.response_count);
      }
      Frontend.notify("网络请求数据", content, Config.program_main_icon);
    }

    // only in_configuration = true, can some settings be done.
    // this provides extended thread safty.
    // main glib loop will be delayed ~0.1s. in this time, global
    // configuration should make all settings done...
    // i hate locks ...
    private static bool in_configuration;

    class CloudEngine {
      public double response_time_rank;
      public int response_count;
      public double response_time;
      //{ get; private set; }
      public int priority { get; private set; }
      public string script { get; private set; }

      public CloudEngine(string script, int priority = 1) {
        this.priority = priority;
        this.script = script;
        response_time_rank = 2;
        response_count = 0;
        response_time = 0;
      }

      public void update_response_time_rank(double time, 
          bool successful = true,
          double timeout = 3 
          ) {
        // hardcoded 3 sec here:
        double t = time / 3; 
        // make t between 1 (high delay) and 0 (best)
        if (t > 1) t = 1;
        if (t < 0) t = 0; 
        // lowest rank when fail
        if (!successful) t = 1;
        // do not record fail or timeout in low-timeout request
        if (t < 1 || timeout > 3) {
          lock(response_time_rank) {
            if (response_time_rank > 1)
              response_time_rank = t;
            else
              response_time_rank = response_time_rank * 0.9 + t * 0.1;
          }
        }
        if (successful) {
          response_time += time;
          response_count ++;
        }
      }
    }

    private static HashMap<long, RequestStatus> pid_to_request_status;

    class RequestStatus {
      double start_time;
      CloudEngine* pengine;

      public Pid pid;
      public int id { get; private set; }
      public bool done;

      RequestGroup group;
      CloudEngine engine;

      public RequestStatus(RequestGroup group, CloudEngine engine,
          int status_id) {

        // id, done will be read from RequestGroup
        id = status_id;
        done = false;

        this.group = group;
        this.engine = engine;

        string[] argv = {
          Config.program_request,
          "-c", "%s".printf(engine.script),
          "-r", "%s".printf(group.pinyins),
          "-p", "%d".printf(engine.priority),
          "-t", "%f".printf(group.timeout)
        };

        start_time = Database.get_atime();
        if (group.highest_priority < engine.priority)
          group.highest_priority = engine.priority;

        // time out is controlled by child process
        // to restrict timeout, only spawn self, provide only
        // dbus api to lua script

        try {
          Process.spawn_async(null, argv, null, 
              SpawnFlags.DO_NOT_REAP_CHILD, null, out this.pid
              );

          // put pid - status pair for later lookup
          pid_to_request_status[pid] = this;

          ChildWatch.add(pid, (p, status) => {
              bool successful = (status == 0);

              // since directly access class variables will cause
              // segmentational fault. here a map is used to help
              // locate related RequestStatus class by pid(p)
              assert(pid_to_request_status.has_key(p));
              RequestStatus rs = pid_to_request_status[p];
              pid_to_request_status.unset(p);

              assert(rs.pid == p);

              // do not count failure of requests being killed
              if (status != 15) {
              rs.engine.update_response_time_rank(
                (Database.get_atime() - rs.start_time) * 3600 * 24,
                successful,
                rs.group.timeout
                );
              }

              // stop other requests in same group if this is enough
              rs.group.notify_done(rs.id, (successful 
                  && rs.engine.priority == rs.group.highest_priority)
                );
              Process.close_pid(p);
              }
              );
        } catch (SpawnError e) {
          stderr.printf("ERROR: Can not spawn self to send request: '%s'\n",
              group.pinyins
              );
        }
      }
    }

    class RequestGroup {
      public bool* done;
      public bool can_clean;
      public int highest_priority;
      public string pinyins;
      public double timeout;

      public ArrayList<RequestStatus> status_list;

      public RequestGroup(string pinyins, double timeout, bool* done) {
        this.done = done;
        this.pinyins = pinyins.replace("ü", "v");
        *(this.done) = false;
        this.timeout = timeout;
        can_clean = false;

        highest_priority = 0;
        status_list = new ArrayList<RequestStatus>();

        int id = 0;
        foreach (CloudEngine engine in LuaBinding.engines.values) {
          status_list.add(new RequestStatus(this, engine, ++id));
        }
      }

      public void notify_done(int id, bool stop_others = false) {
        // lock (status_list) {
        // scan list and mark as done
        int done_count = 0;
        foreach(RequestStatus i in status_list) {
          if (i.id == id) i.done = true;
          if (i.done) done_count++;
          else if (stop_others) Posix.kill(i.pid, 15);
        }
        // all done ?
        if (done_count == status_list.size) {
          *done = true;
          can_clean = true;
        }
      }
      // }
    }

    private static ArrayList<RequestGroup> request_group;

    public static void start_requests(string pinyins, double timeout,
        bool* done) {
      // clean request_group if it should be cleaned
      // no need to lock since no multi threads indeed
      // lock (request_group) {
      bool can_clean = true;
      foreach (RequestGroup r in request_group) {
        if (r.can_clean == false) {
          can_clean = false;
          break;
        }
      }
      if (can_clean) {
        request_group.clear();
      }
      request_group.add(new RequestGroup(pinyins, timeout, done));
      // }
    }

    private LuaBinding() {
      // this class is used as namespace
    }

    private static bool check_permissions(
      bool should_in_configuration = true
      ) {
      if (should_in_configuration && !in_configuration) {
        Frontend.notify("No permission", 
            "Configurations must be done in startup script.", 
            "stop"
            );
        return false;
      }
      return true;
    }

    private static int l_get_selection(LuaVM vm) {
      // lock is no more needed because only one thread per process
      // use this lua vm. however this thread is not main glib loop
      // lock(vm_lock) {
      vm.check_stack(1);
      vm.push_string(icp.Frontend.get_selection());
      return 1;
      // }
    }
    
    private static int l_set_cutting_adjust(LuaVM vm) {
      if (!check_permissions()) return 0;
      // take an string and push it to icp.Pinyin.cutting_adjusts
      if (vm.is_string(1)) {
        string cutting_adjust = vm.to_string(1);
        Pinyin.cutting_adjusts[cutting_adjust.replace(" ", "")] 
          = cutting_adjust;
      }
      return 0;
    }

    private static int l_notify(LuaVM vm) {
      if (vm.is_string(1)) {
        string title = vm.to_string(1);
        string content = "", icon = "";
        if (vm.is_string(2)) content = vm.to_string(2);
        if (vm.is_string(3)) icon = vm.to_string(3);
        icp.Frontend.notify(title, content, icon);
      }
      // IMPROVE: use lua_error to report error
      return 0;
    }

    private static int l_set_response(LuaVM vm) {
      if (!check_permissions()) return 0;
      if (vm.is_string(1) && vm.is_string(2)) {
        string pinyins = vm.to_string(1);
        string content = vm.to_string(2);
        // high priority, user set.
        int priority = 128;
        if (vm.is_number(3)) priority = vm.to_integer(3);
        DBusBinding.set_response(pinyins, content, priority);
      }
      return 0;
    }

    private static int l_set_color(LuaVM vm) {
      if (!check_permissions()) return 0;
      if (!vm.is_table(1)) return 0;

      vm.check_stack(2);
      for (vm.push_nil(); vm.next(1) != 0; vm.pop(1)) {
        // format: 'name' = '[fgcolor],[bgcolor],[1/0]'
        if (!vm.is_string(-1) || !vm.is_string(-2)) continue;

        string k = vm.to_string(-2);
        string v = vm.to_string(-1);

        int i = 0;
        bool underlined = false;
        int? foreground = null;
        int? background = null;

        foreach (string s in v.split(",")) {
          int t = -1;
          s.scanf("%x", &t);
          switch (i) {
            case 0:
              if (t != -1) foreground = t;
              break;
            case 1:
              if (t != -1) background = t;
              break;
            case 2:
              underlined = (t > 0);
              break;
          }
          i++;
        }

        switch(k) {
          case "buffer_raw":
            Config.Colors.buffer_raw
            = new Config.Colors.Color(foreground, background, underlined);
          break;
          case "buffer_pinyin":
            Config.Colors.buffer_pinyin
            = new Config.Colors.Color(foreground, background, underlined);
          break;
          case "candidate_local":
            Config.Colors.candidate_local
            = new Config.Colors.Color(foreground, background, underlined);
          break;
          case "candidate_remote":
            Config.Colors.candidate_remote
            = new Config.Colors.Color(foreground, background, underlined);
          break;
          case "preedit_correcting":
            Config.Colors.preedit_correcting
            = new Config.Colors.Color(foreground, background, underlined);
          break;            
          case "preedit_local":
            Config.Colors.preedit_local
            = new Config.Colors.Color(foreground, background, underlined);
          break;
          case "preedit_remote":
            Config.Colors.preedit_remote
            = new Config.Colors.Color(foreground, background, underlined);
          break;
          case "preedit_fixed":
            Config.Colors.preedit_fixed
            = new Config.Colors.Color(foreground, background, underlined);
          break;
        }
      }

      return 0;
    }

    private static int l_set_switch(LuaVM vm) {
      if (!vm.is_table(1)) return 0;

      vm.check_stack(2);
      // traverse that table (at pos 1)
      for (vm.push_nil(); vm.next(1) != 0; vm.pop(1)) {
        if (!vm.is_boolean(-1) || !vm.is_string(-2)) continue;

        string k = vm.to_string(-2);
        bool v = vm.to_boolean(-1);
        bool* bind_value = null;

        switch(k) {
          case "double_pinyin":
            bind_value = &Config.Switches.double_pinyin;
          break;
          case "background_request":
            bind_value = &Config.Switches.background_request;
          break;
          case "always_show_candidates":
            bind_value = &Config.Switches.always_show_candidates;
          break;
          case "show_pinyin_auxiliary":
            bind_value = &Config.Switches.show_pinyin_auxiliary;
          break;
          case "show_raw_in_auxiliary":
            bind_value = &Config.Switches.show_raw_in_auxiliary;
          break;            
          case "default_offline_mode":
            bind_value = &Config.Switches.default_offline_mode;
          break;
          case "default_chinese_mode":
            bind_value = &Config.Switches.default_chinese_mode;
          break;
          case "default_traditional_mode":
            bind_value = &Config.Switches.default_traditional_mode;
          break;
        }
        *bind_value = v;
      }

      return 0;
    }

    private static int l_set_timeout(LuaVM vm) {
      if (!vm.is_table(1)) return 0;

      vm.check_stack(2);
      // traverse that table (at pos 1)
      for (vm.push_nil(); vm.next(1) != 0; vm.pop(1)) {
        if (!vm.is_number(-1) || !vm.is_string(-2)) continue;

        string k = vm.to_string(-2);
        double v = vm.to_number(-1);
        double* bind_value = null;

        switch(k) {
          case "request":
            bind_value = &Config.Timeouts.request;
          break;
          case "prerequest":
            bind_value = &Config.Timeouts.prerequest;
          break;
          case "selection":
            bind_value = &Config.Timeouts.selection;
          break;
        }
        *bind_value = v;
      }

      return 0;
    }

    private static int l_set_limit(LuaVM vm) {
      if (!vm.is_table(1)) return 0;

      vm.check_stack(2);
      // traverse that table (at pos 1)
      for (vm.push_nil(); vm.next(1) != 0; vm.pop(1)) {
        if (!vm.is_number(-1) || !vm.is_string(-2)) continue;

        string k = vm.to_string(-2);
        int v = vm.to_integer(-1);
        int* bind_value = null;

        switch(k) {
          case "db_query_limit":
            bind_value = &Config.Limits.db_query_limit;
          break;
          case "prerequest_retry_limit":
            bind_value = &Config.Limits.prerequest_retry_limit;
          break;
          case "request_retry_limit":
            bind_value = &Config.Limits.request_retry_limit;
          break;
          case "cloud_candidates_limit":
            bind_value = &Config.Limits.cloud_candidates_limit;
          break;
        }
        *bind_value = v;
      }

      return 0;
    }

    private static int l_set_double_pinyin(LuaVM vm) {
      if (!check_permissions()) return 0;
      Pinyin.DoublePinyin.clear();

      if (!vm.is_table(1)) return 0;

      int vm_top = vm.get_top();
      vm.check_stack(2);
      // traverse that table (at pos 1)
      for (vm.push_nil(); vm.next(1) != 0; vm.pop(1)) {
        // key is at index -2 and value is at index -1
        if (!vm.is_string(-1) || !vm.is_string(-2)) continue;

        string double_pinyin = vm.to_string(-2);
        string full_pinyin = vm.to_string(-1);
        if (double_pinyin.length > 2) continue;
        Pinyin.DoublePinyin.insert(double_pinyin, full_pinyin);
      }
      assert(vm.get_top() == vm_top);

      return 0;
    }

    private static int l_set_key(LuaVM vm) {
      if (!check_permissions()) return 0;

      if (vm.get_top() < 3
        || !(vm.type(1) == Lua.Type.STRING || vm.type(1) == Lua.Type.NUMBER)
          || !vm.is_string(3) || !vm.is_number(2)) return 0;

      uint key_value = 0;
      if (vm.type(1) == Lua.Type.STRING) {
        string s = vm.to_string(1);
        if (s.length > 0) key_value = (uint)s[0];
      } else key_value = (uint)vm.to_integer(1);

      if (key_value == 0) return 0;
      Config.Key key = new Config.Key(key_value, (uint)vm.to_integer(2));
      Config.KeyActions.set(key, vm.to_string(3));
      return 0;
    }

    private static int l_set_candidate_labels(LuaVM vm) {
      if (!check_permissions()) return 0;
      // accept two strings, only one unichar per label
      if (!vm.is_string(1)) return 0;

      string labels = vm.to_string(1);
      string alternative_labels = labels;
      if (vm.is_string(2)) alternative_labels = vm.to_string(2);

      Config.CandidateLabels.clear();
      for (int i = 0; i < labels.length; i++) {
        Config.CandidateLabels.add (labels[i:i+1],
            (i < alternative_labels.length) ? alternative_labels[i:i+1] : null
            );
      }
      return 0;
    }

    private static int l_set_punctuation(LuaVM vm) {
      if (!check_permissions()) return 0;
      if (!(vm.type(1) == Lua.Type.NUMBER || vm.type(1) == Lua.Type.STRING)
       || !vm.is_string(2)) return 0;

      bool only_after_chinese = false;
      if (!vm.is_boolean(3)) only_after_chinese = vm.to_boolean(3);
      
      int half_punc;
      if (vm.type(1) == Lua.Type.NUMBER) half_punc = vm.to_integer(1);
        else {
          string half_punc_str = vm.to_string(1);
          if (half_punc_str.length == 0) return 0;
          half_punc = (int)half_punc_str[0];
        }
      string full_punc = vm.to_string(2);
      Config.Punctuations.set(half_punc, full_punc, only_after_chinese);
      return 0;
    }

    private static int l_register_engine(LuaVM vm) {
      if (!check_permissions()) return 0;
      // TODO: register request engine at Config...
      if (!vm.is_string(1)) return 0;

      string name = vm.to_string(1);
      string script_filename = "";
      if (vm.is_string(2)) script_filename = vm.to_string(2);
      
      int priority = 1;
      if (vm.is_number(3)) priority = vm.to_integer(3);

      if (script_filename.length == 0 || priority <= 0) {
        if (engines.has_key(name)) engines.unset(name);
      } else
        engines[name] = new CloudEngine(script_filename, priority);

      return 0;
    }

    private static int l_commit(LuaVM vm) {
      if (!vm.is_string(1)) return 0;
      string content = vm.to_string(1);
      if (IBusBinding.active_engine != null) {
        var engine = IBusBinding.active_engine;
        if (engine != null) {
          engine.commit(content);
        }
      }
      return 0;
    }

    public static void init() {
      in_configuration = false;
      script_pool = new Gee.LinkedList<string>();
      engines = new HashMap<string, CloudEngine>();
      request_group = new ArrayList<RequestGroup>();
      pid_to_request_status = new HashMap<long, RequestStatus>();

      vm = new LuaVM();
      vm.open_libs();

      vm.check_stack(1);
      vm.push_string(Config.user_config_path);
      vm.set_global("user_config_path");
      vm.push_string(Config.user_data_path);
      vm.set_global("user_data_path");
      vm.push_string(Config.user_cache_path);
      vm.set_global("user_cache_path");
      vm.push_string(Config.global_data_path);
      vm.set_global("data_path");

      vm.register("notify", l_notify);
      vm.register("get_selection", l_get_selection);
      vm.register("commit", l_commit);

      vm.register("set_response", l_set_response);
      vm.register("set_double_pinyin", l_set_double_pinyin);
      vm.register("set_key", l_set_key);
      vm.register("set_candidate_labels", l_set_candidate_labels);
      vm.register("set_punctuation", l_set_punctuation);

      vm.register("set_switch", l_set_switch);
      vm.register("set_timeout", l_set_timeout);
      vm.register("set_limit", l_set_limit);
      vm.register("set_color", l_set_color);

      vm.register("set_cutting_adjust", l_set_cutting_adjust);

      // these engines' requests will be async (in sep process)
      vm.register("register_engine", l_register_engine);

      try {
        thread_pool = new ThreadPool(do_string_internal, 1, true);
      } catch (ThreadError e) {
        stderr.printf("LuaBinding cannot create thread pool: %s\n", 
            e.message
            );
      }

      // load configuration
      load_configuration();
    }

    private static void do_string_internal(void* data) {
      // do not execute other script if being forked
      // prevent executing them two times
      string script = (string)data;

      switch(script) {
        case ".stop_conf":
          in_configuration = false;
        break;
        default:
        vm.load_string(script);
        if (vm.pcall(0, 0, 0) != 0) {
          string error_message = vm.to_string(-1);
          if (error_message != "fork_stop")
            Frontend.notify("Lua Error", error_message, "error");
          vm.pop(1);
        }
        break;
      }
    }

    public static void do_string(string script) {
      // do all things in thread pool
      try {
        // attention: script may be unavailabe after pushed into thread_pool
        // thread_pool.push((void*)script);

        // do some cleanning when possible
        if (thread_pool.unprocessed() == 0) script_pool.clear();

        // push script into script_pool to keep it safe
        script_pool.add(script);
        thread_pool.push((void*)script_pool.last());
      } catch (ThreadError e) {
        stderr.printf(
            "LuaBinding fails to launch thread from thread pool: %s\n",
            e.message);
      }
    }

    public static void load_configuration() {
      in_configuration = true;
      do_string("dofile([[%s]])".printf(
            Config.CommandlineOptions.startup_script)
          );
      do_string(".stop_conf");
    }
  }
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
