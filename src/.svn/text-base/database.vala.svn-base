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
using icp.Pinyin;

namespace icp {
  public class Database {
    private static Sqlite.Database db;
    private bool user_db;
    private const int PHRASE_LENGTH_MAX = 15;

    private static void assert_exec(string sql) {
      string error_msg;
      int ret = db.exec(sql, null, out error_msg);
      if (ret != Sqlite.OK) {
        stderr.printf("FATAL SQLITE ERROR: %s\nSQL: %s\n", error_msg, sql);
        assert_not_reached();
      }
    }

    public static double get_atime() {
      return (double)Frontend.get_current_time()
        / ((double)(24) * 3600 * 1000000);
    }

    private static void internal_query(Pinyin.Sequence pinyins,
        ArrayList<string> results, bool reverse_order = false,
        int pinyins_begin = 0, int pinyins_end = -1,
        int limit = 1, double phrase_adjust = 1.0) {

      if (pinyins_begin < 0) pinyins_begin = 0;
      if (pinyins_end < 0 || pinyins_end > pinyins.size)
        pinyins_end = pinyins.size;

      // results is already a ref type, directly modify it
      string where = "", query = "SELECT phrase, freqadj FROM (";
      string subquery = "";
      for (int id = 0; id < pinyins.size; ++id) {
        if (id > PHRASE_LENGTH_MAX || id + pinyins_begin >= pinyins_end)
          break;

        Id pinyin_id;
        if (!reverse_order) {
          pinyin_id = pinyins.get_id(id + pinyins_begin);
          int cid = pinyin_id.consonant, vid = pinyin_id.vowel;
          if (cid == 0 && vid == -1) break;

          // refuse to lookup single character with partial pinyin
          // (allow when limit = 1)
          if (vid == -1 && id == 0 && limit != 1 && pinyins.size == 1) break;

          if (where.length != 0) where += " AND ";
          where += "s%d=%d".printf(id, cid);
          if (vid != -1) where += " AND y%d=%d".printf(id, vid);
        } else {
          // rebuild where
          where = "";
          for (int p = id; p >= 0; --p) {
            //if (pinyins_end - 1 - p < 0) break;
            pinyin_id = pinyins.get_id(pinyins_end - 1 - p);
            if (where.length != 0) where += " AND ";
            where += "s%d=%d".printf(id - p, pinyin_id.consonant);
            if (pinyin_id.vowel >= 0) {
              where += " AND y%d=%d".printf(id - p, pinyin_id.vowel);
            }
          }
        }
        if (id > 0) subquery += " UNION ALL ";

        subquery += 
          "SELECT phrase, freq*%.3f AS freqadj FROM main.py_phrase_%d WHERE %s"
          .printf((id + 1) * Math.pow(1.0 + (double)id, phrase_adjust),
            id, where
            );

        // user db 
        subquery +=
          (" UNION ALL SELECT phrase, freq*%.3f*max((32-%.3lf+atime)/32.0, %.3f)"
           + " AS freqadj FROM userdb.py_phrase_%d WHERE %s")
          .printf((id + 1) * Math.pow(1.0 + (double)id,
                phrase_adjust), get_atime(), Math.pow(0.3, 1 + id),
              id, where
              );
      } // for

      if (subquery.length == 0) return;

      // seems userdb results can overwrite maindb's
      query += subquery + ") GROUP BY phrase ORDER BY freqadj DESC";
      if (limit > 0) query += " LIMIT %d".printf(limit);

      Sqlite.Statement stmt;

      if (db.prepare_v2(query, -1, out stmt, null) != Sqlite.OK) return;

      for (bool running = true; running;) {
        switch (stmt.step()) {
          case Sqlite.ROW: 
            {
              string phrase = stmt.column_text(0);
              results.add(phrase);
              break;
            }
          case Sqlite.DONE: 
            {
              running = false;
              break;
            }
          case Sqlite.BUSY: 
            {
              Thread.usleep(1024);
              break;
            }
          case Sqlite.MISUSE:
          case Sqlite.ERROR: 
          default: 
            {
              running = false;
              break;
            }
        }
      }
    }

    private static void load_databases() {
      // load global db
      assert(Sqlite.Database.open_v2(Config.global_database, out db, 
            /*Sqlite.OPEN_READONLY*/ Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE) == Sqlite.OK
          );
      db.exec("PRAGMA cache_size = 16384;\n PRAGMA temp_store = MEMORY;\n"
          + "PRAGMA synchronous=NORMAL;\n PRAGMA journal_mode=PERSIST;\n"
          /* + "PRAGMA locking_mode=EXCLUSIVE;\n"*/);

      // load user db
      assert_exec("ATTACH DATABASE \"%s\" AS userdb;".printf(
            Config.user_database)
          );
      StringBuilder sql_builder = new StringBuilder();
      sql_builder.append("BEGIN TRANSACTION;\n");

      // create tables and indexes
      for (int i = 0; i <= PHRASE_LENGTH_MAX; i++) {
        sql_builder.append("CREATE TABLE IF NOT EXISTS userdb.py_phrase_%d"
            .printf(i)
            );
        sql_builder.append("(phrase TEXT, freq DOUBLE, atime DOUBLE");
        for (int j = 0; j <= i; j++) {
          sql_builder.append(",s%d INTEGER,y%d INTEGER".printf(j, j));
        }
        sql_builder.append(");\n");

        string columns = "";
        if (i < 3)
          for (int j = 0; j <= i; j++) {
            columns += "s%d,y%d,".printf(j, j);
          }
        columns += "phrase";
        sql_builder.append(
            "CREATE UNIQUE INDEX IF NOT EXISTS userdb.index_%d_%d ON py_phrase_%d (%s);\n"
            .printf(i, 0, i, columns)
            );
        if (i >= 2) {
          sql_builder.append(
              "CREATE INDEX IF NOT EXISTS userdb.index_%d_%d ON py_phrase_%d (s0, y0, s1, y1, s2, y2);\n"
              .printf(i, 1, i)
              );
        }
        if (i >= 3) {
          sql_builder.append(
              "CREATE INDEX IF NOT EXISTS userdb.index_%d_%d ON py_phrase_%d (s0, s1, s2, s3);\n"
              .printf(i, 2, i)
              );
        }
      }
      sql_builder.append("COMMIT;");
      assert_exec(sql_builder.str);
    }

    // batch insert perform INSERT OR REPLACE, do not perform
    // do INSERT OR IGNORE
    public static void batch_insert(ArrayList<string> phrases,
        ArrayList<Pinyin.Sequence> sequences,
        ArrayList<double?> freqs) {
      int count = phrases.size;
      if (sequences.size < count) count = sequences.size;
      if (freqs.size < count) count = freqs.size;

      StringBuilder sql_builder = new StringBuilder();
      sql_builder.append("BEGIN;\n");
      for (int i = 0; i < count; i++) {
        var phrase = phrases[i];
        var sequence = sequences[i];
        double freq = freqs[i] ?? 1000;

        if (sequence.size != phrase.length 
            || sequence.size > PHRASE_LENGTH_MAX + 1
            || sequence.size == 0
           ) continue;

        int length = sequence.size;
        sql_builder.append(
            "INSERT OR REPLACE INTO userdb.py_phrase_%d VALUES('%s',%.3lf,%.3lf"
            .printf(length - 1, phrase, freq, 
              get_atime())
            );
        for (int j = 0; j < length; j++) {
          Id id = sequence.get_id(j);
          // do not allow partial pinyin
          if (id.vowel < 0) return;
          sql_builder.append(",%d,%d".printf(id.consonant, id.vowel));
        }
        sql_builder.append(");\n");

      }
      sql_builder.append("COMMIT;\n");
      assert_exec(sql_builder.str);
    }

    public static void insert(string phrase, Pinyin.Sequence sequence,
        double base_freq = -3000.0, double freq_increase = 200,
        bool lookup_first = true
        ) {
      // insert into user_db
      // reject length mismatch or exceed max length allowed
      if (sequence.size != phrase.length 
          || sequence.size > PHRASE_LENGTH_MAX + 1
          || sequence.size == 0
         ) return;

      int length = sequence.size;
      StringBuilder sql_builder = new StringBuilder();
      string where = "phrase=\"%s\"".printf(phrase);
      if (lookup_first)  {
        sql_builder.append(
            "INSERT OR IGNORE INTO userdb.py_phrase_%d VALUES("
            .printf(length - 1)
            );
      } else {
        sql_builder.append(
            "INSERT OR REPLACE INTO userdb.py_phrase_%d VALUES("
            .printf(length - 1)
            );
      }
      double freq = base_freq;  
      if (freq < 0) freq = (-freq) / length;

      if (lookup_first) {
        // query freq
        string query =
          "SELECT freq FROM main.py_phrase_%d WHERE phrase=\"%s\" LIMIT 1"
          .printf(length - 1, phrase);
        Sqlite.Statement stmt;
        if (db.prepare_v2(query, -1, out stmt, null) == Sqlite.OK) {
          for (bool running = true; running;) {
            switch (stmt.step()) {
              case Sqlite.ROW: 
                freq = (double)stmt.column_double(0);
                break;
              case Sqlite.BUSY: 
                Thread.usleep(1024);
                break;
              default: 
                running = false;
                break;
            }
          }
        }
      }

      sql_builder.append("'%s',%lf,%lf".printf(phrase, freq,
            get_atime())
          );
      for (int i = 0; i < length; i++) {
        Id id = sequence.get_id(i);
        // do not allow partial pinyin
        if (id.vowel < 0) return;
        where += " AND s%d=%d AND y%d=%d".printf(i, id.consonant, 
            i, id.vowel
            );
        sql_builder.append(",%d,%d".printf(id.consonant, id.vowel));
      }
      sql_builder.append(");");

      // lock (db) {
      // try insert if not existed
      assert_exec(sql_builder.str);
      if (lookup_first) { 
        // update freq OR atime
        double atime = get_atime();

        string query =
          "SELECT atime, freq FROM userdb.py_phrase_%d WHERE %s LIMIT 1"
          .printf(length - 1, where);
        Sqlite.Statement stmt;

        if (db.prepare_v2(query, -1, out stmt, null) == Sqlite.OK) {
          for (bool running = true; running;) {
            switch (stmt.step()) {
              case Sqlite.ROW: 
                atime = stmt.column_double(0);
                freq = stmt.column_double(1);
                break;
              case Sqlite.BUSY:
                Thread.usleep(1024);
                break;
              default:
                running = false;
                break;
            }
          }
        }

        atime = get_atime() - atime;
        if (atime < 1.0) {
          // in 24 hours, update both
          assert_exec(
              "UPDATE userdb.py_phrase_%d SET freq=freq+%.3lf, atime=%lf WHERE %s"
              .printf(length - 1, freq_increase, get_atime(), where)
              );
        } else {
          // update atime only
          assert_exec(
              "UPDATE userdb.py_phrase_%d SET atime=%lf WHERE %s"
              .printf(length - 1, get_atime(), where)
              );
        }
      } // if lookup_first

      // } // lock (db)
    }

    public static bool reverse_convert(string content, 
        out Pinyin.Sequence pinyins) {
      bool successful = true;
      ArrayList<Pinyin.Id> ids = new ArrayList<Pinyin.Id>();

      for (int pos = 0; pos < content.length; ) {
        // IMPROVE: allow query longer phrases (also need sql index)
        int phrase_length_max = 5;
        if (pos + phrase_length_max >= content.length) 
          phrase_length_max = (int)content.length - pos - 1;

        int matched_length = 0;
        // note that phrase_length is real phrase length - 1 
        // for easily building sql query string
        for (int phrase_length = phrase_length_max; phrase_length >= 0; 
            phrase_length--) {
          string query = "SELECT ";
          for (int i = 0; i <= phrase_length; i++) {
            query += "s%d,y%d%c".printf(i, i,
                (i == phrase_length) ? ' ':','
                );
          }
          query += " FROM main.py_phrase_%d WHERE phrase=\"%s\" LIMIT 1"
            .printf(phrase_length, content[pos:pos + phrase_length + 1]);

          // query
          Sqlite.Statement stmt;

          if (db.prepare_v2(query, -1, out stmt, null) != Sqlite.OK)
            continue;

          for (bool running = true; running;) {
            switch (stmt.step()) {
              case Sqlite.ROW: 
                // got it, matched
                if (matched_length == 0) {
                  matched_length = phrase_length + 1;
                  for (int i = 0; i <= phrase_length; i++)
                    ids.add(new Pinyin.Id.id(stmt.column_int(i * 2), 
                          stmt.column_int(i * 2 + 1))
                        );
                }
                break;
              case Sqlite.BUSY: 
                Thread.usleep(1024);
                break;
              default: 
                running = false;
                break;
            }
          }

          if (matched_length > 0) break;
        }

        if (matched_length == 0) {
          // try regonise it as a normal pinyin
          int pinyin_length = 6;
          if (pos + pinyin_length >= content.length) 
            pinyin_length = (int)content.length - pos;

          for (; pinyin_length > 0; pinyin_length--) {
            if (content[pos:pos + pinyin_length] in valid_partial_pinyins) {
              // got it
              matched_length = pinyin_length;
              ids.add(new Id(content[pos:pos + pinyin_length]));
              break;
            }
          }
        }

        if (matched_length == 0) {
          // not matched anyway, ignore that character
          successful = false;
          pos++;
        } else {
          pos += matched_length;
        }
      }

      pinyins = new Pinyin.Sequence.ids(ids);
      return successful;
    }

    public static void query(Pinyin.Sequence pinyins, 
        ArrayList<string> candidates, 
        int limit = 0, double phrase_adjust = 1.05) {

      internal_query(pinyins, candidates, false,
          0, -1, limit, phrase_adjust
          );
    }

    public static string greedy_convert(Pinyin.Sequence pinyins, 
        double phrase_adjust = 2) {

      string r = "";
      if (pinyins.size == 0) return r;

      ArrayList<string> query_result = new ArrayList<string>();;

      for (int id = (int) pinyins.size; id > 0;) {
        internal_query (pinyins, query_result, true, 0, id, 1, phrase_adjust);
        string phrase = "";
        if (query_result.size > 0) phrase = query_result.get(0);
        int match_length = (int)phrase.length;

        if (match_length == 0) {
          // can't convert just skip this pinyin -,-
          r = pinyins.get(id - 1) + r;
          id--;
        } else {
          r = phrase + r;
          id -= match_length;
        }
        query_result.clear();
      }
      return r;
    }

    public static void init() {
      // create essential directories
      string path = "";
      foreach (string dir in Config.user_cache_path.split("/")) {
        path += "/%s".printf(dir);
        Posix.mkdir(path, Posix.S_IRWXU);
      }
      // load dbs
      load_databases();
    }

    private Database() { }
  } // class Database
} // namespace icp

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
