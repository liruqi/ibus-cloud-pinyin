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

using IBus;
using Gee;

namespace icp {
  class IBusBinding {
    // for connection
    private static EngineDesc engine;
    private static Component component;
    private static IBus.Bus bus;
    private static Factory factory;

    // active engine
    public static CloudPinyinEngine active_engine;

    // constants
    public static const uint key_state_filter
      = ModifierType.SHIFT_MASK | ModifierType.LOCK_MASK
      | ModifierType.CONTROL_MASK | ModifierType.MOD1_MASK
      | ModifierType.MOD4_MASK | ModifierType.MOD5_MASK
      | ModifierType.SUPER_MASK | ModifierType.RELEASE_MASK
      | ModifierType.META_MASK;

    public class CloudPinyinEngine : Engine {
      private string raw_buffer = "";
      private Pinyin.Sequence pinyin_buffer;
      private string pinyin_buffer_preedit;

      // engine states
      private bool chinese_mode;
      private bool correction_mode = false;
      private bool offline_mode;
      private bool traditional_mode;
      private bool last_is_chinese = true;

      // pending segments
      class PendingSegment {
        public bool done;
        // if done = true, then use content
        // otherwise use pinyins and request is not
        // done yet (when pinyins != null)
        public string content;
        public Pinyin.Sequence pinyins;
        public int retry;

        // no timeout control at this level
        public PendingSegment.from_content(string content) {
          this.content = content;
          pinyins = null;
          done = true;
          retry = 0;
        }
        public PendingSegment.from_pinyins(Pinyin.Sequence pinyins) {
          content = null;
          this.pinyins = new Pinyin.Sequence.copy(pinyins);
          // allow another request
          done = true;
          retry = Config.Limits.request_retry_limit;
        }
      }

      LinkedList<PendingSegment> pending_segment_list;

      // only one prerequest per engine allowed
      bool prerequest_done;

      // lookup table and candidates
      LookupTable table;
      int cloud_candidate_count = 0;
      bool table_visible;
      uint page_index;

      // panel icons
      private Property chinese_mode_icon
        = new Property("mode", PropType.NORMAL, null,
            Config.global_data_path + "/icons/pinyin-enabled.png", 
            new Text.from_string("切换中文/英文模式"),
            true, true, PropState.INCONSISTENT, null);
      private Property traditional_conversion_icon
        = new Property("trad", PropType.NORMAL, null,
            Config.global_data_path + "/icons/traditional-disabled.png", 
            new Text.from_string("切换简体/繁体模式"),
            false, true, PropState.INCONSISTENT, null);
      private Property status_icon 
        = new Property("status", PropType.NORMAL, null, 
            Config.global_data_path + "/icons/idle-0.png",
            new Text.from_string("切换在线/离线模式"),
            true, true, PropState.INCONSISTENT, null);
      private Property tools_icon 
        = new Property("tools", PropType.MENU, null, 
            Config.global_data_path + "/icons/tools.png",
            new Text.from_string("工具菜单"),
            true, true, PropState.INCONSISTENT, null);
      private Property tools_status_item
        = new Property("tools_status", PropType.NORMAL, 
            new Text.from_string("查看网络请求数据"),
            null, null,
            true, true, PropState.INCONSISTENT, null);
      private Property tools_scel_import_item
        = new Property("tools_scel_import", PropType.NORMAL, 
            new Text.from_string("导入 scel 词库"),
            null, null,
            true, true, PropState.INCONSISTENT, null);
      private PropList tools_menu_list = new PropList();
      private PropList panel_prop_list = new PropList();
      private TimeoutSource waiting_animation_timer = null;

      // used by update_properties() and waiting_animation_timer callback func
      // they should be static vars in func,
      // however Vala does not seems to support static vars
      // at the time I write these code ...
      private bool last_chinese_mode = true;
      private bool last_traditional_mode = false;
      private bool last_offline_mode = false;

      // idle animation start and stop
      private int waiting_index = 0;
      private int waiting_index_acc = 1;
      private int waiting_subindex = 0;

      private bool last_prerequest_done;
      private void start_requesting() {
        if (waiting_animation_timer != null) return;
        waiting_animation_timer = new TimeoutSource(64);
        waiting_animation_timer.set_callback(() => {
            // send another prerequest if current one is done
            if (prerequest_done && !last_prerequest_done) {
              send_prerequest();
              last_prerequest_done = prerequest_done;
              update_preedit();
            }
            if (process_pending_list()) {
              update_preedit();
            }
            // update status icon
            string icon_path;
            if (waiting_subindex > 1) {
            waiting_subindex = 0;
            if (pending_segment_list.size == 0 && prerequest_done) {
              icon_path = "%s/icons/idle-%d.png".printf(
                Config.global_data_path, 
                LuaBinding.get_engine_speed_rank()
                );
            } else {
              waiting_index += waiting_index_acc;
              if (waiting_index == 3 || waiting_index == 0)
                waiting_index_acc = - waiting_index_acc;
              icon_path = "%s/icons/waiting-%d.png".printf(
                Config.global_data_path, waiting_index
                );
            }
            // update that icon
            if (icon_path != status_icon.icon) {
              status_icon.set_icon(icon_path);
              update_property(status_icon);
            }
            // stop if offline mode
            } else waiting_subindex ++;
            if (offline_mode) stop_requesting();
            return true;
        });
        waiting_animation_timer.attach(icp.main_loop.get_context());
      }

      private void stop_requesting() {
        force_commit_pending_list();
        if (waiting_animation_timer == null) return;
        if (!waiting_animation_timer.is_destroyed())
          waiting_animation_timer.destroy();
        waiting_animation_timer = null;
        update_preedit();
        update_candidates();
      }

      // init, workaround for no ctor
      private bool inited = false;

      private void init() {
        // strings, booleans
        raw_buffer = "";
        last_pinyin_buffer_string = "";
        pinyin_buffer = new Pinyin.Sequence(raw_buffer);
        table_visible = false;

        // switches
        chinese_mode = Config.Switches.default_chinese_mode;
        traditional_mode = Config.Switches.default_traditional_mode;
        offline_mode = Config.Switches.default_offline_mode;
        if (LuaBinding.get_engine_count() == 0) offline_mode = true;
        correction_mode = false;

        // load properties into property list
        tools_menu_list.append(tools_status_item);
        tools_menu_list.append(tools_scel_import_item);
        tools_icon.set_sub_props(tools_menu_list);
        panel_prop_list.append(chinese_mode_icon);
        panel_prop_list.append(traditional_conversion_icon);
        panel_prop_list.append(status_icon);
        panel_prop_list.append(tools_icon);
        waiting_animation_timer = null;

        // timeouts
        prerequest_retry = Config.Limits.prerequest_retry_limit;

        // lookup table, insert enough dummy labels first
        page_index = 0;
        table = new LookupTable(Config.CandidateLabels.size, 0, false, false);
        var candidates = new ArrayList<string>();
        for (int i = 0; i < Config.CandidateLabels.size; i++) {
          table.append_label(new Text.from_string("."));
        }

        // user phrase
        user_pinyins = new ArrayList<Pinyin.Id>();
        user_phrase = "";

        // request list and pending segment list
        pending_segment_list = new LinkedList<PendingSegment>();
        prerequest_done = true;
        last_prerequest_done = false;

        // start animations
        if (!offline_mode) start_requesting();

        // TODO: dlopen opencc ...
        inited = true;

        // update properties now
        update_properties();
      }

      private void force_commit_pending_list() {
        commit_buffer();
        foreach (PendingSegment seg in pending_segment_list) {
          if (seg.content != null) {
            commit_text(new Text.from_string(seg.content));
            seg.content = null;
          } else if (seg.pinyins != null) {
            string content = DBusBinding.convert(seg.pinyins, offline_mode);
            commit_text(new Text.from_string(content));
            seg.pinyins = null;
          }
        }
      }

      // return whether preedit should be updated
      private bool process_pending_list() {
        bool preedit_should_update = false;
        bool first_items = true;
        int committed_item_count = 0;
        foreach (PendingSegment seg in pending_segment_list) {
          // seg.done == false means requesting, just do nothing
          if (!seg.done) {
            first_items = false;
            continue;
          }
          // check existing cloud response
          if (seg.content == null && seg.pinyins != null) {
            string content = DBusBinding.query(seg.pinyins.to_string());
            if (content.size() > 0) {
              seg.content = content;
              // only keep content
              seg.pinyins = null;
            }
          }
          // retry limit exceed ?
          if (seg.pinyins != null && seg.retry <= 0) {
            // force convert
            seg.content = DBusBinding.convert(seg.pinyins, offline_mode);
            seg.pinyins = null;
          }
          if (seg.pinyins == null) {
            // mark as to be committed
            // seg.content may be null
            if (first_items) committed_item_count ++;
            continue;
          }
          first_items = false;
          if (seg.content == null) {
            preedit_should_update = true;
            // send request about pinyins
            // check retry
            seg.done = false;
            LuaBinding.start_requests(seg.pinyins.to_string(),
                Config.Timeouts.request,
                &(seg.done)
                );
            seg.retry --;
          }
        } // foreach

        // commit first committed_item_count items and delete them
        if (committed_item_count > 0) {
          preedit_should_update = true;
          LinkedList<PendingSegment> head_segs = 
            new LinkedList<PendingSegment>();
          pending_segment_list.drain_head(head_segs, committed_item_count);

          foreach (PendingSegment seg in head_segs) {
            if (seg.content != null)
              commit_text(new Text.from_string(seg.content));
          }
        }
        return preedit_should_update;
      }

      private int prerequest_retry;
      private string last_prerequest_pinyins = "";
      private void send_prerequest() {
        if (offline_mode || !prerequest_done) return;
        // scan to a complete pinyin
        int i = pinyin_buffer.size - 1;

        // try not send request when user is typing (pinyin not complete)
        if (pinyin_buffer.get_id(i).vowel <= 0) i--;
        if (i <= 0) return;

        string pinyins = pinyin_buffer.to_string(0, i + 1);
        if (last_prerequest_pinyins != pinyins) {
          prerequest_retry = Config.Limits.prerequest_retry_limit;
          last_prerequest_pinyins = pinyins;
        }
        if (DBusBinding.query(pinyins) == "" 
            && prerequest_retry > 0) {
          prerequest_retry--;
          prerequest_done = false;
          LuaBinding.start_requests(
              pinyins,
              Config.Timeouts.prerequest,
              &prerequest_done
              );
          start_requesting();
        }
      }

      public override void reset() {

      }

      public override void enable() {
        enabled = true;
        if (!inited) init();
        update_properties();
      }

      public override void disable() {
        enabled = false;
        stdout.printf("called disable\n");
      }

      public override void focus_in() {
        has_focus = true;
        if (!inited) init();
        register_properties(panel_prop_list);
        update_properties();
        update_preedit();
        // force update candidates
        last_pinyin_buffer_string = ".";
        update_candidates();
        active_engine = this;
      }

      public override void focus_out() {
        force_commit_pending_list();
        has_focus = false;
        active_engine = null;
      }

      public override void property_activate(string prop_name, 
          uint prop_state) {
        switch (prop_name) {
          case "mode":
            chinese_mode = !chinese_mode;
          break;
          case "trad":
            traditional_mode = !traditional_mode;
          break;
          case "status":
            switch_offline_mode();
          break;
          case "tools_scel_import":
            string[] argv = { Config.program_scel_import };
            Pid pid;
            Process.spawn_async(null, argv, null, 0, null, out pid);
            Process.close_pid(pid);
          break;
          case "tools_status":
            LuaBinding.show_engine_speed_rank();
          break;
        }
        update_properties();
      }

      private bool is_pending_segment_list_empty() {
        bool r = true;
        foreach (PendingSegment seg in pending_segment_list) {
          if (seg.content != null || seg.pinyins != null) {
            r = false;
            break;
          }
        }
        return r;
      }

      public void commit(string content) {
        if (content.length > 0) {
          Frontend.clear_selection();
          if (is_pending_segment_list_empty())
            commit_text(new Text.from_string(content));
          else {
            pending_segment_list.add(new
                PendingSegment.from_content(content)
                );
            process_pending_list();
          }
        }
      }

      // call this if background_request is enabled and not in offline mode
      private void commit_pinyins(Pinyin.Sequence pinyins) {
        if (pinyins.size > 0) {
          pending_segment_list.add(
              new PendingSegment.from_pinyins(pinyins)
              );
          process_pending_list();
        }
      }

      private void switch_offline_mode() {
        offline_mode = !offline_mode;
        if (!offline_mode) {
          if (LuaBinding.get_engine_count() == 0) {
            Frontend.notify(
                "在线模式",
                "无法切换到在线模式\n没有注册过云请求脚本", 
                "error"
                );
            offline_mode = true;
          } else {
            start_requesting();
          }
        } else {
          stop_requesting();
        }
      }

      private void commit_buffer() {
        if (pinyin_buffer.size > 0) {
          if (Config.Switches.background_request && !offline_mode)
            commit_pinyins(pinyin_buffer);
          else
            commit(pinyin_buffer_preedit);
          last_is_chinese = true;
        }
        clear_buffer();
      }

      private void clear_buffer() {
        raw_buffer = "";
        user_phrase_clear();
        pinyin_buffer.clear();
      }

      // process key event, most important func in engine
      private uint last_state = 0;
      public override bool process_key_event(uint keyval, uint keycode, 
          uint state) {
        bool handled = false;
        state = state & key_state_filter;

        string action;
        // prevent trigger unwanted hotkeys
        if (((state & ModifierType.RELEASE_MASK) != 0)
            && ((last_state & ModifierType.RELEASE_MASK) != 0))
          action = "";
        else action = Config.KeyActions.get(
            new Config.Key(keyval, state)
            );
        last_state = state;

        do {
          // this loop is dummy onlyto enable 'break' for flow control
          if (action.has_prefix("lua:")) {
            // it is a lua script, execute in background
            LuaBinding.do_string(action[4:action.length]);
            handled = true;
            break;
          }

          // otherwise user may specify multi actions seperated by space
          // collect them into a set
          HashSet<string> actions = new HashSet<string>();
          foreach (string v in action.split(" ")) actions.add(v);

          // consider mode switch action first
          if ((chinese_mode == false && ("chs" in actions))
              || (chinese_mode == true && ("eng" in actions))) {
            // TODO: do something here
            chinese_mode = !chinese_mode;
            if (chinese_mode) last_is_chinese = true;
            handled = true; break;
          }

          if ((traditional_mode && ("simp" in actions))
              || (!traditional_mode && ("trad" in actions))) {
            traditional_mode = !traditional_mode;
            handled = true; break;
          }

          if ((offline_mode && ("online" in actions))
              || (!offline_mode && ("offline" in actions))) {
            switch_offline_mode();
            handled = true; break;
          }

          // then in chinese mode, consider edit / commit things
          // edit raw pinyin buffer (disabled in correction mode)
          // handle "sep", "back", "clear" here
          if (chinese_mode) {
            // enter correction mode ?
            if (!correction_mode && "correct" in actions) {
              // changed > 0 to > 1
              if (raw_buffer.length > 1) {
                if (pinyin_buffer.size > 0 
                  && pinyin_buffer.get_id(0).vowel > 0) {
                  correction_mode = true;
                  handled = true; break;
                }
              } else {
                // user select some thing, currently buffer is empty,
                // test if it can be reverse converted to pinyin
                if (Frontend.get_current_time()
                    <= (uint64)(1000000 * Config.Timeouts.selection)
                    + Frontend.clipboard_update_time
                    && is_pending_segment_list_empty()) {
                  string selection = Frontend.get_selection();
                  if (!selection.contains("\n")
                      && Database.reverse_convert(
                        selection, out pinyin_buffer)) {
                    // reverse convert successful
                    // erase client text
                    commit_text(new Text.from_string(""));
                    correction_mode = true;
                    // rebuild raw_buffer
                    if (Config.Switches.double_pinyin) {
                      raw_buffer = pinyin_buffer.to_double_pinyin_string();
                    } else {
                      raw_buffer = pinyin_buffer.to_string();
                    }
                    handled = true; break;
                  } else {
                    // convert fail, clean buffers
                    pinyin_buffer = new Pinyin.Sequence();
                  }
                }
              }
            } // if to enter correction mode

            if (!correction_mode && raw_buffer.length > 0 
              && "clear" in actions) {
              clear_buffer();
              handled = true; break;
            }

            // check normal pinyin chars, only in non correction mode
            if (!correction_mode) {
              bool is_backspace = (("back" in actions) 
                  && raw_buffer.length > 0
                  );

              if (Config.Switches.double_pinyin) {
                // note that ';' can not occur at the beginning
                if ((Pinyin.DoublePinyin.is_valid_key(keyval)
                      && state == 0 && ('z' >= keyval >= 'a'
                        || raw_buffer.length > 0)) || is_backspace) {
                  if (is_backspace) raw_buffer = raw_buffer[0:-1];
                  else raw_buffer += "%c".printf((int)keyval);
                  Pinyin.DoublePinyin.convert(raw_buffer, out pinyin_buffer);
                  handled = true; break;
                }
              } else {
                if (('z' >= keyval >= 'a'
                      && state == 0) || is_backspace) {
                  if (is_backspace) raw_buffer = raw_buffer[0:-1];
                  else raw_buffer += "%c".printf((int)keyval);
                  pinyin_buffer = new Pinyin.Sequence(raw_buffer);
                  handled = true; break;
                }
                if (("sep" in actions) && raw_buffer.length > 0 
                    && (uint)raw_buffer[raw_buffer.length - 1] != keyval) {
                  raw_buffer += "%c".printf((int)keyval);
                  handled = true; break;
                }
              }
            } // edit pinyin buffer (backspace, escape, append)

            // consider candidate select
            // lookup table pgup, pgdn, candidate select
            // this should work regardless of correction mode
            if (table_visible) {
              if ("pgup" in actions) { page_up(); handled = true;}
              if ("pgdn" in actions) { page_down(); handled = true;}
              if (handled) {
                update_lookup_table(table, true);
                break;
              }

              foreach (string s in actions) {
                if (s.has_prefix("cand:")) {
                  uint index = 0;
                  s.scanf("cand:%u", &index);
                  // check if that candidate exists
                  if (table.get_number_of_candidates() 
                      > table.get_page_size() * page_index + index
                      && Config.CandidateLabels.size > index) {
                    candidate_clicked(index, 128, 0);
                    handled = true;
                  }
                  break;
                }
              }
              if (handled) break;
            }

            // chinese puncs, let it work in correction mode
            if (((state ^ IBus.ModifierType.SHIFT_MASK)
                  == 0 || state == 0)
                && 128 > keyval >= 32 
                && Config.Punctuations.exists((int)keyval)) {

              commit_buffer();
              string punc = Config.Punctuations.get(
                  (int)keyval, last_is_chinese
                  );
              user_phrase_clear();
              commit(punc);
              handled = true; break;
            }

            // disable backspace in correction mode
            if (correction_mode && "back" in actions) {
              handled = true; break;
            }
          }

          // raw commit
          if (("raw" in actions)
              && raw_buffer.length > 0) {
            commit(raw_buffer);
            clear_buffer();
            last_is_chinese = false;
            handled = true; break;
          }

          // commit buffer hotkey
          if (("commit" in actions)
              && pinyin_buffer.size > 0) {
            commit_buffer();
            handled = true; break;
          }

          // backspace in pending_segment_list
          if (("back" in actions) && !is_pending_segment_list_empty() 
              && raw_buffer.length == 0) {
            for (int i = pending_segment_list.size - 1; i >= 0; i--) {
              PendingSegment seg = pending_segment_list.get(i);
              if (seg.content != null) {
                // directly shorten or remove that segment
                if (seg.content.length <= 1) {
                  pending_segment_list.remove_at(i);
                } else {
                  seg.content = seg.content[0:seg.content.length - 1];
                }
                break;
              }
              if (seg.pinyins != null) {
                // mute it (for request will write 'done' information back)
                // reset it to buffer
                Pinyin.Sequence pinyins = new Pinyin.Sequence.copy(
                    seg.pinyins, 0, seg.pinyins.size - 1
                    );
                seg.pinyins = null;
                seg.content = null;
                // put that segment back to buffer
                if (Config.Switches.double_pinyin) {
                  raw_buffer = pinyins.to_double_pinyin_string();
                } else {
                  raw_buffer = pinyins.to_string();
                }
                pinyin_buffer = pinyins;
                break;
              }
            }
            handled = true; break;
          }

          // non-chinese puncs
          // special handle enter, convert it to ASCII 13
          if (((state ^ IBus.ModifierType.SHIFT_MASK)
                == 0 || state == 0)
              && (128 > keyval >= 32 || (keyval == IBus.Return
                  && !is_pending_segment_list_empty()))) {
            commit_buffer();

            if (keyval == IBus.Return) keyval = 13;
            string punc = "%c".printf((int)keyval);
            last_is_chinese = false;
            commit(punc);
            handled = true; break;
          }
        } while (false);

        if (handled) {
          if (!offline_mode) {
            last_prerequest_done = false;
            start_requesting();
          }
          process_pending_list();
          update_preedit();
          update_properties();
          update_candidates();
        }

        return handled;
      }

      private override void page_up() {
        if (table_visible && table.page_up()) {
          update_lookup_table(table, true);
          page_index --;
        }
      }

      private override void page_down() {
        if (table_visible && table.page_down()) {
          update_lookup_table(table, true);
          page_index ++;
        }
      }

      // used to insert to user database
      private ArrayList<Pinyin.Id> user_pinyins;
      private string user_phrase;

      private void user_phrase_clear() {
        user_phrase = "";
        user_pinyins.clear();
      }

      private override void candidate_clicked (uint index, uint button,
          uint state) {

        index += table.get_page_size() * page_index;
        Text candidate = table.get_candidate(index);
        string content = candidate.text;
        int len = (int)content.length;
        commit(content);

        // append to user phrase
        user_phrase += content;
        for (int i = 0; i < content.length; i++)
          user_pinyins.add(pinyin_buffer.get_id(i));

        // insert to user dict, ignore if it is first one in db results
        // but do not ignore if user_phrase is combined from two first one
        // candidates
        var pinyins = new Pinyin.Sequence.ids(user_pinyins);
        if (index != cloud_candidate_count || content != user_phrase) {
          Database.insert(user_phrase, pinyins);
        }

        // also update cloud cache with priority = 128
        DBusBinding.set_response(pinyins.to_string(), user_phrase, 128);

        // remove heading pinyins (rebuild buffer)
        if (Config.Switches.double_pinyin) {
          raw_buffer = pinyin_buffer.to_double_pinyin_string(len);
          Pinyin.DoublePinyin.convert(raw_buffer, 
              out pinyin_buffer);
        } else {
          raw_buffer = pinyin_buffer.to_string(len);
          pinyin_buffer = new Pinyin.Sequence(raw_buffer);
        }

        // clear user phrase buffer when a phrase is complete
        if (raw_buffer.size() == 0) user_phrase_clear();

        // button == 128 means it is called from internal function, and
        // that function will update preedit and candidates.
        if (button != 128) {
          update_preedit();
          update_candidates();
        }
      }

      class ColorSegment {
        Config.Colors.Color color;
        uint start;
        int end;
        public ColorSegment(Config.Colors.Color color, uint start, int end) {
          this.color = color;
          this.start = start;
          this.end = end;
        }
        public void apply(Text text) {
          color.apply(text, start, end);
        }
      }

      private void update_preedit() {
        // auxiliary text
        if (pinyin_buffer.size == 0 
            || (!Config.Switches.show_pinyin_auxiliary 
              && !Config.Switches.show_raw_in_auxiliary
              )) {
          hide_auxiliary_text();
        } else {
          string pinyin_buffer_aux 
            = Config.Switches.show_pinyin_auxiliary 
            ? pinyin_buffer.to_string() : "";
          string raw_buffer_aux
            = Config.Switches.show_raw_in_auxiliary 
            ? " [%s]".printf(raw_buffer) : "";
          var text = new Text.from_string(
              @"$pinyin_buffer_aux$raw_buffer_aux"
              );
          Config.Colors.buffer_pinyin.apply(
              text, 0, (int)pinyin_buffer_aux.length
              );
          Config.Colors.buffer_raw.apply(
              text, (uint)pinyin_buffer_aux.length, 
              (int)(pinyin_buffer_aux.length + raw_buffer_aux.length)
              );
          update_auxiliary_text(text, true);          
        }
        // preedit
        {
          int cloud_length;
          pinyin_buffer_preedit = DBusBinding.convert(
              pinyin_buffer, 
              offline_mode,
              out cloud_length
              );

          var color_list = new ArrayList<ColorSegment>();

          string pending_preedit = "";
          int pending_preedit_length = 0; // (int)pending_preedit.length;
          foreach (PendingSegment seg in pending_segment_list) {
            if (seg.content == null && seg.pinyins != null) {
              // mixed cloud and local
              int cloud_len;
              string content =
                DBusBinding.convert(seg.pinyins, offline_mode,
                    out cloud_len
                    );
              pending_preedit += content;

              color_list.add(new ColorSegment(Config.Colors.preedit_remote,
                    (uint)pending_preedit_length,
                    pending_preedit_length + cloud_len)
                  );
              color_list.add(new ColorSegment(Config.Colors.preedit_local,
                    (uint)(pending_preedit_length + cloud_len),
                    pending_preedit_length + (int)content.length)
                  );
              pending_preedit_length += (int)content.length;
              continue;
            }
            if (seg.content != null) {
              // fixed
              pending_preedit += seg.content;
              color_list.add(new ColorSegment(Config.Colors.preedit_fixed,
                    (uint)pending_preedit_length,
                    pending_preedit_length + (int)seg.content.length)
                  );
              pending_preedit_length += (int)seg.content.length;
              continue;
            }
          }

          string preedit = pending_preedit + pinyin_buffer_preedit;
          var text = new Text.from_string(preedit);

          foreach (ColorSegment i in color_list) {
            i.apply(text);
          }

          // colors
          if (correction_mode)
            Config.Colors.preedit_correcting.apply(text, 
                pending_preedit_length
                );
          else {
            // remote result
            Config.Colors.preedit_remote.apply(text, pending_preedit_length,
                cloud_length + pending_preedit_length
                );
            // local database
            Config.Colors.preedit_local.apply(text, 
                cloud_length + pending_preedit_length
                );
          }

          // apply underline
          text.append_attribute(AttrType.UNDERLINE, 
              AttrUnderline.SINGLE, pending_preedit_length,
              (int)text.get_length()
              );

          update_preedit_text(text,
              correction_mode ? 0 : (int)text.get_length(), preedit.length > 0
              );
        }
      }

      private string last_pinyin_buffer_string;
      private bool last_correction_mode = false;
      private void update_candidates() {
        // update candidates according to pinyin_buffer
        if (pinyin_buffer.size > 0 && 
            (Config.Switches.always_show_candidates || correction_mode)) {
          if (last_pinyin_buffer_string != pinyin_buffer.to_string()
              || last_correction_mode != correction_mode) {

            // should update lookup table now
            var candidates = new ArrayList<string>();
            table.clear();
            page_index = 0;

            // cloud candidates
            cloud_candidate_count = 0;
            if (!offline_mode) {
              int last_cloud_candidate_length = -16;
              string last_cloud_candidate = ".";
              for (int i = 2; i < pinyin_buffer.size
                  && cloud_candidate_count
                  < Config.Limits.cloud_candidates_limit;
                  i ++) {
                string cloud_candidate = DBusBinding.query(
                    pinyin_buffer.to_string(0, i)
                    );
                if (cloud_candidate.size() > 0
                    && (cloud_candidate.length - last_cloud_candidate_length
                      > 2 ||
                      (cloud_candidate.length > last_cloud_candidate.length
                       && cloud_candidate[0:last_cloud_candidate.length]
                       != last_cloud_candidate
                      ))) {
                  cloud_candidate_count++;
                  last_cloud_candidate_length = i;
                  candidates.insert(0, cloud_candidate);
                  last_cloud_candidate = cloud_candidate;
                }
              }
            }

            // database results
            Database.query(pinyin_buffer, candidates, 
                Config.Limits.db_query_limit
                );

            // update lookup table labels
            for (int i = 0; i < Config.CandidateLabels.size; i++) {
              table.set_label((uint)i, new Text.from_string(
                    Config.CandidateLabels.get(i,
                      (Config.Switches.always_show_candidates 
                       && !correction_mode)))
                  );
            }

            // prepare a set to detect duplication
            var candidate_set = new HashSet<string>();

            // update candidates
            int candidate_index = 0;
            foreach (string s in candidates) {
              if (s in candidate_set) continue;
              candidate_set.add(s);

              var text = new Text.from_string(s);
              if (++candidate_index <= cloud_candidate_count)
                Config.Colors.candidate_remote.apply(text);
              else
                Config.Colors.candidate_local.apply(text);
              table.append_candidate(text);
            }

            table_visible = (candidates.size > 0);
            update_lookup_table(table, table_visible);
            last_pinyin_buffer_string = pinyin_buffer.to_string();
            last_correction_mode = correction_mode;
          }
        } else {
          table_visible = false;
          hide_lookup_table();
          // if nothing to correct, exit correct mode.
          if (pinyin_buffer.size == 0) correction_mode = false;
          last_pinyin_buffer_string = "";
        }
      }

      private void update_properties() {
        if (!enabled) return;
        if (last_chinese_mode != chinese_mode) {
          chinese_mode_icon.set_icon("%s/icons/pinyin-%s.png"
              .printf(Config.global_data_path,
                chinese_mode ? "enabled" : "disabled"));
          last_chinese_mode = chinese_mode;
          update_property(chinese_mode_icon);
        }
        if (last_traditional_mode != traditional_mode) {
          traditional_conversion_icon.set_icon(
              "%s/icons/traditional-%s.png"
              .printf(Config.global_data_path,
                traditional_mode ?
                "enabled" : "disabled")
              );
          last_traditional_mode = traditional_mode;
          update_property(traditional_conversion_icon);
        }
        if (last_offline_mode != offline_mode) {
          if (offline_mode) stop_requesting();
          status_icon.set_icon("%s/icons/%s.png"
              .printf(Config.global_data_path,
                offline_mode ? "offline" : "idle-%d"
                .printf(LuaBinding.get_engine_speed_rank())
                ));
          last_offline_mode = offline_mode;
          update_property(status_icon);
        }
      }
    }

    public static void init() {
      component = new Component (
          "org.freedesktop.IBus.cloudpinyin",
          "Cloud Pinyin", Config.version, "GPL",
          "WU Jun <quark@lihdd.net>",
          "http://code.google.com/p/ibus-cloud-pinyin/",
          Config.prefix_path
          + "/lib/ibus/ibus-engine-cloud-pinyin --ibus --replace",
          "ibus-cloud-pinyin");
      engine = new EngineDesc ("cloud-pinyin",
          "Cloud Pinyin",
          "A client of cloud pinyin IME on ibus",
          "zh_CN",
          "GPL",
          "WU Jun <quark@lihdd.net>",
          Config.global_data_path
          + "/icons/ibus-cloud-pinyin.png",
          "us");
      component.add_engine (engine);
    }

    public static string get_component_xml() {
      StringBuilder builder = new StringBuilder();
      builder.append(
          "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
          );
      component.output(builder, 0);
      return builder.str;
    }

    public static void register() {
      bus = new IBus.Bus();
      if (Config.CommandlineOptions.launched_by_ibus) 
        bus.request_name("org.freedesktop.IBus.cloudpinyin", 0);
      else
        bus.register_component (component);

      factory = new Factory(bus.get_connection());
      factory.add_engine("cloud-pinyin",
          typeof(CloudPinyinEngine)
          );
    }
  }
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
